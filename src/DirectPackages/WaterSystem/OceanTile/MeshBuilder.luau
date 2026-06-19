--!strict

type InternalOceanTile = any
type EdgeVertexMapper = (number) -> number
type EdgeGridMapper = (number) -> (number, number)

return function(deps: any)
	local VOLUME_BOTTOM_GRID_OFFSET = deps.VOLUME_BOTTOM_GRID_OFFSET
	local addMeshVertex = deps.addMeshVertex
	local addMeshFace = deps.addMeshFace
	local gridIndex = deps.gridIndex
	local getBaseCFrame = deps.getBaseCFrame

	local function buildSurfaceMesh(tile: InternalOceanTile)
		local resolutionX = tile._ResolutionX
		local resolutionZ = tile._ResolutionZ

		for z = 0, resolutionZ do
			local localZ = buffer.readf32(tile._GridZCoordinates, z * 4)

			for x = 0, resolutionX do
				local localX = buffer.readf32(tile._GridXCoordinates, x * 4)

				addMeshVertex(tile, Vector3.new(localX, 0, localZ), x, z, 1, true)
			end
		end

		for z = 0, resolutionZ - 1 do
			for x = 0, resolutionX - 1 do
				local a = gridIndex(resolutionX, x, z)
				local b = gridIndex(resolutionX, x + 1, z)
				local c = gridIndex(resolutionX, x, z + 1)
				local d = gridIndex(resolutionX, x + 1, z + 1)

				addMeshFace(tile, a, c, b)
				addMeshFace(tile, b, c, d)
			end
		end
	end

	local function getVolumeDepth(tile: InternalOceanTile, localX: number, localZ: number): number
		local sourceDepth = math.max(tile.SourcePart.Size.Y, 0.1)
		local minDepth = math.max(tile._Config.VolumeMinDepth, sourceDepth)
		local maxDepth = math.max(tile._Config.OceanDepth, minDepth)
		local depth = sourceDepth

		if tile._DepthMap ~= nil then
			depth = tile._DepthMap:SampleDepth(localX, localZ)
		end

		return math.clamp(math.max(depth, minDepth), minDepth, maxDepth)
	end

	local function buildSideStrip(
		tile: InternalOceanTile,
		edgeCount: number,
		topAt: EdgeVertexMapper,
		gridAt: EdgeGridMapper,
		reverseWinding: boolean
	)
		local verticalSegments = math.clamp(math.round(tile._Config.VolumeVerticalSegments), 1, 8)
		local stripSegments = edgeCount - 1
		local stripCount = stripSegments + 1
		local topIndices = table.create(stripCount)
		local rows = table.create(verticalSegments + 1)

		rows[1] = table.create(stripCount)

		for stripIndex = 0, stripSegments do
			local sourceIndex = stripIndex

			topIndices[stripIndex + 1] = sourceIndex
			rows[1][stripIndex + 1] = topAt(sourceIndex)
		end

		for segment = 1, verticalSegments do
			local t = segment / verticalSegments
			local row = table.create(stripCount)
			local waveInfluence = tile._Config.VolumeWaveScale * (1 - t) + tile._Config.VolumeWaveScale * 0.18 * t

			for stripIndex = 0, stripSegments do
				local sourceIndex = topIndices[stripIndex + 1]
				local topVertex = tile._Vertices[topAt(sourceIndex)]
				local gridX, gridZ = gridAt(sourceIndex)
				local base = topVertex.baseLocal
				local depth = getVolumeDepth(tile, base.X, base.Z)

				row[stripIndex + 1] = addMeshVertex(
					tile,
					Vector3.new(base.X, -depth * t, base.Z),
					gridX,
					gridZ,
					waveInfluence,
					false
				)
			end

			rows[segment + 1] = row
		end

		for segment = 1, verticalSegments do
			local upper = rows[segment]
			local lower = rows[segment + 1]

			for index = 1, stripCount - 1 do
				local a = upper[index]
				local b = upper[index + 1]
				local c = lower[index]
				local d = lower[index + 1]

				if reverseWinding then
					addMeshFace(tile, a, b, c)
					addMeshFace(tile, b, d, c)
				else
					addMeshFace(tile, a, c, b)
					addMeshFace(tile, b, c, d)
				end
			end
		end
	end

	local function buildBottomMesh(tile: InternalOceanTile)
		local resolution = math.clamp(math.round(tile._Config.VolumeBottomResolution), 1, 24)
		local halfSize = tile.SourcePart.Size * 0.5
		local rows = table.create(resolution + 1)

		for z = 0, resolution do
			local row = table.create(resolution + 1)
			local localZ = (z / resolution - 0.5) * tile.SourcePart.Size.Z

			for x = 0, resolution do
				local localX = (x / resolution - 0.5) * tile.SourcePart.Size.X
				local edgeDistance = math.min(
					math.abs(localX + halfSize.X),
					math.abs(localX - halfSize.X),
					math.abs(localZ + halfSize.Z),
					math.abs(localZ - halfSize.Z)
				)
				local edgeBlend = math.clamp(edgeDistance / math.max(math.min(halfSize.X, halfSize.Z), 1), 0, 1)
				local waveInfluence = tile._Config.VolumeWaveScale * (0.12 + edgeBlend * 0.04)
				local depth = getVolumeDepth(tile, localX, localZ)

				row[x + 1] = addMeshVertex(
					tile,
					Vector3.new(localX, -depth, localZ),
					VOLUME_BOTTOM_GRID_OFFSET + x,
					VOLUME_BOTTOM_GRID_OFFSET + z,
					waveInfluence,
					false
				)
			end

			rows[z + 1] = row
		end

		for z = 1, resolution do
			for x = 1, resolution do
				local a = rows[z][x]
				local b = rows[z][x + 1]
				local c = rows[z + 1][x]
				local d = rows[z + 1][x + 1]

				addMeshFace(tile, a, b, c)
				addMeshFace(tile, b, d, c)
			end
		end
	end

	local function candidateCoversEdgeSample(candidate: BasePart, worldPosition: Vector3, surfaceY: number, tolerance: number): boolean
		local candidateBaseCFrame = getBaseCFrame(candidate)

		if math.abs(candidateBaseCFrame.Position.Y - surfaceY) > math.max(tolerance * 2, 0.5) then
			return false
		end

		local localPosition = candidateBaseCFrame:PointToObjectSpace(worldPosition)
		local halfSize = candidate.Size * 0.5

		return math.abs(localPosition.X) <= halfSize.X + tolerance
			and math.abs(localPosition.Z) <= halfSize.Z + tolerance
	end

	local function hasAdjacentWaterOnEdge(
		tile: InternalOceanTile,
		edgeCenter: Vector3,
		edgeAxis: Vector3,
		edgeNormal: Vector3,
		edgeLength: number
	): boolean
		local sourcePart = tile.SourcePart
		local oceanParent = sourcePart.Parent

		if oceanParent == nil then
			return false
		end

		local tolerance = math.max(tile._Config.VertexSpacing * 0.35, 0.08)
		local probeDistance = math.max(tolerance, 0.05)
		local surfaceY = tile.BaseCFrame.Position.Y
		local coveredSamples = 0
		local sampleOffsets = { -0.375, 0, 0.375 }

		for _, sampleOffset in ipairs(sampleOffsets) do
			local localSample = edgeCenter + edgeAxis * (edgeLength * sampleOffset)
			local worldSample = tile.BaseCFrame:PointToWorldSpace(localSample + edgeNormal * probeDistance)
			local sampleCovered = false

			for _, descendant in ipairs(oceanParent:GetDescendants()) do
				if descendant == sourcePart or not descendant:IsA("BasePart") then
					continue
				end

				if candidateCoversEdgeSample(descendant, worldSample, surfaceY, tolerance) then
					sampleCovered = true
					break
				end
			end

			if not sampleCovered then
				return false
			end

			coveredSamples += 1
		end

		return coveredSamples == #sampleOffsets
	end

	local function buildVolumeMesh(tile: InternalOceanTile)
		if not tile._Config.VolumeEnabled then
			return
		end

		local resolutionX = tile._ResolutionX
		local resolutionZ = tile._ResolutionZ
		local halfSize = tile.SourcePart.Size * 0.5
		local skipNegativeZ = hasAdjacentWaterOnEdge(
			tile,
			Vector3.new(0, 0, -halfSize.Z),
			Vector3.xAxis,
			Vector3.new(0, 0, -1),
			tile.SourcePart.Size.X
		)
		local skipPositiveZ = hasAdjacentWaterOnEdge(
			tile,
			Vector3.new(0, 0, halfSize.Z),
			Vector3.xAxis,
			Vector3.zAxis,
			tile.SourcePart.Size.X
		)
		local skipNegativeX = hasAdjacentWaterOnEdge(
			tile,
			Vector3.new(-halfSize.X, 0, 0),
			Vector3.zAxis,
			Vector3.new(-1, 0, 0),
			tile.SourcePart.Size.Z
		)
		local skipPositiveX = hasAdjacentWaterOnEdge(
			tile,
			Vector3.new(halfSize.X, 0, 0),
			Vector3.zAxis,
			Vector3.xAxis,
			tile.SourcePart.Size.Z
		)

		if not skipNegativeZ then
			buildSideStrip(tile, resolutionX + 1, function(index)
				return gridIndex(resolutionX, index, 0)
			end, function(index)
				return index, 0
			end, true)
		end

		if not skipPositiveZ then
			buildSideStrip(tile, resolutionX + 1, function(index)
				return gridIndex(resolutionX, index, resolutionZ)
			end, function(index)
				return index, resolutionZ
			end, false)
		end

		if not skipNegativeX then
			buildSideStrip(tile, resolutionZ + 1, function(index)
				return gridIndex(resolutionX, 0, index)
			end, function(index)
				return 0, index
			end, false)
		end

		if not skipPositiveX then
			buildSideStrip(tile, resolutionZ + 1, function(index)
				return gridIndex(resolutionX, resolutionX, index)
			end, function(index)
				return resolutionX, index
			end, true)
		end

		buildBottomMesh(tile)
	end

	local function buildMesh(tile: InternalOceanTile)
		buildSurfaceMesh(tile)
		buildVolumeMesh(tile)
	end

	return {
		buildSurfaceMesh = buildSurfaceMesh,
		getVolumeDepth = getVolumeDepth,
		buildVolumeMesh = buildVolumeMesh,
		buildMesh = buildMesh,
	}
end
