--!strict

type TileConfig = any
type VertexState = any
type InternalOceanTile = any

return function(deps: any)
	local RING_LOD_ENTRY_BYTES = deps.RING_LOD_ENTRY_BYTES
	local RING_LOD_VERTEX_OFFSET = deps.RING_LOD_VERTEX_OFFSET
	local RING_LOD_LEVEL_OFFSET = deps.RING_LOD_LEVEL_OFFSET
	local RING_LEVEL_NEAR = deps.RING_LEVEL_NEAR
	local RING_LEVEL_MID = deps.RING_LEVEL_MID
	local RING_LEVEL_FAR = deps.RING_LEVEL_FAR
	local RING_LEVEL_EXTREME = deps.RING_LEVEL_EXTREME
	local readNumberAttribute = deps.readNumberAttribute

	local function getLodDetail(config: TileConfig, distance: number): number
		if distance >= config.MaxDistance then
			return 0
		end

		if distance <= config.PhysicsDistance then
			return 1
		end

		if distance <= config.FadeStartDistance then
			local alpha = math.clamp(
				(distance - config.PhysicsDistance) / math.max(config.FadeStartDistance - config.PhysicsDistance, 1),
				0,
				1
			)

			return 1 + (math.clamp(config.FarWaveDetail, 0.05, 1) - 1) * alpha * 0.45
		end

		local fade = 1 - ((distance - config.FadeStartDistance) / math.max(config.MaxDistance - config.FadeStartDistance, 1))
		return math.clamp(fade * math.clamp(config.FarWaveDetail, 0.05, 1), 0, 1)
	end

	local function shouldUpdateLodVertex(_tile: InternalOceanTile, _vertex: VertexState, _step: number): boolean
		-- The rings still reduce wave detail, but every vertex must receive a fresh
		-- position. Skipping alternating vertices inside one mesh leaves stale peaks
		-- beside updated vertices, which creates jagged LOD borders.
		return true
	end

	local function ringLodEntryOffset(entryIndex: number): number
		return entryIndex * RING_LOD_ENTRY_BYTES
	end

	local function getRingLodKey(config: TileConfig): string
		return `{config.Lod0Radius}:{config.Lod1Radius}:{config.Lod2Radius}:{config.LodRecenterDistance}:{config.VertexSpacing}:{config.MidLodVertexStep}:{config.FarLodVertexStep}:{config.ExtremeLodVertexStep}:{config.FarWaveDetail}`
	end

	local function quantizeRingCenter(value: number, recenterDistance: number): number
		local step = math.max(recenterDistance, 0.5)

		return math.round(value / step) * step
	end

	local function getRingLodLevel(config: TileConfig, ringDistance: number, seamWidth: number): number
		local level = RING_LEVEL_EXTREME

		if ringDistance <= config.Lod0Radius then
			level = RING_LEVEL_NEAR
		elseif ringDistance <= config.Lod1Radius then
			level = RING_LEVEL_MID
		elseif ringDistance <= config.Lod2Radius then
			level = RING_LEVEL_FAR
		end

		if math.abs(ringDistance - config.Lod0Radius) <= seamWidth then
			return RING_LEVEL_NEAR
		end

		if math.abs(ringDistance - config.Lod1Radius) <= seamWidth then
			return math.min(level, RING_LEVEL_MID)
		end

		if math.abs(ringDistance - config.Lod2Radius) <= seamWidth then
			return math.min(level, RING_LEVEL_FAR)
		end

		return level
	end

	local function getRingLodStep(config: TileConfig, lodLevel: number): number
		if lodLevel <= RING_LEVEL_NEAR then
			return 1
		end

		if lodLevel == RING_LEVEL_MID then
			return math.max(1, math.round(config.MidLodVertexStep))
		end

		if lodLevel == RING_LEVEL_FAR then
			return math.max(1, math.round(config.FarLodVertexStep))
		end

		return math.max(1, math.round(config.ExtremeLodVertexStep))
	end

	local function getRingLodDetail(config: TileConfig, tileDetail: number, lodLevel: number): number
		local farDetail = math.clamp(config.FarWaveDetail, 0.05, 1)

		if lodLevel <= RING_LEVEL_NEAR then
			return tileDetail
		end

		if lodLevel == RING_LEVEL_MID then
			return tileDetail * (1 + (farDetail - 1) * 0.35)
		end

		if lodLevel == RING_LEVEL_FAR then
			return tileDetail * farDetail
		end

		return tileDetail * farDetail * 0.55
	end

	local function getRingDistanceFactor(tileDistanceFactor: number, lodLevel: number): number
		if lodLevel <= RING_LEVEL_NEAR then
			return tileDistanceFactor
		end

		if lodLevel == RING_LEVEL_MID then
			return tileDistanceFactor * 0.92
		end

		if lodLevel == RING_LEVEL_FAR then
			return tileDistanceFactor * 0.72
		end

		return tileDistanceFactor * 0.48
	end

	local function ensureRingLodCache(tile: InternalOceanTile, cameraLocalX: number, cameraLocalZ: number)
		local config = tile._Config
		local centerX = quantizeRingCenter(cameraLocalX, config.LodRecenterDistance)
		local centerZ = quantizeRingCenter(cameraLocalZ, config.LodRecenterDistance)
		local key = getRingLodKey(config)

		if tile._RingLodIndices ~= nil
			and not tile._RingLodDirty
			and tile._RingLodKey == key
			and tile._RingLodCenterX == centerX
			and tile._RingLodCenterZ == centerZ
		then
			return
		end

		local vertexCount = #tile._Vertices
		local indices = buffer.create(math.max(vertexCount, 1) * RING_LOD_ENTRY_BYTES)
		local entryCount = 0
		local vertexSpacing = math.max(readNumberAttribute(tile.SourcePart, "OceanVertexSpacing", config.VertexSpacing), 0.5)
		local seamWidth = math.max(vertexSpacing, config.LodRecenterDistance * 0.5, 1)

		for vertexIndex, vertex in ipairs(tile._Vertices) do
			local dx = math.abs(vertex.baseLocal.X - centerX)
			local dz = math.abs(vertex.baseLocal.Z - centerZ)
			local ringDistance = math.max(dx, dz)
			local lodLevel = getRingLodLevel(config, ringDistance, seamWidth)
			local step = getRingLodStep(config, lodLevel)

			if shouldUpdateLodVertex(tile, vertex, step) then
				local offset = ringLodEntryOffset(entryCount)

				buffer.writeu16(indices, offset + RING_LOD_VERTEX_OFFSET, vertexIndex)
				buffer.writeu16(indices, offset + RING_LOD_LEVEL_OFFSET, lodLevel)
				entryCount += 1
			end
		end

		tile._RingLodIndices = indices
		tile._RingLodCount = entryCount
		tile._RingLodCenterX = centerX
		tile._RingLodCenterZ = centerZ
		tile._RingLodKey = key
		tile._RingLodDirty = false
	end

	return {
		getLodDetail = getLodDetail,
		ringLodEntryOffset = ringLodEntryOffset,
		ensureRingLodCache = ensureRingLodCache,
		getRingLodDetail = getRingLodDetail,
		getRingDistanceFactor = getRingDistanceFactor,
	}
end
