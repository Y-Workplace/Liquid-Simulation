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
	local editableMesh, pooledMeshPart, editableMeshError = createEditableMesh(true)
	if editableMesh == nil then
		warn(
			"[WaterSystem] Tile init: reserved editable mesh is nil for sourcePart="
				.. tostring(sourcePart)
				.. "; error="
				.. tostring(editableMeshError)
		)
		warn(debug.traceback())
	end

	-- Try to reserve a pooled mesh for the reflection as well (pool-only)
	local reflectionEditableMesh, pooledReflectionMeshPart, reflectionMeshError = nil, nil, nil
	local available = deps.getEditableMeshPoolAvailableCount and deps.getEditableMeshPoolAvailableCount() or 0
	if available > 0 then
		reflectionEditableMesh, pooledReflectionMeshPart, reflectionMeshError = createEditableMesh(true)
	else
		-- not enough pool capacity for reflection reservation
		reflectionEditableMesh = nil
		pooledReflectionMeshPart = nil
		reflectionMeshError = "not enough pool capacity for reflection"
	end
	if reflectionEditableMesh == nil then
		warn(
			"[WaterSystem] Tile init: reserved reflection editable mesh is nil for sourcePart="
				.. tostring(sourcePart)
				.. "; error="
				.. tostring(reflectionMeshError)
		)
		warn(debug.traceback())
	end

	-- continue even if editableMesh is nil (system supports plain MeshPart fallback)

	local resolutionX, resolutionZ, gridXCoordinates, gridZCoordinates = getGridCoordinates(sourcePart, config)

	local tile = setmetatable({
		SourcePart = sourcePart,
		MeshPart = nil,
		ReflectionMeshPart = nil,
		EditableMesh = editableMesh,
		ReflectionEditableMesh = reflectionEditableMesh,
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
		_PooledMeshPart = (pooledMeshPart ~= nil),
		_PooledReflectionMeshPart = (pooledReflectionMeshPart ~= nil),
		_EditableMeshReleased = false,
		_ReflectionEditableMeshReleased = false,
	}, OceanTileClass) :: any

	-- Capabilities: avoid pcall in hot loops by probing method presence once.
	if editableMesh ~= nil then
		tile._SurfaceUVSupported = type(editableMesh.AddUV) == "function"
		tile._SurfaceColorSupported = type(editableMesh.AddColor) == "function"
	else
		tile._SurfaceUVSupported = false
		tile._SurfaceColorSupported = false
	end

	-- Mesh editing capability probe: check method presence once to avoid pcalls in hot loops.
	if editableMesh ~= nil then
		tile._MeshEditingSupported = type(editableMesh.AddVertex) == "function"
			and type(editableMesh.AddTriangle) == "function"
			and type(editableMesh.SetPosition) == "function"
	else
		tile._MeshEditingSupported = false
	end

	buildMesh(tile)

	if usesSurfaceAppearanceTexture(config) or usesWaterNormalMap(config) then
		ensureSurfaceUVs(tile)
	end

	if usesPaintVertices(config) then
		ensureSurfaceVertexColors(tile)
	end

	local meshPart, meshPartError = pooledMeshPart, nil

	if meshPart == nil then
		meshPart, meshPartError = createMeshPart(editableMesh)
	end

	if meshPart == nil then
		tile:Destroy()
		return nil, meshPartError
	end

	local reflectionMeshPart, reflectionMeshPartError = pooledReflectionMeshPart, nil
	local reflectionMeshPart, reflectionMeshPartError = pooledReflectionMeshPart, nil

	if reflectionMeshPart == nil then
		-- Try to create a reflection mesh part from (in order): reserved reflection editable, main editable, or plain MeshPart fallback.
		reflectionMeshPart, reflectionMeshPartError = createMeshPart(reflectionEditableMesh or editableMesh)
		if reflectionMeshPart == nil then
			-- final attempt: create plain MeshPart
			reflectionMeshPart, reflectionMeshPartError = createMeshPart(nil)
		end
	end

	-- If reflectionMeshPart still nil, we cannot create a reflection, but we should NOT
	-- abort tile creation entirely. Log and continue without reflection.
	if reflectionMeshPart == nil then
		warn(
			"[WaterSystem] Could not create reflection mesh part for tile; continuing without reflection: "
				.. tostring(reflectionMeshPartError)
		)
		warn(debug.traceback())
	else
		-- attach reflection mesh part
		reflectionMeshPart.CFrame = getReflectionCFrame(meshPart)
		reflectionMeshPart.Parent = parent
		tile.ReflectionMeshPart = reflectionMeshPart
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

	-- Reserve pooled editable images for this tile (pool-only). This avoids runtime
	-- AssetService calls inside SurfaceResources and ensures images are ready
	-- before calling `ensureSurfaceAppearance`.
	local hasSurfaceAppearance = false
	local needsColorMap = usesSurfaceAppearanceTexture(config)
	local needsNormalMap = usesWaterNormalMap(config) and tile._SurfaceNormalSupported

	if needsColorMap then
		local colorResolution = deps.getSurfaceImageResolution(config)
		local img, imgErr = deps.createEditableImage(true)
		if img ~= nil then
			-- prepare pixel buffer for the requested resolution (blank)
			local pixels = buffer.create(colorResolution * colorResolution * deps.SURFACE_IMAGE_PIXEL_BYTES)
			local stride = deps.SURFACE_IMAGE_PIXEL_BYTES
			local totalPixels = colorResolution * colorResolution
			for px = 0, totalPixels - 1 do
				local base = px * stride
				buffer.writeu8(pixels, base, 0)
				buffer.writeu8(pixels, base + 1, 0)
				buffer.writeu8(pixels, base + 2, 0)
				buffer.writeu8(pixels, base + 3, 255)
			end
			local ok, err = pcall(function()
				(img :: any):WritePixelsBuffer(Vector2.zero, Vector2.new(colorResolution, colorResolution), pixels)
			end)
			if ok then
				tile._SurfaceImage = img
				tile._SurfaceImageResolution = colorResolution
			else
				deps.releaseEditableImage(img)
				tile._SurfaceImage = nil
				tile._SurfaceImageResolution = 0
			end
		else
			-- pool exhausted or unavailable; leave nil and let SurfaceResources fallback
			tile._SurfaceImage = nil
			tile._SurfaceImageResolution = 0
		end
	end

	if needsNormalMap then
		local normalResolution = deps.getSurfaceNormalResolution(config)
		local nimg, nimgErr = deps.createEditableImage(true)
		if nimg ~= nil then
			local pixels = buffer.create(normalResolution * normalResolution * deps.SURFACE_IMAGE_PIXEL_BYTES)
			local stride = deps.SURFACE_IMAGE_PIXEL_BYTES
			local totalPixels = normalResolution * normalResolution
			for px = 0, totalPixels - 1 do
				local base = px * stride
				-- neutral normal: X=0.5,Y=0.5,Z=1.0 -> R=128,G=128,B=255
				buffer.writeu8(pixels, base, 128)
				buffer.writeu8(pixels, base + 1, 128)
				buffer.writeu8(pixels, base + 2, 255)
				buffer.writeu8(pixels, base + 3, 255)
			end
			local okn, errn = pcall(function()
				(nimg :: any):WritePixelsBuffer(Vector2.zero, Vector2.new(normalResolution, normalResolution), pixels)
			end)
			if okn then
				tile._SurfaceNormalImage = nimg
				tile._SurfaceNormalImageResolution = normalResolution
			else
				deps.releaseEditableImage(nimg)
				tile._SurfaceNormalImage = nil
				tile._SurfaceNormalImageResolution = 0
			end
		else
			tile._SurfaceNormalImage = nil
			tile._SurfaceNormalImageResolution = 0
		end
	end

	hasSurfaceAppearance = ensureSurfaceAppearance(tile)
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
