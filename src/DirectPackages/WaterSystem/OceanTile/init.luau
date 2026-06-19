--!strict

local WaterSurfaceColor = require(script.Parent.WaterSurfaceColor)
local WaveSpectrum = require(script.Parent.WaveSpectrum)

local OceanTileTypes = require(script.Types)
local Constants = require(script.Constants)
local Base = require(script.Base)
local PartsFactory = require(script.Parts)
local MeshEditingFactory = require(script.MeshEditing)
local SurfaceSamplingFactory = require(script.SurfaceSampling)
local SurfaceResourcesFactory = require(script.SurfaceResources)
local MeshBuilderFactory = require(script.MeshBuilder)
local LodFactory = require(script.Lod)
local WaveLoopFactory = require(script.WaveLoop)
local SurfaceBakeFactory = require(script.SurfaceBake)
local attachMethods = require(script.Methods)

export type TileConfig = OceanTileTypes.TileConfig
export type OceanTile = OceanTileTypes.OceanTile

local OceanTileClass = {}
OceanTileClass.__index = OceanTileClass

local deps: any = {
	WaterSurfaceColor = WaterSurfaceColor,
	WaveSpectrum = WaveSpectrum,
}

local function mergeDependencies(source: any)
	for key, value in pairs(source) do
		deps[key] = value
	end
end

mergeDependencies(Constants)
mergeDependencies(Base)
mergeDependencies(SurfaceSamplingFactory(deps))
mergeDependencies(PartsFactory(deps))
mergeDependencies(MeshEditingFactory(deps))
mergeDependencies(SurfaceResourcesFactory(deps))
mergeDependencies(MeshBuilderFactory(deps))
mergeDependencies(LodFactory(deps))
mergeDependencies(WaveLoopFactory(deps))
mergeDependencies(SurfaceBakeFactory(deps))
attachMethods(OceanTileClass, deps)

local createEditableMesh = deps.createEditableMesh
local getGridCoordinates = deps.getGridCoordinates
local createWaterBuffer = deps.createWaterBuffer
local createDepthMap = deps.createDepthMap
local createObstacleMap = deps.createObstacleMap
local getBaseCFrame = deps.getBaseCFrame
local buildMesh = deps.buildMesh
local usesSurfaceAppearanceTexture = deps.usesSurfaceAppearanceTexture
local usesWaterNormalMap = deps.usesWaterNormalMap
local ensureSurfaceUVs = deps.ensureSurfaceUVs
local usesPaintVertices = deps.usesPaintVertices
local ensureSurfaceVertexColors = deps.ensureSurfaceVertexColors
local createMeshPart = deps.createMeshPart
local configureMeshPart = deps.configureMeshPart
local configureReflectionMeshPart = deps.configureReflectionMeshPart
local getReflectionCFrame = deps.getReflectionCFrame
local ensureSurfaceAppearance = deps.ensureSurfaceAppearance
local shouldUseWhiteMeshColor = deps.shouldUseWhiteMeshColor
local configureSeaSpray = deps.configureSeaSpray
local configureSplashParticles = deps.configureSplashParticles
local readBooleanAttribute = deps.readBooleanAttribute

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
		_StageCameraLocal = Vector3.zero,
		_StageDistance = 0,
		_StageDetail = 1,
		_StageDistanceFactor = 1,
		_StageRenderVisible = true,
		_RenderTargetCFrame = getBaseCFrame(sourcePart),
		_RenderTransformDirty = false,
		_RenderVertexPositions = nil,
		_RenderVertexDirtyIndices = nil,
		_RenderVertexDirtyCount = 0,
		_RenderSurfaceColorPixels = nil,
		_RenderSurfaceColorDirty = false,
		_RenderSurfaceTexturePixels = nil,
		_RenderSurfaceTextureResolution = 0,
		_RenderSurfaceTextureDirty = false,
		_RenderSurfaceNormalPixels = nil,
		_RenderSurfaceNormalResolution = 0,
		_RenderSurfaceNormalDirty = false,
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
		_WaveLoopReadyFrames = 0,
		_WaveLoopFrameStride = 0,
		_WaveLoopDuration = math.max(config.WaveLoopDuration, 0.25),
		_WaveLoopKey = "",
		_WaveLoopBaking = false,
		_WaveLoopBakeId = 0,
		_WaveLoopMinHeight = 0,
		_WaveLoopMaxHeight = 0,
		_SurfaceColorIds = {},
		_SurfaceUVIds = {},
		_SurfaceImage = nil,
		_SurfaceImageResolution = 0,
		_SurfaceNormalImage = nil,
		_SurfaceNormalImageResolution = 0,
		_SurfaceMetalnessImage = nil,
		_SurfaceRoughnessImage = nil,
		_SurfaceNormalLastUpdateTime = -math.huge,
		_SurfaceNormalLastFrameIndex = -1,
		_SurfaceNormalFramePixels = nil,
		_SurfaceNormalFrameCount = 0,
		_SurfaceNormalFrameResolution = 0,
		_SurfaceNormalRuntimePixels = nil,
		_SurfaceNormalBakeKey = "",
		_SurfaceNormalBakeBaking = false,
		_SurfaceNormalBakeId = 0,
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
		_SurfaceBakeId = 0,
		_SurfaceColorSupported = true,
		_SurfaceUVSupported = true,
		_SurfaceAppearanceSupported = true,
		_SurfaceNormalSupported = true,
		_SurfaceColorWarningShown = false,
		_ObstacleImpactVertices = nil,
		_ObstacleImpactVertexCount = 0,
		_LastObstacleSplashTime = 0,
	}, OceanTileClass) :: any

	buildMesh(tile)

	if usesSurfaceAppearanceTexture(config) or usesWaterNormalMap(config) then
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
