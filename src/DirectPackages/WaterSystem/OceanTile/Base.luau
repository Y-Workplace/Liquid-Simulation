--!strict

local AssetService = game:GetService("AssetService")

local WaterDepthMap = require(script.Parent.Parent.WaterDepthMap)
local WaterObstacleMap = require(script.Parent.Parent.WaterObstacleMap)
local WaterBuffer = require(script.Parent.Parent.WaterBuffer)
local Constants = require(script.Parent.Constants)

type TileConfig = any

local WAVE_LOOP_POSITION_BYTES = Constants.WAVE_LOOP_POSITION_BYTES
local WAVE_LOOP_HEIGHT_BYTES = Constants.WAVE_LOOP_HEIGHT_BYTES
local OBSTACLE_IMPACT_VERTEX_BYTES = Constants.OBSTACLE_IMPACT_VERTEX_BYTES
local VERTEX_BAKE_STATIC_BYTES = Constants.VERTEX_BAKE_STATIC_BYTES

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / math.max(edge1 - edge0, 1e-6), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(lerpNumber(a.R, b.R, t), lerpNumber(a.G, b.G, t), lerpNumber(a.B, b.B, t))
end

local function hashNoise(x: number, z: number, seed: number): number
	local value = math.sin((x + seed * 13.17) * 12.9898 + (z - seed * 7.31) * 78.233) * 43758.5453123

	return value - math.floor(value)
end

local function cframeWithUp(position: Vector3, upVector: Vector3): CFrame
	local up = if upVector.Magnitude > 0.001 then upVector.Unit else Vector3.yAxis
	local right = Vector3.yAxis:Cross(up)

	if right.Magnitude <= 0.001 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	local back = right:Cross(up).Unit

	return CFrame.fromMatrix(position, right, up, back)
end

local function normalizeAssetId(assetId: string?): string?
	if assetId == nil or assetId == "" then
		return nil
	end

	if string.find(assetId, "rbxassetid://") == 1 then
		return assetId
	end

	if string.match(assetId, "^%d+$") then
		return "rbxassetid://" .. assetId
	end

	return assetId
end

local function readNumberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)

	if type(value) == "number" then
		return value
	end

	return fallback
end

local function readBooleanAttribute(instance: Instance, name: string, fallback: boolean): boolean
	local value = instance:GetAttribute(name)

	if type(value) == "boolean" then
		return value
	end

	return fallback
end

local getBaseCFrame: (BasePart) -> CFrame

local function createUniformCoordinateBuffer(size: number, resolution: number): buffer
	local coordinates = buffer.create((resolution + 1) * 4)

	for index = 0, resolution do
		buffer.writef32(coordinates, index * 4, (index / resolution - 0.5) * size)
	end

	return coordinates
end

local function createWorldGridCoordinateBuffer(
	baseCFrame: CFrame,
	localAxis: Vector3,
	size: number,
	spacing: number,
	maxResolution: number
): (buffer, number)
	local maxVertexCount = maxResolution + 1
	local coordinates = buffer.create(maxVertexCount * 4)
	local halfSize = size * 0.5
	local axis = baseCFrame:VectorToWorldSpace(localAxis).Unit
	local originAxis = baseCFrame.Position:Dot(axis)
	local startAxis = originAxis - halfSize
	local endAxis = originAxis + halfSize
	local firstGrid = math.ceil((startAxis + 1e-4) / spacing)
	local lastGrid = math.floor((endAxis - 1e-4) / spacing)
	local gridCount = math.max(lastGrid - firstGrid + 1, 0)
	local gridStep = math.max(1, math.ceil((gridCount + 2) / maxVertexCount))
	local count = 1

	buffer.writef32(coordinates, 0, -halfSize)

	for grid = firstGrid, lastGrid, gridStep do
		if count >= maxResolution then
			break
		end

		local localCoordinate = grid * spacing - originAxis

		if localCoordinate > -halfSize + 1e-4 and localCoordinate < halfSize - 1e-4 then
			buffer.writef32(coordinates, count * 4, localCoordinate)
			count += 1
		end
	end

	if count < 2 then
		buffer.writef32(coordinates, count * 4, 0)
		count += 1
	end

	buffer.writef32(coordinates, count * 4, halfSize)

	return coordinates, count
end

local function getGridCoordinates(sourcePart: BasePart, config: TileConfig): (number, number, buffer, buffer)
	local explicitResolution = sourcePart:GetAttribute("OceanResolution")

	if type(explicitResolution) == "number" then
		local resolution = math.clamp(math.round(explicitResolution), 2, config.Resolution)

		return
			resolution,
			resolution,
			createUniformCoordinateBuffer(sourcePart.Size.X, resolution),
			createUniformCoordinateBuffer(sourcePart.Size.Z, resolution)
	end

	local spacing = math.max(readNumberAttribute(sourcePart, "OceanVertexSpacing", config.VertexSpacing), 0.5)
	local maxResolution = math.clamp(math.round(config.Resolution), 2, 160)
	local baseCFrame = getBaseCFrame(sourcePart)
	local xCoordinates, resolutionX = createWorldGridCoordinateBuffer(
		baseCFrame,
		Vector3.xAxis,
		math.max(sourcePart.Size.X, 0.001),
		spacing,
		maxResolution
	)
	local zCoordinates, resolutionZ = createWorldGridCoordinateBuffer(
		baseCFrame,
		Vector3.zAxis,
		math.max(sourcePart.Size.Z, 0.001),
		spacing,
		maxResolution
	)

	return resolutionX, resolutionZ, xCoordinates, zCoordinates
end

local function getSurfaceOffset(sourcePart: BasePart): number
	return readNumberAttribute(sourcePart, "OceanSurfaceOffset", sourcePart.Size.Y * 0.5)
end

local function createWaterBuffer(sourcePart: BasePart, config: TileConfig): WaterBuffer.WaterBuffer?
	if not config.InteractiveWavesEnabled then
		return nil
	end

	return WaterBuffer.new({
		Resolution = config.InteractiveResolution,
		SizeX = math.max(sourcePart.Size.X, 1),
		SizeZ = math.max(sourcePart.Size.Z, 1),
		Damping = config.InteractiveDamping,
		MaxHeight = config.InteractiveMaxHeight,
		MaxVelocity = config.InteractiveMaxVelocity,
		MoveSphereScale = config.InteractiveMoveSphereScale,
	})
end

local function createDepthMap(sourcePart: BasePart, generatedParent: Instance, config: TileConfig): WaterDepthMap.WaterDepthMap?
	if not config.DepthMapEnabled then
		return nil
	end

	local sourceParent = sourcePart.Parent

	return WaterDepthMap.new({
		CFrame = getBaseCFrame(sourcePart),
		SizeX = math.max(sourcePart.Size.X, 1),
		SizeZ = math.max(sourcePart.Size.Z, 1),
		Resolution = config.DepthMapResolution,
		MaxDepth = config.MaxRaycastDepth,
		FallbackDepth = config.FallbackDepth,
		SourcePart = sourcePart,
		IgnoreInstances = if sourceParent ~= nil then { sourceParent, generatedParent } else { generatedParent },
	})
end

local function createObstacleMap(sourcePart: BasePart, generatedParent: Instance, config: TileConfig): WaterObstacleMap.WaterObstacleMap?
	if not config.ObstacleMapEnabled then
		return nil
	end

	local obstacleRoot = workspace:FindFirstChild(config.ObstacleRootName)
	local sourceParent = sourcePart.Parent

	return WaterObstacleMap.new({
		CFrame = getBaseCFrame(sourcePart),
		SizeX = math.max(sourcePart.Size.X, 1),
		SizeZ = math.max(sourcePart.Size.Z, 1),
		Resolution = config.ObstacleMapResolution,
		ObstacleRoot = obstacleRoot,
		RayHeight = config.ObstacleRayHeight,
		RayDepth = config.ObstacleRayDepth,
		InfluenceRadius = config.ObstacleInfluenceRadius,
		ExcludeInstances = if sourceParent ~= nil then { sourceParent, generatedParent } else { sourcePart, generatedParent },
		BakeAnchoredObstacles = config.BakeAnchoredObstacles,
	})
end

local function createEditableMesh(): (EditableMesh?, string?)
	local ok, editableMesh = pcall(function()
		return AssetService:CreateEditableMesh({ FixedSize = false })
	end)

	if not ok then
		return nil, tostring(editableMesh)
	end

	if editableMesh == nil then
		return nil, "AssetService:CreateEditableMesh returned nil"
	end

	return editableMesh, nil
end

local function createMeshPart(editableMesh: EditableMesh): (MeshPart?, string?)
	local ok, meshPart = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))
	end)

	if not ok then
		return nil, tostring(meshPart)
	end

	if meshPart == nil then
		return nil, "AssetService:CreateMeshPartAsync returned nil"
	end

	return meshPart, nil
end

function getBaseCFrame(sourcePart: BasePart): CFrame
	return sourcePart.CFrame * CFrame.new(0, getSurfaceOffset(sourcePart), 0)
end

local function gridIndex(resolutionX: number, x: number, z: number): number
	return z * (resolutionX + 1) + x + 1
end

local function getAxisCell(coordinates: buffer, resolution: number, value: number): (number, number, number)
	local first = buffer.readf32(coordinates, 0)
	local last = buffer.readf32(coordinates, resolution * 4)

	if value <= first then
		return 0, 0, 0
	end

	if value >= last then
		return resolution, resolution, 0
	end

	local low = 0
	local high = resolution

	while high - low > 1 do
		local mid = math.floor((low + high) * 0.5)
		local midValue = buffer.readf32(coordinates, mid * 4)

		if value >= midValue then
			low = mid
		else
			high = mid
		end
	end

	local lowValue = buffer.readf32(coordinates, low * 4)
	local highValue = buffer.readf32(coordinates, high * 4)
	local alpha = math.clamp((value - lowValue) / math.max(highValue - lowValue, 1e-6), 0, 1)

	return low, high, alpha
end

local function distanceToSourcePart(sourcePart: BasePart, worldPosition: Vector3): number
	local localPosition = sourcePart.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = sourcePart.Size * 0.5
	local closestLocal = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	local closestWorld = sourcePart.CFrame:PointToWorldSpace(closestLocal)

	return (worldPosition - closestWorld).Magnitude
end

local function isWorldPositionNearCamera(worldPosition: Vector3, maxDistance: number): boolean
	local camera = workspace.CurrentCamera

	if camera == nil then
		return true
	end

	return (Vector3.new(worldPosition.X, 0, worldPosition.Z) - Vector3.new(camera.CFrame.Position.X, 0, camera.CFrame.Position.Z)).Magnitude <= maxDistance
end

local function wavePositionOffset(frameIndex: number, vertexIndex: number, vertexCount: number, component: number): number
	return (frameIndex * vertexCount + (vertexIndex - 1)) * WAVE_LOOP_POSITION_BYTES + component * 4
end

local function waveHeightOffset(frameIndex: number, vertexIndex: number, vertexCount: number): number
	return (frameIndex * vertexCount + (vertexIndex - 1)) * WAVE_LOOP_HEIGHT_BYTES
end

local function obstacleImpactVertexOffset(index: number): number
	return (index - 1) * OBSTACLE_IMPACT_VERTEX_BYTES
end

local function vertexBakeStaticOffset(vertexIndex: number, component: number): number
	return (vertexIndex - 1) * VERTEX_BAKE_STATIC_BYTES + component * 4
end

return {
	smoothstep = smoothstep,
	lerpNumber = lerpNumber,
	lerpColor = lerpColor,
	hashNoise = hashNoise,
	cframeWithUp = cframeWithUp,
	normalizeAssetId = normalizeAssetId,
	readNumberAttribute = readNumberAttribute,
	readBooleanAttribute = readBooleanAttribute,
	getBaseCFrame = getBaseCFrame,
	getGridCoordinates = getGridCoordinates,
	getSurfaceOffset = getSurfaceOffset,
	createWaterBuffer = createWaterBuffer,
	createDepthMap = createDepthMap,
	createObstacleMap = createObstacleMap,
	createEditableMesh = createEditableMesh,
	createMeshPart = createMeshPart,
	gridIndex = gridIndex,
	getAxisCell = getAxisCell,
	distanceToSourcePart = distanceToSourcePart,
	isWorldPositionNearCamera = isWorldPositionNearCamera,
	wavePositionOffset = wavePositionOffset,
	waveHeightOffset = waveHeightOffset,
	obstacleImpactVertexOffset = obstacleImpactVertexOffset,
	vertexBakeStaticOffset = vertexBakeStaticOffset,
}
