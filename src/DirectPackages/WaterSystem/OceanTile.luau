--!strict

local AssetService = game:GetService("AssetService")

local WaterDepthMap = require(script.Parent.WaterDepthMap)
local WaterObstacleMap = require(script.Parent.WaterObstacleMap)
local WaterBuffer = require(script.Parent.WaterBuffer)
local WaterSurfaceColor = require(script.Parent.WaterSurfaceColor)
local WaveSpectrum = require(script.Parent.WaveSpectrum)

export type TileConfig = {
	Resolution: number,
	VertexSpacing: number,
	MaxDistance: number,
	FadeStartDistance: number,
	PhysicsDistance: number,
	FoamDistance: number,
	Lod0Radius: number,
	Lod1Radius: number,
	Lod2Radius: number,
	LodRecenterDistance: number,
	VolumeEnabled: boolean,
	VolumeSideSpacing: number,
	VolumeVerticalSegments: number,
	VolumeBottomResolution: number,
	VolumeWaveScale: number,
	VolumeMinDepth: number,
	InteractiveWavesEnabled: boolean,
	InteractiveResolution: number,
	InteractiveSimulationIterations: number,
	InteractiveDamping: number,
	InteractiveMaxHeight: number,
	InteractiveMaxVelocity: number,
	InteractiveMoveSphereScale: number,
	InteractiveFoamStrength: number,
	InteractiveFoamSlopeThreshold: number,
	InteractiveFoamVelocityThreshold: number,
	InteractiveLodDissipation: number,
	DepthMapEnabled: boolean,
	DepthMapResolution: number,
	MaxRaycastDepth: number,
	FallbackDepth: number,
	ShallowWaveScale: number,
	DeepWaveScale: number,
	ShoreFoamStrength: number,
	ObstacleMapEnabled: boolean,
	ObstacleRootName: string,
	BakeAnchoredObstacles: boolean,
	ObstacleMapResolution: number,
	ObstacleInfluenceRadius: number,
	ObstacleRayHeight: number,
	ObstacleRayDepth: number,
	ObstacleWaveDamping: number,
	ObstacleFoamStrength: number,
	FoamBufferEnabled: boolean,
	FoamBufferResolution: number,
	FoamBufferDecay: number,
	FoamBufferGrowth: number,
	CrestFoamAlphaBack: number,
	CrestFoamAlphaTop: number,
	CrestFoamAlphaGain: number,
	ShallowDepth: number,
	LakeDepth: number,
	OceanDepth: number,
	WaveLoopFrames: number,
	WaveLoopDuration: number,
	FarWaveDetail: number,
	MidLodVertexStep: number,
	FarLodVertexStep: number,
	ExtremeLodVertexStep: number,
	StaticObstacleSplashEnabled: boolean,
	StaticObstacleSplashInterval: number,
	WaterColor: Color3,
	WaterTintColor: Color3,
	WaterColorBack: Color3,
	WaterColorTop: Color3,
	WaterColorGain: number,
	FoamColor: Color3,
	SurfaceColorBake: boolean,
	SurfaceColorMode: WaterSurfaceColor.SurfaceColorMode,
	RuntimeSurfaceColorEnabled: boolean,
	WaterVertexAlpha: number,
	FoamVertexAlpha: number,
	FoamVertexBoost: number,
	FoamNoiseInfluence: number,
	Transparency: number,
	Reflectance: number,
	HideSourceParts: boolean,
	FoamColorUpdateInterval: number,
	FoamTextureId: string?,
	FoamTextureTransparency: number,
	FoamTextureStudsPerTile: number,
	FoamTextureFromVerticesEnabled: boolean,
	FoamTextureUpdateInterval: number,
	FoamTextureResolution: number,
	FoamNoiseSize: number,
	FoamNoiseSeed: number,
	SeaSprayEnabled: boolean,
	SeaSprayTextureId: string?,
	SeaSprayRate: number,
	SplashParticlesEnabled: boolean,
	SplashParticleTextureId: string?,
	SplashParticleMinSpeed: number,
	SplashParticleMaxSpeed: number,
	SplashParticleEmitScale: number,
}

export type OceanTile = {
	SourcePart: BasePart,
	MeshPart: MeshPart,
	ReflectionMeshPart: MeshPart,
	EditableMesh: EditableMesh,
	BaseCFrame: CFrame,
	Destroy: (self: OceanTile) -> (),
	SetSpectrum: (self: OceanTile, spectrum: WaveSpectrum.WaveSpectrum) -> (),
	SetConfig: (self: OceanTile, config: TileConfig) -> (),
	Update: (self: OceanTile, time: number, camera: Camera?, renderVisible: boolean?) -> (),
	AddDrop: (self: OceanTile, worldPosition: Vector3, radius: number, strength: number) -> (),
	AddFoam: (self: OceanTile, worldPosition: Vector3, radius: number, amount: number) -> (),
	MoveSphere: (self: OceanTile, oldWorldCenter: Vector3, newWorldCenter: Vector3, radius: number, strengthScale: number?) -> (),
	EmitSplash: (self: OceanTile, worldPosition: Vector3, intensity: number, radius: number?, direction: Vector3?) -> (),
	IsInvalid: (self: OceanTile) -> boolean,
	ContainsWorldPosition: (self: OceanTile, worldPosition: Vector3) -> boolean,
	IsPointInWaterVolume: (self: OceanTile, worldPosition: Vector3, time: number, surfacePadding: number?, bottomPadding: number?) -> boolean,
	GetBaseHeightAt: (self: OceanTile, worldPosition: Vector3) -> number,
	GetHeightAt: (self: OceanTile, worldPosition: Vector3, time: number, steps: number?) -> number,
	GetNormalAt: (self: OceanTile, worldPosition: Vector3, time: number) -> Vector3,
	GetVelocityAt: (self: OceanTile, worldPosition: Vector3, time: number) -> Vector3,
}

type VertexState = {
	id: number,
	baseLocal: Vector3,
	gridX: number,
	gridZ: number,
	waveInfluence: number,
	surfaceEnabled: boolean,
}

type EdgeVertexMapper = (number) -> number
type EdgeGridMapper = (number) -> (number, number)

type FaceState = {
	id: number,
	a: number,
	b: number,
	c: number,
}

type InternalOceanTile = OceanTile & {
	_Config: TileConfig,
	_Spectrum: WaveSpectrum.WaveSpectrum,
	_ResolutionX: number,
	_ResolutionZ: number,
	_GridXCoordinates: buffer,
	_GridZCoordinates: buffer,
	_Vertices: { VertexState },
	_Faces: { FaceState },
	_WaterBuffer: WaterBuffer.WaterBuffer?,
	_DepthMap: WaterDepthMap.WaterDepthMap?,
	_ObstacleMap: WaterObstacleMap.WaterObstacleMap?,
	_SeaSprayAttachment: Attachment?,
	_SeaSprayEmitter: ParticleEmitter?,
	_SplashAttachment: Attachment?,
	_SplashEmitter: ParticleEmitter?,
	_SourceLocalTransparencyModifier: number,
	_HiddenSourcePart: boolean,
	_Destroyed: boolean,
	_MeshInvalid: boolean,
	_IsFlat: boolean,
	_LastUpdateTime: number,
	_InteractionWakeFrames: number,
	_RingLodIndices: buffer?,
	_RingLodCount: number,
	_RingLodCenterX: number,
	_RingLodCenterZ: number,
	_RingLodKey: string,
	_RingLodDirty: boolean,
	_WaveLoopPositions: buffer?,
	_WaveLoopHeights: buffer?,
	_WaveLoopFrames: number,
	_WaveLoopFrameStride: number,
	_WaveLoopDuration: number,
	_WaveLoopKey: string,
	_WaveLoopBaking: boolean,
	_WaveLoopMinHeight: number,
	_WaveLoopMaxHeight: number,
	_SurfaceColorIds: { number },
	_SurfaceUVIds: { number },
	_SurfaceImage: EditableImage?,
	_SurfaceImageResolution: number,
	_SurfaceAppearance: SurfaceAppearance?,
	_SurfaceTextureLastUpdateTime: number,
	_SurfaceTextureLastFrameIndex: number,
	_SurfaceTextureFramePixels: buffer?,
	_SurfaceTextureFrameCount: number,
	_SurfaceTextureFrameResolution: number,
	_SurfaceTextureRuntimePixels: buffer?,
	_SurfaceVertexFrameColors: buffer?,
	_SurfaceVertexFrameCount: number,
	_SurfaceVertexLastFrameIndex: number,
	_SurfaceBakeKey: string,
	_SurfaceBakeBaking: boolean,
	_SurfaceColorSupported: boolean,
	_SurfaceUVSupported: boolean,
	_SurfaceAppearanceSupported: boolean,
	_SurfaceColorWarningShown: boolean,
	_ObstacleImpactVertices: buffer?,
	_ObstacleImpactVertexCount: number,
	_LastObstacleSplashTime: number,
}

local OceanTileClass = {}
OceanTileClass.__index = OceanTileClass

local DEFAULT_MATERIAL = Enum.Material.SmoothPlastic
local WAVE_BAKE_VERSION = 21
local WAVE_LOOP_POSITION_STRIDE = 3
local WAVE_LOOP_POSITION_BYTES = WAVE_LOOP_POSITION_STRIDE * 4
local WAVE_LOOP_HEIGHT_BYTES = 4
local SURFACE_IMAGE_PIXEL_BYTES = 4
local SURFACE_VERTEX_COLOR_BYTES = 4
local WAVE_LOOP_SEAM_FRACTION = 0.18
local BAKE_YIELD_CELL_BUDGET = 4096
local MAX_OBSTACLE_IMPACT_VERTICES = 32
local OBSTACLE_IMPACT_VERTEX_BYTES = 2
local RING_LOD_ENTRY_BYTES = 4
local RING_LOD_VERTEX_OFFSET = 0
local RING_LOD_LEVEL_OFFSET = 2
local RING_LEVEL_NEAR = 0
local RING_LEVEL_MID = 1
local RING_LEVEL_FAR = 2
local RING_LEVEL_EXTREME = 3
local VOLUME_BOTTOM_GRID_OFFSET = 32000
local VERTEX_BAKE_STATIC_STRIDE = 6
local VERTEX_BAKE_STATIC_BYTES = VERTEX_BAKE_STATIC_STRIDE * 4
local VERTEX_STATIC_BASE_WORLD_X = 0
local VERTEX_STATIC_BASE_WORLD_Z = 1
local VERTEX_STATIC_WAVE_SCALE = 2
local VERTEX_STATIC_OCEAN_WEIGHT = 3
local VERTEX_STATIC_LAKE_WEIGHT = 4
local VERTEX_STATIC_SHALLOW_WEIGHT = 5

local ensureWaveLoop: (InternalOceanTile) -> ()
local sampleShoreFoamAlpha: (InternalOceanTile, number, number) -> number = function(_tile, _localX, _localZ)
	return 0
end
local composeSurfaceSample: (
	InternalOceanTile,
	WaterSurfaceColor.SurfaceSample,
	number,
	number,
	number
) -> (Color3, number) = function(_tile, sample, _depthAlpha, _localX, _localZ)
	return sample.FinalColor, sample.FinalAlpha
end

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
	return ((vertexIndex - 1) * VERTEX_BAKE_STATIC_STRIDE + component) * 4
end

local function configureMeshPart(meshPart: MeshPart, sourcePart: BasePart, config: TileConfig)
	meshPart.Name = "OceanTile_" .. sourcePart.Name
	meshPart.Anchored = true
	meshPart.CanCollide = false
	meshPart.CanTouch = false
	meshPart.CanQuery = false
	meshPart.CastShadow = false
	meshPart.Material = DEFAULT_MATERIAL
	meshPart.Color = config.WaterColorBack
	meshPart.Transparency = config.Transparency
	meshPart.Reflectance = config.Reflectance
end

local function getReflectionSize(meshPart: MeshPart): Vector3
	local size = meshPart.Size

	return Vector3.new(
		math.max(size.X - 0.1, 0.001),
		math.max(size.Y - 1, 0.001),
		math.max(size.Z - 0.1, 0.001)
	)
end

local function getReflectionCFrame(meshPart: MeshPart): CFrame
	local position = meshPart.Position

	return CFrame.new(position.X, position.Y - 0.5, position.Z)
end

local function configureReflectionMeshPart(meshPart: MeshPart, sourcePart: BasePart, renderMeshPart: MeshPart)
	meshPart.Name = "OceanTileReflection_" .. sourcePart.Name
	meshPart.Anchored = true
	meshPart.CanCollide = false
	meshPart.CanTouch = false
	meshPart.CanQuery = false
	meshPart.CastShadow = false
	meshPart.Material = Enum.Material.Glass
	meshPart.Transparency = 3
	meshPart.Reflectance = 0
	meshPart.Size = getReflectionSize(renderMeshPart)

	local highlight = Instance.new("Highlight")
	highlight.Name = "Highlight"
	highlight.Enabled = false
	highlight.Parent = meshPart
end

local function syncReflectionMeshPart(tile: InternalOceanTile)
	tile.ReflectionMeshPart.Size = getReflectionSize(tile.MeshPart)
	tile.ReflectionMeshPart.CFrame = getReflectionCFrame(tile.MeshPart)
end

local function configureSeaSpray(tile: InternalOceanTile)
	local meshPart = tile.MeshPart
	local textureId = normalizeAssetId(tile._Config.SeaSprayTextureId)

	if not tile._Config.SeaSprayEnabled or textureId == nil then
		if tile._SeaSprayEmitter then
			tile._SeaSprayEmitter.Enabled = false
			tile._SeaSprayEmitter.Rate = 0
		end

		return
	end

	local attachment = tile._SeaSprayAttachment

	if attachment == nil then
		attachment = Instance.new("Attachment")
		attachment.Name = "SeaSprayAttachment"
		attachment.Parent = meshPart
		tile._SeaSprayAttachment = attachment
	end

	local emitter = tile._SeaSprayEmitter

	if emitter == nil then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SeaSpray"
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Lifetime = NumberRange.new(0.45, 1.1)
		emitter.Rate = 0
		emitter.Speed = NumberRange.new(3, 10)
		emitter.SpreadAngle = Vector2.new(22, 22)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-60, 60)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.35, 1.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.65, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.LightEmission = 0.25
		emitter.LockedToPart = false
		emitter.Parent = attachment
		tile._SeaSprayEmitter = emitter
	end

	emitter.Texture = textureId
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(tile._Config.FoamColor)
	emitter.Enabled = true
end

local function configureSplashParticles(tile: InternalOceanTile)
	local meshPart = tile.MeshPart
	local textureId = normalizeAssetId(tile._Config.SplashParticleTextureId) or normalizeAssetId(tile._Config.SeaSprayTextureId)

	if not tile._Config.SplashParticlesEnabled then
		if tile._SplashEmitter then
			tile._SplashEmitter.Enabled = false
		end

		return
	end

	local attachment = tile._SplashAttachment

	if attachment == nil then
		attachment = Instance.new("Attachment")
		attachment.Name = "SplashAttachment"
		attachment.Parent = meshPart
		tile._SplashAttachment = attachment
	end

	local emitter = tile._SplashEmitter

	if emitter == nil then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "ImpactSplash"
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Lifetime = NumberRange.new(0.28, 0.58)
		emitter.Rate = 0
		emitter.Speed = NumberRange.new(
			math.max(tile._Config.SplashParticleMinSpeed * 0.45, 1.2),
			math.max(tile._Config.SplashParticleMaxSpeed * 0.45, 2.4)
		)
		emitter.SpreadAngle = Vector2.new(18, 18)
		emitter.Rotation = NumberRange.new(-18, 18)
		emitter.RotSpeed = NumberRange.new(-28, 28)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65),
			NumberSequenceKeypoint.new(0.22, 2.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.55, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.LightEmission = 0.18
		emitter.LockedToPart = false
		emitter.Parent = attachment
		tile._SplashEmitter = emitter
	end

	if textureId ~= nil then
		emitter.Texture = textureId
	end

	emitter.Lifetime = NumberRange.new(0.28, 0.58)
	emitter.Speed = NumberRange.new(
		math.max(tile._Config.SplashParticleMinSpeed * 0.45, 1.2),
		math.max(tile._Config.SplashParticleMaxSpeed * 0.45, 2.4)
	)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Rotation = NumberRange.new(-18, 18)
	emitter.RotSpeed = NumberRange.new(-28, 28)
	emitter.Color = ColorSequence.new(tile._Config.FoamColor)
	emitter.Enabled = true
end

local function addMeshVertex(
	tile: InternalOceanTile,
	baseLocal: Vector3,
	gridX: number,
	gridZ: number,
	waveInfluence: number,
	surfaceEnabled: boolean
): number
	local editableMesh = tile.EditableMesh
	local vertices = tile._Vertices
	local vertexId = editableMesh:AddVertex(baseLocal)

	table.insert(vertices, {
		id = vertexId,
		baseLocal = baseLocal,
		gridX = gridX,
		gridZ = gridZ,
		waveInfluence = math.clamp(waveInfluence, 0, 1),
		surfaceEnabled = surfaceEnabled,
	})

	return #vertices
end

local function addMeshFace(tile: InternalOceanTile, a: number, b: number, c: number)
	local vertices = tile._Vertices
	local faceId = tile.EditableMesh:AddTriangle(vertices[a].id, vertices[b].id, vertices[c].id)
	local face = {
		id = faceId,
		a = a,
		b = b,
		c = c,
	}

	table.insert(tile._Faces, face)
end

local function markMeshInvalid(tile: InternalOceanTile, err: any)
	if tile._MeshInvalid then
		return
	end

	tile._MeshInvalid = true
	warn("[WaterSystem] EditableMesh update failed; rebuilding tile on next frame: " .. tostring(err))
end

local function trySetVertexPosition(tile: InternalOceanTile, vertexId: number, position: Vector3): boolean
	if tile._Destroyed or tile._MeshInvalid then
		return false
	end

	local ok, err = pcall(function()
		tile.EditableMesh:SetPosition(vertexId, position)
	end)

	if not ok then
		markMeshInvalid(tile, err)
		return false
	end

	return true
end

local function warnSurfaceColorUnsupported(tile: InternalOceanTile, err: any)
	if tile._SurfaceColorWarningShown then
		return
	end

	tile._SurfaceColorWarningShown = true
	warn("[WaterSystem] Surface color resource unavailable; falling back where possible: " .. tostring(err))
end

local function usesSurfaceAppearanceTexture(config: TileConfig): boolean
	return config.SurfaceColorMode == "SurfaceAppearance" or config.SurfaceColorMode == "FoamSurfaceAppearance"
end

local function usesRenderSurfaceAppearance(config: TileConfig): boolean
	return usesSurfaceAppearanceTexture(config) or config.SurfaceColorMode == "PaintVertices"
end

local function usesPaintVertices(config: TileConfig): boolean
	return config.SurfaceColorMode == "PaintVertices" or config.SurfaceColorMode == "FoamSurfaceAppearance"
end

local function shouldUseWhiteMeshColor(config: TileConfig, hasVertexColors: boolean, hasSurfaceAppearance: boolean): boolean
	if config.SurfaceColorMode == "SurfaceAppearance" then
		return hasSurfaceAppearance
	end

	return hasVertexColors
end

local function getSurfaceImageResolution(config: TileConfig): number
	return math.clamp(math.round(config.FoamTextureResolution), 16, 1024)
end

local function addSurfaceColor(tile: InternalOceanTile, color: Color3, alpha: number): number?
	local editableMesh: any = tile.EditableMesh
	local ok, colorId = pcall(function()
		return editableMesh:AddColor(color, alpha)
	end)

	if not ok or type(colorId) ~= "number" then
		tile._SurfaceColorSupported = false
		warnSurfaceColorUnsupported(tile, colorId)
		return nil
	end

	return colorId
end

local function addSurfaceUV(tile: InternalOceanTile, uv: Vector2): number?
	local editableMesh: any = tile.EditableMesh
	local ok, uvId = pcall(function()
		return editableMesh:AddUV(uv)
	end)

	if not ok or type(uvId) ~= "number" then
		tile._SurfaceUVSupported = false
		warnSurfaceColorUnsupported(tile, uvId)
		return nil
	end

	return uvId
end

local function trySetSurfaceFaceColors(tile: InternalOceanTile, face: FaceState): boolean
	local colorA = tile._SurfaceColorIds[face.a]
	local colorB = tile._SurfaceColorIds[face.b]
	local colorC = tile._SurfaceColorIds[face.c]

	if colorA == nil or colorB == nil or colorC == nil then
		return false
	end

	local editableMesh: any = tile.EditableMesh
	local ok, err = pcall(function()
		editableMesh:SetFaceColors(face.id, { colorA, colorB, colorC })
	end)

	if not ok then
		tile._SurfaceColorSupported = false
		warnSurfaceColorUnsupported(tile, err)
		return false
	end

	return true
end

local function trySetSurfaceFaceUVs(tile: InternalOceanTile, face: FaceState): boolean
	local uvA = tile._SurfaceUVIds[face.a]
	local uvB = tile._SurfaceUVIds[face.b]
	local uvC = tile._SurfaceUVIds[face.c]

	if uvA == nil or uvB == nil or uvC == nil then
		return false
	end

	local editableMesh: any = tile.EditableMesh
	local ok, err = pcall(function()
		editableMesh:SetFaceUVs(face.id, { uvA, uvB, uvC })
	end)

	if not ok then
		tile._SurfaceUVSupported = false
		warnSurfaceColorUnsupported(tile, err)
		return false
	end

	return true
end

local function trySetSurfaceColor(tile: InternalOceanTile, colorId: number, color: Color3, alpha: number): boolean
	local editableMesh: any = tile.EditableMesh
	local ok, err = pcall(function()
		editableMesh:SetColor(colorId, color)
		editableMesh:SetColorAlpha(colorId, alpha)
	end)

	if ok then
		return true
	end

	local fallbackOk, fallbackErr = pcall(function()
		editableMesh:SetColor(colorId, color, alpha)
	end)

	if not fallbackOk then
		tile._SurfaceColorSupported = false
		warnSurfaceColorUnsupported(tile, fallbackErr or err)
		return false
	end

	return true
end

local function destroySurfaceAppearance(tile: InternalOceanTile)
	if tile._SurfaceAppearance ~= nil then
		tile._SurfaceAppearance:Destroy()
		tile._SurfaceAppearance = nil
	end

	if tile._SurfaceImage ~= nil then
		pcall(function()
			tile._SurfaceImage:Destroy()
		end)
		tile._SurfaceImage = nil
	end

	tile._SurfaceImageResolution = 0
	tile._SurfaceTextureLastUpdateTime = -math.huge
	tile._SurfaceTextureLastFrameIndex = -1
	tile._SurfaceTextureRuntimePixels = nil
end

local function resetSurfaceBake(tile: InternalOceanTile)
	tile._SurfaceTextureFramePixels = nil
	tile._SurfaceTextureFrameCount = 0
	tile._SurfaceTextureFrameResolution = 0
	tile._SurfaceTextureRuntimePixels = nil
	tile._SurfaceTextureLastFrameIndex = -1
	tile._SurfaceVertexFrameColors = nil
	tile._SurfaceVertexFrameCount = 0
	tile._SurfaceVertexLastFrameIndex = -1
	tile._SurfaceBakeKey = ""
	tile._SurfaceBakeBaking = false
end

local function ensureSurfaceUVs(tile: InternalOceanTile): boolean
	if not tile._SurfaceUVSupported then
		return false
	end

	if #tile._SurfaceUVIds == #tile._Vertices then
		return true
	end

	table.clear(tile._SurfaceUVIds)

	local sizeX = math.max(tile.SourcePart.Size.X, 0.001)
	local sizeZ = math.max(tile.SourcePart.Size.Z, 0.001)

	for vertexIndex, vertex in ipairs(tile._Vertices) do
		local u = math.clamp(vertex.baseLocal.X / sizeX + 0.5, 0, 1)
		local v = math.clamp(0.5 - vertex.baseLocal.Z / sizeZ, 0, 1)
		local uvId = addSurfaceUV(tile, Vector2.new(u, v))

		if uvId == nil then
			return false
		end

		tile._SurfaceUVIds[vertexIndex] = uvId
	end

	for _, face in ipairs(tile._Faces) do
		if not trySetSurfaceFaceUVs(tile, face) then
			return false
		end
	end

	return true
end

local function ensureSurfaceAppearance(tile: InternalOceanTile): boolean
	if not usesRenderSurfaceAppearance(tile._Config) then
		destroySurfaceAppearance(tile)
		return false
	end

	if not usesSurfaceAppearanceTexture(tile._Config) then
		if tile._SurfaceAppearance ~= nil and tile._SurfaceImage == nil then
			return true
		end

		destroySurfaceAppearance(tile)

		local ok, surfaceOrError = pcall(function()
			return Instance.new("SurfaceAppearance")
		end)

		if not ok or surfaceOrError == nil then
			warnSurfaceColorUnsupported(tile, surfaceOrError)
			return false
		end

		local surface = surfaceOrError :: SurfaceAppearance

		surface.Name = "WaterSurfacePipeline"
		surface.Parent = tile.MeshPart
		tile._SurfaceAppearance = surface
		tile._SurfaceImage = nil
		tile._SurfaceImageResolution = 0
		tile._SurfaceTextureLastUpdateTime = -math.huge

		return true
	end

	if not tile._SurfaceAppearanceSupported then
		return false
	end

	local resolution = getSurfaceImageResolution(tile._Config)

	if
		tile._SurfaceAppearance ~= nil
		and tile._SurfaceImage ~= nil
		and tile._SurfaceImageResolution == resolution
	then
		return true
	end

	destroySurfaceAppearance(tile)

	local ok, imageOrError = pcall(function()
		return AssetService:CreateEditableImage({
			Size = Vector2.new(resolution, resolution),
		})
	end)

	if not ok or imageOrError == nil then
		tile._SurfaceAppearanceSupported = false
		warnSurfaceColorUnsupported(tile, imageOrError)
		return false
	end

	local image = imageOrError :: EditableImage
	local surfaceOk, surfaceOrError = pcall(function()
		return AssetService:CreateSurfaceAppearanceAsync({
			ColorMap = Content.fromObject(image),
		})
	end)

	if not surfaceOk or surfaceOrError == nil then
		tile._SurfaceAppearanceSupported = false
		pcall(function()
			image:Destroy()
		end)
		warnSurfaceColorUnsupported(tile, surfaceOrError)
		return false
	end

	local surface = surfaceOrError :: SurfaceAppearance

	surface.Name = "WaterSurfaceColor"
	surface.Parent = tile.MeshPart
	tile._SurfaceImage = image
	tile._SurfaceImageResolution = resolution
	tile._SurfaceAppearance = surface
	tile._SurfaceTextureLastUpdateTime = -math.huge

	return true
end

local function createSurfaceColorConfig(config: TileConfig): WaterSurfaceColor.SurfaceColorConfig
	return WaterSurfaceColor.BuildConfig({
		SurfaceColorBake = config.SurfaceColorBake,
		SurfaceColorMode = config.SurfaceColorMode,
		WaterColorBack = config.WaterColorBack,
		WaterColorTop = config.WaterColorTop,
		WaterColorGain = config.WaterColorGain,
		WaterVertexAlpha = config.WaterVertexAlpha,
		FoamColor = config.FoamColor,
		CrestFoamAlphaBack = config.CrestFoamAlphaBack,
		CrestFoamAlphaTop = config.CrestFoamAlphaTop,
		CrestFoamAlphaGain = config.CrestFoamAlphaGain,
	})
end

local function ensureSurfaceVertexColors(tile: InternalOceanTile): boolean
	if not tile._SurfaceColorSupported then
		return false
	end

	if #tile._SurfaceColorIds == #tile._Vertices then
		return true
	end

	table.clear(tile._SurfaceColorIds)

	for vertexIndex = 1, #tile._Vertices do
		local colorId = addSurfaceColor(tile, tile._Config.WaterColorBack, 0)

		if colorId == nil then
			return false
		end

		tile._SurfaceColorIds[vertexIndex] = colorId
	end

	for _, face in ipairs(tile._Faces) do
		if not trySetSurfaceFaceColors(tile, face) then
			return false
		end
	end

	return true
end

local function paintSurfaceVertex(
	tile: InternalOceanTile,
	surfaceColorConfig: WaterSurfaceColor.SurfaceColorConfig,
	vertexIndex: number,
	height: number,
	includeFoam: boolean,
	depthAlpha: number,
	localX: number,
	localZ: number
)
	if not tile._SurfaceColorSupported then
		return
	end

	local colorId = tile._SurfaceColorIds[vertexIndex]

	if colorId == nil then
		return
	end

	local normalizedHeight = WaterSurfaceColor.NormalizeHeight(height, tile._WaveLoopMinHeight, tile._WaveLoopMaxHeight)
	if includeFoam then
		local shoreFoamAlpha = sampleShoreFoamAlpha(tile, localX, localZ)
		local fullSample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
		local finalColor, finalAlpha = composeSurfaceSample(tile, fullSample, depthAlpha, localX, localZ)

		trySetSurfaceColor(tile, colorId, finalColor, finalAlpha)
	else
		local waterSample = WaterSurfaceColor.SampleWater(surfaceColorConfig, normalizedHeight, depthAlpha)
		trySetSurfaceColor(tile, colorId, waterSample.Color, waterSample.Alpha)
	end
end

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

local function sampleDepth(depthMap: WaterDepthMap.WaterDepthMap?, config: TileConfig, localX: number, localZ: number): number
	if depthMap == nil then
		return config.FallbackDepth
	end

	return depthMap:SampleDepth(localX, localZ)
end

local function sampleWaterDepthAlpha(tile: InternalOceanTile, localX: number, localZ: number): number
	local config = tile._Config
	local oceanDepth = math.max(config.OceanDepth, math.max(config.LakeDepth, config.ShallowDepth + 0.001) + 0.001)
	local depth = sampleDepth(tile._DepthMap, config, localX, localZ)

	return smoothstep(config.ShallowDepth, oceanDepth, depth)
end

sampleShoreFoamAlpha = function(tile: InternalOceanTile, localX: number, localZ: number): number
	local config = tile._Config

	if tile._DepthMap == nil or config.ShoreFoamStrength <= 0 then
		return 0
	end

	local depth = sampleDepth(tile._DepthMap, config, localX, localZ)
	local shallowBand = math.max(config.ShallowDepth, 0.001)
	local shoreFactor = 1 - smoothstep(shallowBand * 0.2, shallowBand, depth)

	return math.clamp(shoreFactor * config.ShoreFoamStrength, 0, 1)
end

local function sampleFoamBreakup(tile: InternalOceanTile, localX: number, localZ: number): number
	local config = tile._Config
	local influence = math.clamp(config.FoamNoiseInfluence, 0, 1)

	if influence <= 0 then
		return 1
	end

	local maxSize = math.max(tile.SourcePart.Size.X, tile.SourcePart.Size.Z, 1)
	local noiseCellSize = math.max(maxSize / math.max(config.FoamNoiseSize, 1), 1)
	local scale = math.max(math.min(config.FoamTextureStudsPerTile, noiseCellSize), 0.5)
	local sampleX = localX / scale
	local sampleZ = localZ / scale
	local x0 = math.floor(sampleX)
	local z0 = math.floor(sampleZ)
	local tx = smoothstep(0, 1, sampleX - x0)
	local tz = smoothstep(0, 1, sampleZ - z0)
	local seed = config.FoamNoiseSeed
	local n00 = hashNoise(x0, z0, seed)
	local n10 = hashNoise(x0 + 1, z0, seed)
	local n01 = hashNoise(x0, z0 + 1, seed)
	local n11 = hashNoise(x0 + 1, z0 + 1, seed)
	local nx0 = lerpNumber(n00, n10, tx)
	local nx1 = lerpNumber(n01, n11, tx)
	local noise = lerpNumber(nx0, nx1, tz)
	local mask = 0.55 + noise * 0.45

	return lerpNumber(1, mask, influence)
end

local function resolveFoamAlpha(
	tile: InternalOceanTile,
	foamAlpha: number,
	depthAlpha: number,
	localX: number,
	localZ: number
): number
	if foamAlpha <= 0 then
		return 0
	end

	local shallowFade = lerpNumber(0.18, 1, math.clamp(depthAlpha, 0, 1))

	return math.clamp(foamAlpha * shallowFade * sampleFoamBreakup(tile, localX, localZ), 0, 1)
end

composeSurfaceSample = function(
	tile: InternalOceanTile,
	sample: WaterSurfaceColor.SurfaceSample,
	depthAlpha: number,
	localX: number,
	localZ: number
): (Color3, number)
	local foamAlpha = resolveFoamAlpha(tile, sample.FoamAlpha, depthAlpha, localX, localZ)
	local finalColor = lerpColor(sample.WaterColor, sample.FoamColor, foamAlpha)
	local finalAlpha = math.clamp(sample.WaterAlpha + (1 - sample.WaterAlpha) * foamAlpha, 0, 1)

	return finalColor, finalAlpha
end

local function sampleObstacleImpact(obstacleMap: WaterObstacleMap.WaterObstacleMap?, localX: number, localZ: number): number
	if obstacleMap == nil then
		return 0
	end

	return obstacleMap:GetFoamSeed(localX, localZ)
end

local function sampleObstacleAttenuation(
	obstacleMap: WaterObstacleMap.WaterObstacleMap?,
	localX: number,
	localZ: number,
	strength: number
): number
	if obstacleMap == nil then
		return 1
	end

	return obstacleMap:GetWaveAttenuation(localX, localZ, strength)
end

local function getWaveLoopGeometryKey(config: TileConfig): string
	return `{WAVE_BAKE_VERSION}:{math.clamp(math.round(config.WaveLoopFrames), 2, 240)}:{math.max(config.WaveLoopDuration, 0.25)}:{config.ShallowWaveScale}:{config.DeepWaveScale}:{config.ShallowDepth}:{config.LakeDepth}:{config.OceanDepth}:{config.ObstacleWaveDamping}`
end

local function getWaveLoopKey(config: TileConfig): string
	return getWaveLoopGeometryKey(config)
end

local function bakeWaveLoop(tile: InternalOceanTile)
	local config = tile._Config
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

	for vertexIndex, vertex in ipairs(tile._Vertices) do
		local localX = vertex.baseLocal.X
		local localZ = vertex.baseLocal.Z
		local baseWorld = baseCFrame:PointToWorldSpace(vertex.baseLocal)
		local depth = sampleDepth(tile._DepthMap, config, localX, localZ)
		local shallowToLake = smoothstep(config.ShallowDepth, lakeDepth, depth)
		local lakeToOcean = smoothstep(lakeDepth, oceanDepth, depth)
		local shallowWeight = 1 - shallowToLake
		local oceanWeight = lakeToOcean
		local lakeWeight = shallowToLake * (1 - lakeToOcean)
		local deepFactor = smoothstep(config.ShallowDepth, oceanDepth, depth)
		local obstacleSeed = if vertex.surfaceEnabled then sampleObstacleImpact(tile._ObstacleMap, localX, localZ) else 0
		local obstacleAttenuation = sampleObstacleAttenuation(tile._ObstacleMap, localX, localZ, config.ObstacleWaveDamping)
		local depthWaveScale = config.ShallowWaveScale + (config.DeepWaveScale - config.ShallowWaveScale) * deepFactor
		local waveScale = depthWaveScale * obstacleAttenuation * vertex.waveInfluence

		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_BASE_WORLD_X), baseWorld.X)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_BASE_WORLD_Z), baseWorld.Z)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_WAVE_SCALE), waveScale)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_OCEAN_WEIGHT), oceanWeight)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_LAKE_WEIGHT), lakeWeight)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_SHALLOW_WEIGHT), shallowWeight)

		if vertex.surfaceEnabled and obstacleSeed >= 0.55 and obstacleVertexCount < MAX_OBSTACLE_IMPACT_VERTICES then
			obstacleVertexCount += 1
			buffer.writeu16(obstacleVertices, obstacleImpactVertexOffset(obstacleVertexCount), vertexIndex)
		end

		processedSinceYield += 1

		if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
			processedSinceYield = 0
			task.wait()
		end
	end

	for frameIndex = 0, frames - 1 do
		local bakeTime = (frameIndex / frames) * duration

		for vertexIndex = 1, vertexCount do
			local staticOffset = (vertexIndex - 1) * VERTEX_BAKE_STATIC_BYTES
			local baseWorldX = buffer.readf32(static, staticOffset + VERTEX_STATIC_BASE_WORLD_X * 4)
			local baseWorldZ = buffer.readf32(static, staticOffset + VERTEX_STATIC_BASE_WORLD_Z * 4)
			local oceanWeight = buffer.readf32(static, staticOffset + VERTEX_STATIC_OCEAN_WEIGHT * 4)
			local lakeWeight = buffer.readf32(static, staticOffset + VERTEX_STATIC_LAKE_WEIGHT * 4)
			local shallowWeight = buffer.readf32(static, staticOffset + VERTEX_STATIC_SHALLOW_WEIGHT * 4)
			local displacementX, sampleHeight, displacementZ, _sampleFoam =
				tile._Spectrum:SampleBakedWeighted3XZ(baseWorldX, baseWorldZ, bakeTime, 1, oceanWeight, lakeWeight, shallowWeight)
			local loopProgress = frameIndex / frames
			local seamStart = 1 - WAVE_LOOP_SEAM_FRACTION

			if loopProgress >= seamStart then
				local seamAlpha = smoothstep(seamStart, 1, loopProgress)
				local previousX, previousHeight, previousZ, _previousFoam =
					tile._Spectrum:SampleBakedWeighted3XZ(baseWorldX, baseWorldZ, bakeTime - duration, 1, oceanWeight, lakeWeight, shallowWeight)

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
			end
		end
	end

	tile._WaveLoopPositions = positions
	tile._WaveLoopHeights = heights
	tile._WaveLoopFrames = frames
	tile._WaveLoopFrameStride = vertexCount
	tile._WaveLoopDuration = duration
	tile._WaveLoopMinHeight = if minHeight < math.huge then minHeight else 0
	tile._WaveLoopMaxHeight = if maxHeight > -math.huge then maxHeight else 0
	tile._ObstacleImpactVertices = obstacleVertices
	tile._ObstacleImpactVertexCount = obstacleVertexCount
	tile._WaveLoopKey = getWaveLoopKey(config)
end

ensureWaveLoop = function(tile: InternalOceanTile)
	local config = tile._Config
	local key = getWaveLoopKey(config)

	if
		tile._WaveLoopPositions ~= nil
		and tile._WaveLoopHeights ~= nil
		and tile._WaveLoopKey == key
	then
		return
	end

	if tile._WaveLoopBaking then
		while tile._WaveLoopBaking do
			task.wait()
		end

		return
	end

	tile._WaveLoopBaking = true

	local ok, err = pcall(function()
		bakeWaveLoop(tile)
	end)

	tile._WaveLoopBaking = false

	if not ok then
		warn("[WaterSystem] Wave loop bake failed: " .. tostring(err))
	end
end

local function getWaveLoopFrame(tile: InternalOceanTile, time: number): (number, number, number)
	local frames = math.max(tile._WaveLoopFrames, 1)
	local framePosition = ((time % tile._WaveLoopDuration) / tile._WaveLoopDuration) * frames
	local frameA = math.floor(framePosition) % frames
	local frameB = (frameA + 1) % frames
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

	if positions == nil then
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

	if heights == nil then
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

local function surfaceImagePixelOffset(resolution: number, x: number, y: number): number
	return (y * resolution + x) * SURFACE_IMAGE_PIXEL_BYTES
end

local function surfaceTextureFrameOffset(frameIndex: number, resolution: number): number
	return frameIndex * resolution * resolution * SURFACE_IMAGE_PIXEL_BYTES
end

local function surfaceVertexColorOffset(frameIndex: number, vertexIndex: number, vertexCount: number): number
	return (frameIndex * vertexCount + (vertexIndex - 1)) * SURFACE_VERTEX_COLOR_BYTES
end

local function writeColorPixel(pixels: buffer, offset: number, color: Color3, alpha: number)
	buffer.writeu8(pixels, offset, math.clamp(math.floor(color.R * 255 + 0.5), 0, 255))
	buffer.writeu8(pixels, offset + 1, math.clamp(math.floor(color.G * 255 + 0.5), 0, 255))
	buffer.writeu8(pixels, offset + 2, math.clamp(math.floor(color.B * 255 + 0.5), 0, 255))
	buffer.writeu8(pixels, offset + 3, math.clamp(math.floor(alpha * 255 + 0.5), 0, 255))
end

local function getDiscreteWaveLoopFrame(tile: InternalOceanTile, time: number): number
	local frames = math.max(tile._WaveLoopFrames, 1)
	local framePosition = ((time % tile._WaveLoopDuration) / tile._WaveLoopDuration) * frames

	return math.floor(framePosition + 0.5) % frames
end

local function sampleBakedHeightFrame(
	tile: InternalOceanTile,
	heights: buffer,
	frameIndex: number,
	vertexCount: number,
	localX: number,
	localZ: number
): number
	local resolutionX = tile._ResolutionX
	local resolutionZ = tile._ResolutionZ
	local x0, x1, tx = getAxisCell(tile._GridXCoordinates, resolutionX, localX)
	local z0, z1, tz = getAxisCell(tile._GridZCoordinates, resolutionZ, localZ)
	local d00 = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, gridIndex(resolutionX, x0, z0))
	local d10 = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, gridIndex(resolutionX, x1, z0))
	local d01 = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, gridIndex(resolutionX, x0, z1))
	local d11 = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, gridIndex(resolutionX, x1, z1))
	local a = d00 + (d10 - d00) * tx
	local b = d01 + (d11 - d01) * tx

	return a + (b - a) * tz
end

local function getSurfaceBakeKey(tile: InternalOceanTile): string
	local config = tile._Config

	return `{getWaveLoopKey(config)}:{config.SurfaceColorMode}:{config.WaterColorBack.R}:{config.WaterColorBack.G}:{config.WaterColorBack.B}:{config.WaterColorTop.R}:{config.WaterColorTop.G}:{config.WaterColorTop.B}:{config.WaterColorGain}:{config.WaterVertexAlpha}:{config.FoamColor.R}:{config.FoamColor.G}:{config.FoamColor.B}:{config.CrestFoamAlphaBack}:{config.CrestFoamAlphaTop}:{config.CrestFoamAlphaGain}:{config.ShoreFoamStrength}:{config.ShallowDepth}:{config.LakeDepth}:{config.OceanDepth}:{config.FoamNoiseInfluence}:{config.FoamNoiseSize}:{config.FoamNoiseSeed}:{config.FoamTextureStudsPerTile}:{getSurfaceImageResolution(config)}:{#tile._Vertices}:{tile._WaveLoopMinHeight}:{tile._WaveLoopMaxHeight}`
end

local function writeBakedVertexFrameColor(
	tile: InternalOceanTile,
	colors: buffer,
	surfaceColorConfig: WaterSurfaceColor.SurfaceColorConfig,
	heights: buffer,
	frameIndex: number,
	vertexIndex: number,
	vertexCount: number,
	includeFoam: boolean
)
	local vertex = tile._Vertices[vertexIndex]

	if vertex == nil then
		return
	end

	local localX = vertex.baseLocal.X
	local localZ = vertex.baseLocal.Z
	local height = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, vertexIndex)
	local normalizedHeight = WaterSurfaceColor.NormalizeHeight(height, tile._WaveLoopMinHeight, tile._WaveLoopMaxHeight)
	local depthAlpha = sampleWaterDepthAlpha(tile, localX, localZ)
	local offset = surfaceVertexColorOffset(frameIndex, vertexIndex, vertexCount)

	if includeFoam then
		local shoreFoamAlpha = sampleShoreFoamAlpha(tile, localX, localZ)
		local sample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
		local finalColor, finalAlpha = composeSurfaceSample(tile, sample, depthAlpha, localX, localZ)

		writeColorPixel(colors, offset, finalColor, finalAlpha)
	else
		local waterSample = WaterSurfaceColor.SampleWater(surfaceColorConfig, normalizedHeight, depthAlpha)

		writeColorPixel(colors, offset, waterSample.Color, waterSample.Alpha)
	end
end

local function writeBakedTextureFramePixel(
	tile: InternalOceanTile,
	pixels: buffer,
	surfaceColorConfig: WaterSurfaceColor.SurfaceColorConfig,
	heights: buffer,
	frameIndex: number,
	vertexCount: number,
	resolution: number,
	x: number,
	y: number,
	foamOnly: boolean
)
	local size = tile.SourcePart.Size
	local u = if resolution > 1 then x / (resolution - 1) else 0
	local v = if resolution > 1 then y / (resolution - 1) else 0
	local localX = (u - 0.5) * size.X
	local localZ = (0.5 - v) * size.Z
	local height = sampleBakedHeightFrame(tile, heights, frameIndex, vertexCount, localX, localZ)
	local normalizedHeight = WaterSurfaceColor.NormalizeHeight(height, tile._WaveLoopMinHeight, tile._WaveLoopMaxHeight)
	local depthAlpha = sampleWaterDepthAlpha(tile, localX, localZ)
	local offset = surfaceTextureFrameOffset(frameIndex, resolution) + surfaceImagePixelOffset(resolution, x, y)
	local shoreFoamAlpha = sampleShoreFoamAlpha(tile, localX, localZ)

	if foamOnly then
		local foam = WaterSurfaceColor.SampleFoam(surfaceColorConfig, normalizedHeight, shoreFoamAlpha)
		local foamAlpha = resolveFoamAlpha(tile, foam.Alpha, depthAlpha, localX, localZ)

		writeColorPixel(pixels, offset, foam.Color, foamAlpha)
	else
		local sample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
		local finalColor, finalAlpha = composeSurfaceSample(tile, sample, depthAlpha, localX, localZ)

		writeColorPixel(pixels, offset, finalColor, finalAlpha)
	end
end

local function bakeSurfaceFrames(tile: InternalOceanTile, key: string): boolean
	local heights = tile._WaveLoopHeights

	if heights == nil then
		return false
	end

	local config = tile._Config
	local frames = math.max(tile._WaveLoopFrames, 1)
	local vertexCount = #tile._Vertices
	local surfaceColorConfig = createSurfaceColorConfig(config)
	local bakeVertexColors = usesPaintVertices(config)
	local bakeTexture = usesSurfaceAppearanceTexture(config)
	local vertexColors = if bakeVertexColors
		then buffer.create(vertexCount * frames * SURFACE_VERTEX_COLOR_BYTES)
		else nil
	local resolution = if bakeTexture then getSurfaceImageResolution(config) else 0
	local texturePixels = if bakeTexture
		then buffer.create(resolution * resolution * frames * SURFACE_IMAGE_PIXEL_BYTES)
		else nil
	local includeVertexFoam = config.SurfaceColorMode == "PaintVertices"
	local textureFoamOnly = config.SurfaceColorMode == "FoamSurfaceAppearance"
	local processedSinceYield = 0

	for frameIndex = 0, frames - 1 do
		if vertexColors ~= nil then
			for vertexIndex = 1, vertexCount do
				writeBakedVertexFrameColor(
					tile,
					vertexColors,
					surfaceColorConfig,
					heights,
					frameIndex,
					vertexIndex,
					vertexCount,
					includeVertexFoam
				)

				processedSinceYield += 1

				if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
					processedSinceYield = 0
					task.wait()
				end
			end
		end

		if texturePixels ~= nil then
			for y = 0, resolution - 1 do
				for x = 0, resolution - 1 do
					writeBakedTextureFramePixel(
						tile,
						texturePixels,
						surfaceColorConfig,
						heights,
						frameIndex,
						vertexCount,
						resolution,
						x,
						y,
						textureFoamOnly
					)

					processedSinceYield += 1

					if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
						processedSinceYield = 0
						task.wait()
					end
				end
			end
		end
	end

	tile._SurfaceVertexFrameColors = vertexColors
	tile._SurfaceVertexFrameCount = if vertexColors ~= nil then frames else 0
	tile._SurfaceVertexLastFrameIndex = -1
	tile._SurfaceTextureFramePixels = texturePixels
	tile._SurfaceTextureFrameCount = if texturePixels ~= nil then frames else 0
	tile._SurfaceTextureFrameResolution = resolution
	tile._SurfaceTextureRuntimePixels = nil
	tile._SurfaceTextureLastFrameIndex = -1
	tile._SurfaceBakeKey = key

	return true
end

local function ensureSurfaceFrameBake(tile: InternalOceanTile): boolean
	local config = tile._Config

	if not config.SurfaceColorBake then
		return false
	end

	if not usesPaintVertices(config) and not usesSurfaceAppearanceTexture(config) then
		return false
	end

	if tile._WaveLoopHeights == nil then
		return false
	end

	local needsVertexColors = usesPaintVertices(config)
	local needsTexture = usesSurfaceAppearanceTexture(config)
	local hasVertexColors = not needsVertexColors or tile._SurfaceVertexFrameColors ~= nil
	local hasTexture = not needsTexture
		or (
			tile._SurfaceTextureFramePixels ~= nil
			and tile._SurfaceTextureFrameResolution == getSurfaceImageResolution(config)
		)

	if tile._SurfaceBakeKey ~= "" and hasVertexColors and hasTexture then
		return true
	end

	local key = getSurfaceBakeKey(tile)

	if tile._SurfaceBakeBaking then
		while tile._SurfaceBakeBaking do
			task.wait()
		end

		return tile._SurfaceBakeKey == key
	end

	if needsVertexColors and not ensureSurfaceVertexColors(tile) then
		return false
	end

	if needsTexture and (not ensureSurfaceUVs(tile) or not ensureSurfaceAppearance(tile)) then
		return false
	end

	tile._SurfaceBakeBaking = true
	local baked = false

	local ok, err = pcall(function()
		baked = bakeSurfaceFrames(tile, key)
	end)

	tile._SurfaceBakeBaking = false

	if not ok or not baked then
		resetSurfaceBake(tile)
		warn("[WaterSystem] Surface RGBA bake failed: " .. tostring(err or "missing wave height bake"))
		return false
	end

	return true
end

local function applyBakedSurfaceVertexColors(tile: InternalOceanTile, time: number): boolean
	local colors = tile._SurfaceVertexFrameColors

	if colors == nil or tile._SurfaceVertexFrameCount <= 0 then
		return false
	end

	if not ensureSurfaceVertexColors(tile) then
		return false
	end

	local frameIndex = getDiscreteWaveLoopFrame(tile, time) % tile._SurfaceVertexFrameCount

	if tile._SurfaceVertexLastFrameIndex == frameIndex then
		return true
	end

	local vertexCount = #tile._Vertices

	for vertexIndex, colorId in ipairs(tile._SurfaceColorIds) do
		local offset = surfaceVertexColorOffset(frameIndex, vertexIndex, vertexCount)
		local r = buffer.readu8(colors, offset)
		local g = buffer.readu8(colors, offset + 1)
		local b = buffer.readu8(colors, offset + 2)
		local a = buffer.readu8(colors, offset + 3) / 255

		if not trySetSurfaceColor(tile, colorId, Color3.fromRGB(r, g, b), a) then
			return false
		end
	end

	tile._SurfaceVertexLastFrameIndex = frameIndex
	return true
end

local function applyBakedSurfaceAppearanceTexture(tile: InternalOceanTile, time: number): boolean
	if not ensureSurfaceAppearance(tile) then
		return false
	end

	local image = tile._SurfaceImage
	local frames = tile._SurfaceTextureFramePixels

	if image == nil or frames == nil or tile._SurfaceTextureFrameCount <= 0 then
		return false
	end

	local resolution = tile._SurfaceTextureFrameResolution
	local frameIndex = getDiscreteWaveLoopFrame(tile, time) % tile._SurfaceTextureFrameCount

	if tile._SurfaceTextureLastFrameIndex == frameIndex then
		return true
	end

	local frameBytes = resolution * resolution * SURFACE_IMAGE_PIXEL_BYTES

	if tile._SurfaceTextureRuntimePixels == nil then
		tile._SurfaceTextureRuntimePixels = buffer.create(frameBytes)
	end

	local pixels = tile._SurfaceTextureRuntimePixels

	if pixels == nil then
		return false
	end

	local ok, err = pcall(function()
		buffer.copy(pixels, 0, frames, surfaceTextureFrameOffset(frameIndex, resolution), frameBytes)
		image:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(resolution, resolution), pixels)
	end)

	if not ok then
		tile._SurfaceAppearanceSupported = false
		warnSurfaceColorUnsupported(tile, err)
		return false
	end

	tile._SurfaceTextureLastFrameIndex = frameIndex
	tile._SurfaceTextureLastUpdateTime = time
	return true
end

local function updateSurfaceAppearanceTexture(tile: InternalOceanTile, time: number, waterBuffer: WaterBuffer.WaterBuffer?)
	if not ensureSurfaceAppearance(tile) then
		return
	end

	local image = tile._SurfaceImage

	if image == nil then
		return
	end

	local interval = math.max(tile._Config.FoamTextureUpdateInterval, 0)

	if interval > 0 and time - tile._SurfaceTextureLastUpdateTime < interval then
		return
	end

	tile._SurfaceTextureLastUpdateTime = time

	local resolution = math.max(tile._SurfaceImageResolution, 1)
	local pixels = buffer.create(resolution * resolution * SURFACE_IMAGE_PIXEL_BYTES)
	local size = tile.SourcePart.Size
	local surfaceColorConfig = createSurfaceColorConfig(tile._Config)
	local foamOnly = tile._Config.SurfaceColorMode == "FoamSurfaceAppearance"

	for y = 0, resolution - 1 do
		local v = if resolution > 1 then y / (resolution - 1) else 0
		local localZ = (0.5 - v) * size.Z

		for x = 0, resolution - 1 do
			local u = if resolution > 1 then x / (resolution - 1) else 0
			local localX = (u - 0.5) * size.X
			local height = sampleBakedHeight(tile, localX, localZ, time)

			if not tile._Config.SurfaceColorBake and waterBuffer ~= nil and waterBuffer:HasActivity() then
				height += waterBuffer:SampleHeight(localX, localZ)
			end

			local normalizedHeight = WaterSurfaceColor.NormalizeHeight(
				height,
				tile._WaveLoopMinHeight,
				tile._WaveLoopMaxHeight
			)
			local depthAlpha = sampleWaterDepthAlpha(tile, localX, localZ)
			local offset = surfaceImagePixelOffset(resolution, x, y)
			local shoreFoamAlpha = sampleShoreFoamAlpha(tile, localX, localZ)

			if foamOnly then
				local foam = WaterSurfaceColor.SampleFoam(surfaceColorConfig, normalizedHeight, shoreFoamAlpha)
				local foamAlpha = resolveFoamAlpha(tile, foam.Alpha, depthAlpha, localX, localZ)

				writeColorPixel(pixels, offset, foam.Color, foamAlpha)
			else
				local sample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
				local finalColor, finalAlpha = composeSurfaceSample(tile, sample, depthAlpha, localX, localZ)

				writeColorPixel(pixels, offset, finalColor, finalAlpha)
			end
		end
	end

	local ok, err = pcall(function()
		image:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(resolution, resolution), pixels)
	end)

	if not ok then
		tile._SurfaceAppearanceSupported = false
		warnSurfaceColorUnsupported(tile, err)
	end
end

function OceanTileClass:_SetFlat()
	if self._IsFlat then
		return
	end

	for _, vertex in ipairs(self._Vertices) do
		if not trySetVertexPosition(self, vertex.id, vertex.baseLocal) then
			return
		end
	end

	self._IsFlat = true
end

function OceanTileClass:Update(time: number, camera: Camera?, renderVisible: boolean?)
	if self._Destroyed or self._MeshInvalid then
		return
	end

	self.BaseCFrame = getBaseCFrame(self.SourcePart)
	self.MeshPart.CFrame = self.BaseCFrame
	syncReflectionMeshPart(self)

	local deltaTime = if self._LastUpdateTime >= 0 then math.clamp(time - self._LastUpdateTime, 0, 0.25) else 1 / 30
	self._LastUpdateTime = time

	local cameraPosition = if camera then camera.CFrame.Position else self.BaseCFrame.Position
	local cameraLocal = self.BaseCFrame:PointToObjectSpace(cameraPosition)
	local distance = distanceToSourcePart(self.SourcePart, cameraPosition)
	local detail = getLodDetail(self._Config, distance)

	if detail <= 0 then
		if self._WaterBuffer ~= nil and self._WaterBuffer:HasActivity() then
			self._WaterBuffer:Clear()
		end

		self:_SetFlat()
		return
	end

	local surfaceEffectsActive = distance <= self._Config.FoamDistance and detail > 0.35
	local waterBuffer = self._WaterBuffer
	local physicsActive = waterBuffer ~= nil
		and distance <= self._Config.PhysicsDistance
		and detail > 0.05

	if physicsActive and waterBuffer ~= nil then
		waterBuffer:StepSimulation(self._Config.InteractiveSimulationIterations)
		waterBuffer:UpdateNormals()
	elseif waterBuffer ~= nil and waterBuffer:HasActivity() then
		local fade = self._Config.InteractiveLodDissipation ^ math.max(deltaTime * 30, 1)

		waterBuffer:StepSimulation(1)
		waterBuffer:FadeActivity(fade)
	end

	if self._InteractionWakeFrames > 0 then
		self._InteractionWakeFrames = if physicsActive then self._InteractionWakeFrames - 1 else 0
	end

	if renderVisible == false then
		if self._SeaSprayEmitter then
			self._SeaSprayEmitter.Rate = 0
		end

		return
	end

	local distanceFactor = 1

	if distance > self._Config.FadeStartDistance then
		distanceFactor = math.clamp(
			1 - ((distance - self._Config.FadeStartDistance) / math.max(self._Config.MaxDistance - self._Config.FadeStartDistance, 1)),
			0,
			1
		)
	end

	local positions: buffer? = nil
	local frameA = 0
	local frameB = 0
	local frameAlpha = 0
	local vertexCount = 1

	ensureWaveLoop(self)
	positions = self._WaveLoopPositions

	if positions ~= nil then
		frameA, frameB, frameAlpha = getWaveLoopFrame(self, time)
		vertexCount = math.max(self._WaveLoopFrameStride, 1)
	end

	local interactiveBufferActive = physicsActive and waterBuffer ~= nil and waterBuffer:HasActivity()
	local surfaceBakeActive = self._Config.SurfaceColorBake and ensureSurfaceFrameBake(self)
	local paintSurfaceColors = usesPaintVertices(self._Config) and ensureSurfaceVertexColors(self)
	local paintSurfaceFoam = self._Config.SurfaceColorMode == "PaintVertices"
	local surfaceAppearanceWaterBuffer = if interactiveBufferActive then waterBuffer else nil
	local surfaceColorConfig: WaterSurfaceColor.SurfaceColorConfig? = nil

	if paintSurfaceColors and surfaceBakeActive then
		if not applyBakedSurfaceVertexColors(self, time) then
			surfaceBakeActive = false
			surfaceColorConfig = createSurfaceColorConfig(self._Config)
		end
	elseif paintSurfaceColors then
		surfaceColorConfig = createSurfaceColorConfig(self._Config)
	end

	ensureRingLodCache(self, cameraLocal.X, cameraLocal.Z)

	local ringIndices = self._RingLodIndices

	if ringIndices == nil then
		return
	end

	for entryIndex = 0, self._RingLodCount - 1 do
		local entryOffset = ringLodEntryOffset(entryIndex)
		local vertexIndex = buffer.readu16(ringIndices, entryOffset + RING_LOD_VERTEX_OFFSET)
		local lodLevel = buffer.readu16(ringIndices, entryOffset + RING_LOD_LEVEL_OFFSET)
		local vertex = self._Vertices[vertexIndex]

		if vertex == nil then
			continue
		end

		local vertexDetail = getRingLodDetail(self._Config, detail, lodLevel)
		local vertexDistanceFactor = getRingDistanceFactor(distanceFactor, lodLevel)

		local dx = 0
		local dy = 0
		local dz = 0

		if positions ~= nil then
			dx, dy, dz = readWaveLoopVertex(
				positions,
				frameA,
				frameB,
				frameAlpha,
				vertexCount,
				vertexIndex
			)
		end

		local baseLocal = vertex.baseLocal
		local interactiveHeight = if interactiveBufferActive and waterBuffer ~= nil and vertex.surfaceEnabled and lodLevel == RING_LEVEL_NEAR
			then waterBuffer:SampleHeight(baseLocal.X, baseLocal.Z)
			else 0
		local vertexWaveScale = vertexDetail * vertexDistanceFactor

		local localPosition = Vector3.new(
			baseLocal.X + dx * vertexWaveScale,
			baseLocal.Y + dy * vertexWaveScale + interactiveHeight * vertexDistanceFactor,
			baseLocal.Z + dz * vertexWaveScale
		)

		if not trySetVertexPosition(self, vertex.id, localPosition) then
			return
		end

		if paintSurfaceColors and not surfaceBakeActive and surfaceColorConfig ~= nil then
			local colorHeight = if self._Config.SurfaceColorBake then dy else localPosition.Y
			local depthAlpha = sampleWaterDepthAlpha(self, baseLocal.X, baseLocal.Z)
			paintSurfaceVertex(
				self,
				surfaceColorConfig :: WaterSurfaceColor.SurfaceColorConfig,
				vertexIndex,
				colorHeight,
				paintSurfaceFoam,
				depthAlpha,
				baseLocal.X,
				baseLocal.Z
			)
		end
	end

	if usesSurfaceAppearanceTexture(self._Config) then
		if not surfaceBakeActive or not applyBakedSurfaceAppearanceTexture(self, time) then
			updateSurfaceAppearanceTexture(self, time, surfaceAppearanceWaterBuffer)
		end
	end

	self._IsFlat = false

	if self._SeaSprayEmitter then
		self._SeaSprayEmitter.Rate = 0
	end

	if self._Config.StaticObstacleSplashEnabled
		and self._SplashEmitter ~= nil
		and surfaceEffectsActive
		and physicsActive
		and self._ObstacleImpactVertexCount > 0
		and self._ObstacleImpactVertices ~= nil
		and time - self._LastObstacleSplashTime >= self._Config.StaticObstacleSplashInterval
		and distance <= self._Config.PhysicsDistance * 1.75
	then
		self._LastObstacleSplashTime = time
		local obstacleVertices = self._ObstacleImpactVertices

		if obstacleVertices == nil then
			return
		end

		local obstacleIndex = (math.floor(time / math.max(self._Config.StaticObstacleSplashInterval, 0.01)) % self._ObstacleImpactVertexCount) + 1
		local vertexIndex = buffer.readu16(obstacleVertices, obstacleImpactVertexOffset(obstacleIndex))
		local vertex = self._Vertices[vertexIndex]

		if vertex ~= nil then
			local ringDistance = math.max(
				math.abs(vertex.baseLocal.X - cameraLocal.X),
				math.abs(vertex.baseLocal.Z - cameraLocal.Z)
			)

			if ringDistance <= self._Config.Lod0Radius then
				local bakedDelta = sampleWaveLoop(self, vertexIndex, time)
				local worldPosition = self.BaseCFrame:PointToWorldSpace(vertex.baseLocal + bakedDelta * detail * distanceFactor)

				self:EmitSplash(worldPosition, 0.34, 3.5)
			end
		end
	end
end

function OceanTileClass:SetSpectrum(spectrum: WaveSpectrum.WaveSpectrum)
	self._Spectrum = spectrum
	self._WaveLoopPositions = nil
	self._WaveLoopHeights = nil
	self._WaveLoopMinHeight = 0
	self._WaveLoopMaxHeight = 0
	self._WaveLoopKey = ""
	resetSurfaceBake(self)
end

function OceanTileClass:SetConfig(config: TileConfig)
	local previousConfig = self._Config
	local previousWaveLoopKey = getWaveLoopKey(previousConfig)
	local keepWaveLoop = self._WaveLoopPositions ~= nil
		and self._WaveLoopHeights ~= nil
		and getWaveLoopGeometryKey(previousConfig) == getWaveLoopGeometryKey(config)
		and previousWaveLoopKey == getWaveLoopKey(config)

	self._Config = config

	if keepWaveLoop then
		self._WaveLoopKey = getWaveLoopKey(config)
	else
		self._WaveLoopPositions = nil
		self._WaveLoopHeights = nil
		self._WaveLoopMinHeight = 0
		self._WaveLoopMaxHeight = 0
		self._WaveLoopKey = ""
	end

	resetSurfaceBake(self)

	self._RingLodIndices = nil
	self._RingLodCount = 0
	self._RingLodKey = ""
	self._RingLodDirty = true
	self._ObstacleImpactVertices = nil
	self._ObstacleImpactVertexCount = 0

	if usesSurfaceAppearanceTexture(config) then
		ensureSurfaceUVs(self)
	end

	local hasVertexColors = usesPaintVertices(config) and ensureSurfaceVertexColors(self)
	local hasSurfaceAppearance = ensureSurfaceAppearance(self)

	if shouldUseWhiteMeshColor(config, hasVertexColors, hasSurfaceAppearance) then
		self.MeshPart.Color = Color3.new(1, 1, 1)
	else
		self.MeshPart.Color = config.WaterColorBack
	end

	self.MeshPart.Transparency = config.Transparency
	self.MeshPart.Reflectance = config.Reflectance
	syncReflectionMeshPart(self)

	if config.InteractiveWavesEnabled and self._WaterBuffer == nil then
		self._WaterBuffer = createWaterBuffer(self.SourcePart, config)
	elseif not config.InteractiveWavesEnabled then
		self._WaterBuffer = nil
	end

	configureSeaSpray(self)
	configureSplashParticles(self)
end

function OceanTileClass:AddDrop(worldPosition: Vector3, radius: number, strength: number)
	local waterBuffer = self._WaterBuffer

	if waterBuffer == nil or not isWorldPositionNearCamera(worldPosition, self._Config.PhysicsDistance) then
		return
	end

	local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)

	waterBuffer:AddDrop(localPosition.X, localPosition.Z, radius, strength)
	self._InteractionWakeFrames = math.max(self._InteractionWakeFrames, 72)

	if math.abs(strength) >= 0.12 then
		self:EmitSplash(worldPosition, math.abs(strength), radius)
	end
end

function OceanTileClass:AddFoam(_worldPosition: Vector3, _radius: number, _amount: number)
end

function OceanTileClass:MoveSphere(oldWorldCenter: Vector3, newWorldCenter: Vector3, radius: number, strengthScale: number?)
	local waterBuffer = self._WaterBuffer

	if waterBuffer == nil or not isWorldPositionNearCamera(newWorldCenter, self._Config.PhysicsDistance) then
		return
	end

	local oldLocal = self.BaseCFrame:PointToObjectSpace(oldWorldCenter)
	local newLocal = self.BaseCFrame:PointToObjectSpace(newWorldCenter)

	waterBuffer:MoveSphere(oldLocal, newLocal, radius, strengthScale)
	self._InteractionWakeFrames = math.max(self._InteractionWakeFrames, 60)
end

function OceanTileClass:EmitSplash(worldPosition: Vector3, intensity: number, radius: number?, direction: Vector3?)
	local emitter = self._SplashEmitter

	if emitter == nil or self._SplashAttachment == nil or not self._Config.SplashParticlesEnabled then
		return
	end

	if self._Config.SplashParticleEmitScale <= 0 then
		return
	end

	local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
	local localDirection = if direction ~= nil
		then self.BaseCFrame:VectorToObjectSpace(direction)
		else Vector3.zero
	local emitUp = if localDirection.Magnitude > 0.001
		then (Vector3.yAxis + localDirection.Unit * 0.35).Unit
		else Vector3.yAxis
	local particleRadius = math.max(radius or 2, 0.5)
	local sizeScale = math.clamp(particleRadius * 0.28, 0.85, 8)
	local spread = math.clamp(12 + particleRadius * 0.55, 12, 34)
	local emitCount = math.clamp(
		math.round((0.65 + intensity * 0.35 + particleRadius * 0.05) * self._Config.SplashParticleEmitScale),
		1,
		2
	)

	local attachment = Instance.new("Attachment")
	attachment.Name = "SplashBurst"
	attachment.CFrame = cframeWithUp(localPosition, emitUp)
	attachment.Parent = self.MeshPart

	local burstEmitter = emitter:Clone()
	burstEmitter.Enabled = false
	burstEmitter.Rate = 0
	burstEmitter.Parent = attachment
	burstEmitter.SpreadAngle = Vector2.new(spread, spread)
	burstEmitter.Lifetime = NumberRange.new(0.28, 0.58)
	burstEmitter.Rotation = NumberRange.new(-18, 18)
	burstEmitter.RotSpeed = NumberRange.new(-28, 28)
	burstEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sizeScale * 0.5),
		NumberSequenceKeypoint.new(0.22, sizeScale),
		NumberSequenceKeypoint.new(1, 0),
	})
	burstEmitter.Speed = NumberRange.new(
		math.max(self._Config.SplashParticleMinSpeed * 0.45, 1.2),
		math.max(self._Config.SplashParticleMaxSpeed * 0.45 + intensity * 1.4, 2.4)
	)
	burstEmitter:Emit(emitCount)

	task.delay(0.9, function()
		if attachment.Parent ~= nil then
			attachment:Destroy()
		end
	end)
end

function OceanTileClass:ContainsWorldPosition(worldPosition: Vector3): boolean
	local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
	local halfSize = self.SourcePart.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X and math.abs(localPosition.Z) <= halfSize.Z
end

function OceanTileClass:IsPointInWaterVolume(
	worldPosition: Vector3,
	time: number,
	surfacePadding: number?,
	bottomPadding: number?
): boolean
	local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
	local halfSize = self.SourcePart.Size * 0.5

	if math.abs(localPosition.X) > halfSize.X or math.abs(localPosition.Z) > halfSize.Z then
		return false
	end

	local surfaceHeight = self:GetHeightAt(worldPosition, time, 1) + (surfacePadding or 0)
	local bottomLocalY = -getVolumeDepth(self, localPosition.X, localPosition.Z) - (bottomPadding or 0)
	local bottomWorld = self.BaseCFrame:PointToWorldSpace(Vector3.new(localPosition.X, bottomLocalY, localPosition.Z)).Y

	return worldPosition.Y <= surfaceHeight and worldPosition.Y >= bottomWorld
end

function OceanTileClass:GetBaseHeightAt(worldPosition: Vector3): number
	local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
	local onSurface = self.BaseCFrame:PointToWorldSpace(Vector3.new(localPosition.X, 0, localPosition.Z))

	return onSurface.Y
end

function OceanTileClass:GetHeightAt(worldPosition: Vector3, time: number, steps: number?): number
	local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
	local baseHeight = self.BaseCFrame:PointToWorldSpace(Vector3.new(localPosition.X, 0, localPosition.Z)).Y
	local waterBuffer = self._WaterBuffer
	local interactiveHeight = if waterBuffer ~= nil and waterBuffer:HasActivity()
		then waterBuffer:SampleHeight(localPosition.X, localPosition.Z)
		else 0

	return baseHeight + sampleBakedHeight(self, localPosition.X, localPosition.Z, time) + interactiveHeight
end

function OceanTileClass:GetNormalAt(worldPosition: Vector3, time: number): Vector3
	local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
	local sampleDistance = math.max(self._Config.VertexSpacing * 0.5, 1)
	local waterBuffer = self._WaterBuffer

	local function localHeight(localX: number, localZ: number): number
		local interactiveHeight = if waterBuffer ~= nil and waterBuffer:HasActivity()
			then waterBuffer:SampleHeight(localX, localZ)
			else 0

		return sampleBakedHeight(self, localX, localZ, time) + interactiveHeight
	end

	local x0 = localPosition.X - sampleDistance
	local x1 = localPosition.X + sampleDistance
	local z0 = localPosition.Z - sampleDistance
	local z1 = localPosition.Z + sampleDistance
	local px0 = Vector3.new(x0, localHeight(x0, localPosition.Z), localPosition.Z)
	local px1 = Vector3.new(x1, localHeight(x1, localPosition.Z), localPosition.Z)
	local pz0 = Vector3.new(localPosition.X, localHeight(localPosition.X, z0), z0)
	local pz1 = Vector3.new(localPosition.X, localHeight(localPosition.X, z1), z1)
	local normalLocal = (pz1 - pz0):Cross(px1 - px0)

	if normalLocal.Magnitude <= 0.001 then
		return self.BaseCFrame.UpVector
	end

	return self.BaseCFrame:VectorToWorldSpace(normalLocal.Unit).Unit
end

function OceanTileClass:GetVelocityAt(worldPosition: Vector3, time: number): Vector3
	local sampleDelta = 0.08
	local currentHeight = self:GetHeightAt(worldPosition, time, 1)
	local previousHeight = self:GetHeightAt(worldPosition, time - sampleDelta, 1)

	return Vector3.yAxis * ((currentHeight - previousHeight) / sampleDelta)
end

function OceanTileClass:IsInvalid(): boolean
	return self._Destroyed or self._MeshInvalid
end

function OceanTileClass:Destroy()
	self._Destroyed = true
	destroySurfaceAppearance(self)

	if self._HiddenSourcePart then
		self.SourcePart.LocalTransparencyModifier = self._SourceLocalTransparencyModifier
	end

	if self.MeshPart then
		self.MeshPart:Destroy()
	end

	if self.ReflectionMeshPart then
		self.ReflectionMeshPart:Destroy()
	end

	if self.EditableMesh then
		pcall(function()
			self.EditableMesh:Destroy()
		end)
	end
end

local OceanTile = {}

function OceanTile.new(
	sourcePart: BasePart,
	parent: Instance,
	spectrum: WaveSpectrum.WaveSpectrum,
	config: TileConfig
): (OceanTile?, string?)
	local editableMesh, editableMeshError = createEditableMesh()

	if editableMesh == nil then
		return nil, editableMeshError
	end

	local resolutionX, resolutionZ, gridXCoordinates, gridZCoordinates = getGridCoordinates(sourcePart, config)

	local tile = setmetatable({
		SourcePart = sourcePart,
		MeshPart = nil,
		ReflectionMeshPart = nil,
		EditableMesh = editableMesh,
		BaseCFrame = getBaseCFrame(sourcePart),
		_Config = config,
		_Spectrum = spectrum,
		_ResolutionX = resolutionX,
		_ResolutionZ = resolutionZ,
		_GridXCoordinates = gridXCoordinates,
		_GridZCoordinates = gridZCoordinates,
		_Vertices = {},
		_Faces = {},
		_WaterBuffer = createWaterBuffer(sourcePart, config),
		_DepthMap = createDepthMap(sourcePart, parent, config),
		_ObstacleMap = createObstacleMap(sourcePart, parent, config),
		_SeaSprayAttachment = nil,
		_SeaSprayEmitter = nil,
		_SplashAttachment = nil,
		_SplashEmitter = nil,
		_SourceLocalTransparencyModifier = sourcePart.LocalTransparencyModifier,
		_HiddenSourcePart = false,
		_Destroyed = false,
		_MeshInvalid = false,
		_IsFlat = false,
		_LastUpdateTime = -1,
		_InteractionWakeFrames = 0,
		_RingLodIndices = nil,
		_RingLodCount = 0,
		_RingLodCenterX = 0,
		_RingLodCenterZ = 0,
		_RingLodKey = "",
		_RingLodDirty = true,
		_WaveLoopPositions = nil,
		_WaveLoopHeights = nil,
		_WaveLoopFrames = 0,
		_WaveLoopFrameStride = 0,
		_WaveLoopDuration = math.max(config.WaveLoopDuration, 0.25),
		_WaveLoopKey = "",
		_WaveLoopBaking = false,
		_WaveLoopMinHeight = 0,
		_WaveLoopMaxHeight = 0,
		_SurfaceColorIds = {},
		_SurfaceUVIds = {},
		_SurfaceImage = nil,
		_SurfaceImageResolution = 0,
		_SurfaceAppearance = nil,
		_SurfaceTextureLastUpdateTime = -math.huge,
		_SurfaceTextureLastFrameIndex = -1,
		_SurfaceTextureFramePixels = nil,
		_SurfaceTextureFrameCount = 0,
		_SurfaceTextureFrameResolution = 0,
		_SurfaceTextureRuntimePixels = nil,
		_SurfaceVertexFrameColors = nil,
		_SurfaceVertexFrameCount = 0,
		_SurfaceVertexLastFrameIndex = -1,
		_SurfaceBakeKey = "",
		_SurfaceBakeBaking = false,
		_SurfaceColorSupported = true,
		_SurfaceUVSupported = true,
		_SurfaceAppearanceSupported = true,
		_SurfaceColorWarningShown = false,
		_ObstacleImpactVertices = nil,
		_ObstacleImpactVertexCount = 0,
		_LastObstacleSplashTime = 0,
	}, OceanTileClass) :: any

	buildMesh(tile)

	if usesSurfaceAppearanceTexture(config) then
		ensureSurfaceUVs(tile)
	end

	if usesPaintVertices(config) then
		ensureSurfaceVertexColors(tile)
	end

	local meshPart, meshPartError = createMeshPart(editableMesh)

	if meshPart == nil then
		tile:Destroy()
		return nil, meshPartError
	end

	local reflectionMeshPart, reflectionMeshPartError = createMeshPart(editableMesh)

	if reflectionMeshPart == nil then
		meshPart:Destroy()
		tile:Destroy()
		return nil, reflectionMeshPartError
	end

	if parent.Parent == nil then
		tile:Destroy()
		meshPart:Destroy()
		reflectionMeshPart:Destroy()
		return nil, "Ocean tile parent was destroyed"
	end

	configureMeshPart(meshPart, sourcePart, config)
	meshPart.CFrame = tile.BaseCFrame
	meshPart.Parent = parent
	tile.MeshPart = meshPart

	configureReflectionMeshPart(reflectionMeshPart, sourcePart, meshPart)
	reflectionMeshPart.CFrame = getReflectionCFrame(meshPart)
	reflectionMeshPart.Parent = parent
	tile.ReflectionMeshPart = reflectionMeshPart

	local hasSurfaceAppearance = ensureSurfaceAppearance(tile)
	local hasVertexColors = usesPaintVertices(config) and tile._SurfaceColorSupported

	if shouldUseWhiteMeshColor(config, hasVertexColors, hasSurfaceAppearance) then
		meshPart.Color = Color3.new(1, 1, 1)
	end

	configureSeaSpray(tile)
	configureSplashParticles(tile)

	if readBooleanAttribute(sourcePart, "OceanHideSourcePart", config.HideSourceParts) then
		sourcePart.LocalTransparencyModifier = 1
		tile._HiddenSourcePart = true
	end

	return tile :: OceanTile, nil
end

return OceanTile
