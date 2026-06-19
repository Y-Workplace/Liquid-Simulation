--!strict

local WaveSpectrum = require(script.Parent.Parent.WaveSpectrum)

type TileConfig = any
type InternalOceanTile = any

return function(deps: any)
	local WAVE_BAKE_VERSION = deps.WAVE_BAKE_VERSION
	local WAVE_LOOP_POSITION_BYTES = deps.WAVE_LOOP_POSITION_BYTES
	local WAVE_LOOP_HEIGHT_BYTES = deps.WAVE_LOOP_HEIGHT_BYTES
	local WAVE_LOOP_SEAM_FRACTION = deps.WAVE_LOOP_SEAM_FRACTION
	local BAKE_YIELD_CELL_BUDGET = deps.BAKE_YIELD_CELL_BUDGET
	local MAX_OBSTACLE_IMPACT_VERTICES = deps.MAX_OBSTACLE_IMPACT_VERTICES
	local OBSTACLE_IMPACT_VERTEX_BYTES = deps.OBSTACLE_IMPACT_VERTEX_BYTES
	local VERTEX_BAKE_STATIC_BYTES = deps.VERTEX_BAKE_STATIC_BYTES
	local VERTEX_STATIC_BASE_WORLD_X = deps.VERTEX_STATIC_BASE_WORLD_X
	local VERTEX_STATIC_BASE_WORLD_Z = deps.VERTEX_STATIC_BASE_WORLD_Z
	local VERTEX_STATIC_WAVE_SCALE = deps.VERTEX_STATIC_WAVE_SCALE
	local VERTEX_STATIC_OCEAN_WEIGHT = deps.VERTEX_STATIC_OCEAN_WEIGHT
	local VERTEX_STATIC_LAKE_WEIGHT = deps.VERTEX_STATIC_LAKE_WEIGHT
	local VERTEX_STATIC_SHALLOW_WEIGHT = deps.VERTEX_STATIC_SHALLOW_WEIGHT
	local smoothstep = deps.smoothstep
	local gridIndex = deps.gridIndex
	local getAxisCell = deps.getAxisCell
	local wavePositionOffset = deps.wavePositionOffset
	local waveHeightOffset = deps.waveHeightOffset
	local obstacleImpactVertexOffset = deps.obstacleImpactVertexOffset
	local vertexBakeStaticOffset = deps.vertexBakeStaticOffset
	local sampleDepth = deps.sampleDepth
	local sampleObstacleImpact = deps.sampleObstacleImpact
	local sampleObstacleAttenuation = deps.sampleObstacleAttenuation
	local resetWaveLoop = deps.resetWaveLoop

	local ensureWaveLoop: (InternalOceanTile) -> boolean

	local function getWaveLoopGeometryKey(config: TileConfig): string
		return `{WAVE_BAKE_VERSION}:{math.clamp(math.round(config.WaveLoopFrames), 2, 240)}:{math.max(config.WaveLoopDuration, 0.25)}:{config.ShallowWaveScale}:{config.DeepWaveScale}:{config.ShallowDepth}:{config.LakeDepth}:{config.OceanDepth}:{config.ObstacleWaveDamping}:{config.FoamNoiseSeed}`
	end

	local function getWaveLoopKey(config: TileConfig): string
		return getWaveLoopGeometryKey(config)
	end

	local function getWaveLoopReadyFrameCount(tile: InternalOceanTile): number
		return math.clamp(tile._WaveLoopReadyFrames, 0, math.max(tile._WaveLoopFrames, 0))
	end

	local function hasAnyWaveLoopFrame(tile: InternalOceanTile, key: string): boolean
		return tile._WaveLoopPositions ~= nil
			and tile._WaveLoopHeights ~= nil
			and tile._WaveLoopKey == key
			and getWaveLoopReadyFrameCount(tile) > 0
	end

	local function hasCompleteWaveLoop(tile: InternalOceanTile, key: string): boolean
		return hasAnyWaveLoopFrame(tile, key)
			and tile._WaveLoopFrames > 0
			and getWaveLoopReadyFrameCount(tile) >= tile._WaveLoopFrames
	end

	local function isWaveLoopBakeCurrent(
		tile: InternalOceanTile,
		bakeId: number,
		key: string,
		spectrum: WaveSpectrum.WaveSpectrum
	): boolean
		return not tile._Destroyed
			and tile._WaveLoopBakeId == bakeId
			and tile._Spectrum == spectrum
			and tile._WaveLoopKey == key
	end

	local function bakeWaveLoop(tile: InternalOceanTile, key: string, bakeId: number): boolean
		local config = tile._Config
		local spectrum = tile._Spectrum
		local vertexCount = #tile._Vertices
		local frames = math.clamp(math.round(config.WaveLoopFrames), 2, 240)
		local duration = math.max(config.WaveLoopDuration, 0.25)
		local positions = buffer.create(vertexCount * frames * WAVE_LOOP_POSITION_BYTES)
		local heights = buffer.create(vertexCount * frames * WAVE_LOOP_HEIGHT_BYTES)
		local static = buffer.create(vertexCount * VERTEX_BAKE_STATIC_BYTES)
		local baseCFrame = tile.BaseCFrame
		local obstacleVertices = buffer.create(MAX_OBSTACLE_IMPACT_VERTICES * OBSTACLE_IMPACT_VERTEX_BYTES)
		local obstacleVertexCount = 0
		local processedSinceYield = 0
		local minHeight = math.huge
		local maxHeight = -math.huge
		local lakeDepth = math.max(config.LakeDepth, config.ShallowDepth + 0.001)
		local oceanDepth = math.max(config.OceanDepth, lakeDepth + 0.001)

		if not isWaveLoopBakeCurrent(tile, bakeId, key, spectrum) then
			return false
		end

		tile._WaveLoopPositions = positions
		tile._WaveLoopHeights = heights
		tile._WaveLoopFrames = frames
		tile._WaveLoopReadyFrames = 0
		tile._WaveLoopFrameStride = vertexCount
		tile._WaveLoopDuration = duration
		tile._WaveLoopMinHeight = 0
		tile._WaveLoopMaxHeight = 0
		tile._WaveLoopKey = key

		for vertexIndex, vertex in ipairs(tile._Vertices) do
			if not isWaveLoopBakeCurrent(tile, bakeId, key, spectrum) then
				return false
			end

			local localX = vertex.baseLocal.X
			local localZ = vertex.baseLocal.Z
			local baseWorld = baseCFrame:PointToWorldSpace(vertex.baseLocal)
			local depth = sampleDepth(tile._DepthMap, config, localX, localZ)
			local shallowToLake = smoothstep(config.ShallowDepth, lakeDepth, depth)
			local lakeToOcean = smoothstep(lakeDepth, oceanDepth, depth)
			local shallowWeight = 1 - shallowToLake
			local oceanWeight = lakeToOcean + shallowWeight
			local lakeWeight = shallowToLake * (1 - lakeToOcean)
			local deepFactor = smoothstep(config.ShallowDepth, oceanDepth, depth)
			local obstacleSeed = if vertex.surfaceEnabled then sampleObstacleImpact(tile._ObstacleMap, localX, localZ) else 0
			local obstacleAttenuation = sampleObstacleAttenuation(tile._ObstacleMap, localX, localZ, config.ObstacleWaveDamping)
			local depthWaveScale = config.ShallowWaveScale + (config.DeepWaveScale - config.ShallowWaveScale) * deepFactor
			local waveScale = depthWaveScale * obstacleAttenuation * vertex.waveInfluence
			local sampleWorldX = baseWorld.X
			local sampleWorldZ = baseWorld.Z

			buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_BASE_WORLD_X), sampleWorldX)
			buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_BASE_WORLD_Z), sampleWorldZ)
			buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_WAVE_SCALE), waveScale)
			buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_OCEAN_WEIGHT), oceanWeight)
			buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_LAKE_WEIGHT), lakeWeight)
			buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_SHALLOW_WEIGHT), 0)

			if vertex.surfaceEnabled and obstacleSeed >= 0.55 and obstacleVertexCount < MAX_OBSTACLE_IMPACT_VERTICES then
				obstacleVertexCount += 1
				buffer.writeu16(obstacleVertices, obstacleImpactVertexOffset(obstacleVertexCount), vertexIndex)
			end

			processedSinceYield += 1

			if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
				processedSinceYield = 0
				task.wait()

				if not isWaveLoopBakeCurrent(tile, bakeId, key, spectrum) then
					return false
				end
			end
		end

		tile._ObstacleImpactVertices = obstacleVertices
		tile._ObstacleImpactVertexCount = obstacleVertexCount

		for frameIndex = 0, frames - 1 do
			local bakeTime = (frameIndex / frames) * duration

			for vertexIndex = 1, vertexCount do
				if not isWaveLoopBakeCurrent(tile, bakeId, key, spectrum) then
					return false
				end

				local staticOffset = (vertexIndex - 1) * VERTEX_BAKE_STATIC_BYTES
				local baseWorldX = buffer.readf32(static, staticOffset + VERTEX_STATIC_BASE_WORLD_X * 4)
				local baseWorldZ = buffer.readf32(static, staticOffset + VERTEX_STATIC_BASE_WORLD_Z * 4)
				local oceanWeight = buffer.readf32(static, staticOffset + VERTEX_STATIC_OCEAN_WEIGHT * 4)
				local lakeWeight = buffer.readf32(static, staticOffset + VERTEX_STATIC_LAKE_WEIGHT * 4)
				local shallowWeight = buffer.readf32(static, staticOffset + VERTEX_STATIC_SHALLOW_WEIGHT * 4)
				local displacementX, sampleHeight, displacementZ, _sampleFoam =
					spectrum:SampleBakedWeighted3XZ(baseWorldX, baseWorldZ, bakeTime, 1, oceanWeight, lakeWeight, shallowWeight)
				local loopProgress = frameIndex / frames
				local seamStart = 1 - WAVE_LOOP_SEAM_FRACTION

				if loopProgress >= seamStart then
					local seamAlpha = smoothstep(seamStart, 1, loopProgress)
					local previousX, previousHeight, previousZ, _previousFoam =
						spectrum:SampleBakedWeighted3XZ(baseWorldX, baseWorldZ, bakeTime - duration, 1, oceanWeight, lakeWeight, shallowWeight)

					displacementX += (previousX - displacementX) * seamAlpha
					sampleHeight += (previousHeight - sampleHeight) * seamAlpha
					displacementZ += (previousZ - displacementZ) * seamAlpha
				end

				local waveScale = buffer.readf32(static, staticOffset + VERTEX_STATIC_WAVE_SCALE * 4)
				local delta = baseCFrame:VectorToObjectSpace(Vector3.new(displacementX, sampleHeight, displacementZ) * waveScale)
				local positionOffset = wavePositionOffset(frameIndex, vertexIndex, vertexCount, 0)

				buffer.writef32(positions, positionOffset, delta.X)
				buffer.writef32(positions, positionOffset + 4, delta.Y)
				buffer.writef32(positions, positionOffset + 8, delta.Z)
				buffer.writef32(heights, waveHeightOffset(frameIndex, vertexIndex, vertexCount), delta.Y)
				minHeight = math.min(minHeight, delta.Y)
				maxHeight = math.max(maxHeight, delta.Y)

				processedSinceYield += 1

				if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
					processedSinceYield = 0
					task.wait()

					if not isWaveLoopBakeCurrent(tile, bakeId, key, spectrum) then
						return false
					end
				end
			end

			if not isWaveLoopBakeCurrent(tile, bakeId, key, spectrum) then
				return false
			end

			tile._WaveLoopReadyFrames = frameIndex + 1
			tile._WaveLoopMinHeight = if minHeight < math.huge then minHeight else 0
			tile._WaveLoopMaxHeight = if maxHeight > -math.huge then maxHeight else 0

			if frameIndex < frames - 1 then
				processedSinceYield = 0
				task.wait()

				if not isWaveLoopBakeCurrent(tile, bakeId, key, spectrum) then
					return false
				end
			end
		end

		tile._WaveLoopMinHeight = if minHeight < math.huge then minHeight else 0
		tile._WaveLoopMaxHeight = if maxHeight > -math.huge then maxHeight else 0
		tile._WaveLoopKey = key
		tile._WaveLoopReadyFrames = frames

		return true
	end

	ensureWaveLoop = function(tile: InternalOceanTile)
		local config = tile._Config
		local key = getWaveLoopKey(config)

		if hasCompleteWaveLoop(tile, key) then
			return true
		end

		if tile._WaveLoopBaking then
			return hasAnyWaveLoopFrame(tile, key)
		end

		if tile._WaveLoopKey ~= key then
			resetWaveLoop(tile)
		end

		tile._WaveLoopBakeId += 1
		local bakeId = tile._WaveLoopBakeId
		tile._WaveLoopKey = key
		tile._WaveLoopBaking = true

		task.spawn(function()
			local baked = false
			local ok, err = pcall(function()
				baked = bakeWaveLoop(tile, key, bakeId)
			end)

			if tile._WaveLoopBakeId ~= bakeId then
				return
			end

			tile._WaveLoopBaking = false

			if not ok then
				resetWaveLoop(tile)
				warn("[WaterSystem] Wave loop bake failed: " .. tostring(err))
			elseif not baked and not tile._Destroyed and tile._WaveLoopKey == key then
				tile._WaveLoopReadyFrames = math.clamp(tile._WaveLoopReadyFrames, 0, math.max(tile._WaveLoopFrames, 0))
			end
		end)

		return hasAnyWaveLoopFrame(tile, key)
	end

	local function getWaveLoopFrame(tile: InternalOceanTile, time: number): (number, number, number)
		local frames = math.max(getWaveLoopReadyFrameCount(tile), 1)
		local framePosition = ((time % tile._WaveLoopDuration) / tile._WaveLoopDuration) * frames
		local frameA = math.floor(framePosition) % frames
		local frameB = if frames > 1 then (frameA + 1) % frames else frameA
		local alpha = framePosition - math.floor(framePosition)

		return frameA, frameB, alpha
	end

	local function readWaveLoopVertex(
		positions: buffer,
		frameA: number,
		frameB: number,
		alpha: number,
		vertexCount: number,
		vertexIndex: number
	): (number, number, number)
		local offsetA = wavePositionOffset(frameA, vertexIndex, vertexCount, 0)
		local offsetB = wavePositionOffset(frameB, vertexIndex, vertexCount, 0)
		local ax = buffer.readf32(positions, offsetA)
		local ay = buffer.readf32(positions, offsetA + 4)
		local az = buffer.readf32(positions, offsetA + 8)

		return
			ax + (buffer.readf32(positions, offsetB) - ax) * alpha,
			ay + (buffer.readf32(positions, offsetB + 4) - ay) * alpha,
			az + (buffer.readf32(positions, offsetB + 8) - az) * alpha
	end

	local function sampleWaveLoop(tile: InternalOceanTile, vertexIndex: number, time: number): Vector3
		ensureWaveLoop(tile)

		local positions = tile._WaveLoopPositions

		if positions == nil or getWaveLoopReadyFrameCount(tile) <= 0 then
			return Vector3.zero
		end

		local frameA, frameB, alpha = getWaveLoopFrame(tile, time)
		local dx, dy, dz = readWaveLoopVertex(
			positions,
			frameA,
			frameB,
			alpha,
			math.max(tile._WaveLoopFrameStride, 1),
			vertexIndex
		)

		return Vector3.new(dx, dy, dz)
	end

	local function readWaveLoopHeight(
		heights: buffer,
		frameA: number,
		frameB: number,
		alpha: number,
		vertexCount: number,
		vertexIndex: number
	): number
		local offsetA = waveHeightOffset(frameA, vertexIndex, vertexCount)
		local valueA = buffer.readf32(heights, offsetA)

		return valueA + (buffer.readf32(heights, waveHeightOffset(frameB, vertexIndex, vertexCount)) - valueA) * alpha
	end

	local function readWaveLoopHeightFrame(
		heights: buffer,
		frameIndex: number,
		vertexCount: number,
		vertexIndex: number
	): number
		return buffer.readf32(heights, waveHeightOffset(frameIndex, vertexIndex, vertexCount))
	end

	local function sampleBakedHeight(tile: InternalOceanTile, localX: number, localZ: number, time: number): number
		ensureWaveLoop(tile)

		local heights = tile._WaveLoopHeights

		if heights == nil or getWaveLoopReadyFrameCount(tile) <= 0 then
			return 0
		end

		local resolutionX = tile._ResolutionX
		local resolutionZ = tile._ResolutionZ
		local x0, x1, tx = getAxisCell(tile._GridXCoordinates, resolutionX, localX)
		local z0, z1, tz = getAxisCell(tile._GridZCoordinates, resolutionZ, localZ)
		local frameA, frameB, alpha = getWaveLoopFrame(tile, time)
		local vertexCount = math.max(tile._WaveLoopFrameStride, 1)
		local d00 = readWaveLoopHeight(heights, frameA, frameB, alpha, vertexCount, gridIndex(resolutionX, x0, z0))
		local d10 = readWaveLoopHeight(heights, frameA, frameB, alpha, vertexCount, gridIndex(resolutionX, x1, z0))
		local d01 = readWaveLoopHeight(heights, frameA, frameB, alpha, vertexCount, gridIndex(resolutionX, x0, z1))
		local d11 = readWaveLoopHeight(heights, frameA, frameB, alpha, vertexCount, gridIndex(resolutionX, x1, z1))
		local a = d00 + (d10 - d00) * tx
		local b = d01 + (d11 - d01) * tx

		return a + (b - a) * tz
	end

	local function sampleBakedHeightAtTime(
		tile: InternalOceanTile,
		heights: buffer,
		localX: number,
		localZ: number,
		time: number
	): number
		local resolutionX = tile._ResolutionX
		local resolutionZ = tile._ResolutionZ
		local x0, x1, tx = getAxisCell(tile._GridXCoordinates, resolutionX, localX)
		local z0, z1, tz = getAxisCell(tile._GridZCoordinates, resolutionZ, localZ)
		local frameA, frameB, alpha = getWaveLoopFrame(tile, time)
		local vertexCount = math.max(tile._WaveLoopFrameStride, 1)
		local d00 = readWaveLoopHeight(heights, frameA, frameB, alpha, vertexCount, gridIndex(resolutionX, x0, z0))
		local d10 = readWaveLoopHeight(heights, frameA, frameB, alpha, vertexCount, gridIndex(resolutionX, x1, z0))
		local d01 = readWaveLoopHeight(heights, frameA, frameB, alpha, vertexCount, gridIndex(resolutionX, x0, z1))
		local d11 = readWaveLoopHeight(heights, frameA, frameB, alpha, vertexCount, gridIndex(resolutionX, x1, z1))
		local a = d00 + (d10 - d00) * tx
		local b = d01 + (d11 - d01) * tx

		return a + (b - a) * tz
	end


	return {
		getWaveLoopGeometryKey = getWaveLoopGeometryKey,
		getWaveLoopKey = getWaveLoopKey,
		getWaveLoopReadyFrameCount = getWaveLoopReadyFrameCount,
		hasAnyWaveLoopFrame = hasAnyWaveLoopFrame,
		hasCompleteWaveLoop = hasCompleteWaveLoop,
		ensureWaveLoop = ensureWaveLoop,
		getWaveLoopFrame = getWaveLoopFrame,
		readWaveLoopVertex = readWaveLoopVertex,
		sampleWaveLoop = sampleWaveLoop,
		readWaveLoopHeight = readWaveLoopHeight,
		readWaveLoopHeightFrame = readWaveLoopHeightFrame,
		sampleBakedHeight = sampleBakedHeight,
		sampleBakedHeightAtTime = sampleBakedHeightAtTime,
	}
end
