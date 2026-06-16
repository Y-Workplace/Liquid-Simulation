--!strict

local AssetService = game:GetService("AssetService")

local WaterDepthMap = require(script.Parent.WaterDepthMap)
local WaterFoamBuffer = require(script.Parent.WaterFoamBuffer)
local WaterObstacleMap = require(script.Parent.WaterObstacleMap)
local WaterBuffer = require(script.Parent.WaterBuffer)
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
	CrestFoamStrength: number,
	HighWaveFoamThreshold: number,
	HighWaveFoamStrength: number,
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
	FoamColor: Color3,
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
	uvId: number?,
	waveInfluence: number,
	foamEnabled: boolean,
	color: number,
	foam: number,
	foamAccumulation: number,
	foamPattern: number,
	crestTint: number,
}

type EdgeVertexMapper = (number) -> number
type EdgeGridMapper = (number) -> (number, number)

type FaceState = {
	id: number,
	a: number,
	b: number,
	c: number,
	buckets: { number },
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
	_ColorIds: { number }?,
	_WaterBuffer: WaterBuffer.WaterBuffer?,
	_DepthMap: WaterDepthMap.WaterDepthMap?,
	_ObstacleMap: WaterObstacleMap.WaterObstacleMap?,
	_FoamBuffer: WaterFoamBuffer.WaterFoamBuffer?,
	_FoamTexture: SurfaceAppearance?,
	_FoamEditableImage: EditableImage?,
	_FoamTextureKey: string?,
	_FoamImageBuffer: buffer?,
	_FoamTextureRowCursor: number,
	_FoamTextureBake: { buffer }?,
	_FoamTextureBakeKey: string,
	_FoamTextureBakeFrames: number,
	_FoamTextureBakeSize: number,
	_LastFoamTextureUpdate: number,
	_UvEnabled: boolean,
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
	_LastFoamColorUpdate: number,
	_FoamVisible: boolean,
	_InteractionWakeFrames: number,
	_RingLodIndices: buffer?,
	_RingLodCount: number,
	_RingLodCenterX: number,
	_RingLodCenterZ: number,
	_RingLodKey: string,
	_RingLodDirty: boolean,
	_RingFoamFaceIndices: buffer?,
	_RingFoamFaceCount: number,
	_PreviousRingFoamFaceIndices: buffer?,
	_PreviousRingFoamFaceCount: number,
	_RingFoamFullRefresh: boolean,
	_WaveLoopPositions: buffer?,
	_WaveLoopHeights: buffer?,
	_WaveLoopSurface: buffer?,
	_WaveLoopFrames: number,
	_WaveLoopFrameStride: number,
	_WaveLoopDuration: number,
	_WaveLoopKey: string,
	_WaveLoopBaking: boolean,
	_ObstacleImpactVertices: buffer?,
	_ObstacleImpactVertexCount: number,
	_LastObstacleSplashTime: number,
	_LastFoamMaxRecalculateTime: number,
}

local OceanTileClass = {}
OceanTileClass.__index = OceanTileClass

local SURFACE_FOAM_COLOR_BUCKETS = 32
local SURFACE_TINT_COLOR_BUCKETS = 32
local COLOR_BUCKETS = (SURFACE_FOAM_COLOR_BUCKETS + 1) * (SURFACE_TINT_COLOR_BUCKETS + 1) - 1
local TAU = math.pi * 2
local DEFAULT_MATERIAL = Enum.Material.SmoothPlastic
local VERTEX_COLOR_TINT = Color3.new(1, 1, 1)
local DEFAULT_WATER_TINT_COLOR = Color3.fromRGB(31, 143, 128)
local FOAM_BAKE_VERSION = 17
local WAVE_LOOP_POSITION_STRIDE = 3
local WAVE_LOOP_POSITION_BYTES = WAVE_LOOP_POSITION_STRIDE * 4
local WAVE_LOOP_HEIGHT_BYTES = 4
local WAVE_LOOP_SURFACE_BYTES = 4
local WAVE_LOOP_SURFACE_FOAM = 0
local WAVE_LOOP_SURFACE_TINT = 1
local WAVE_LOOP_SURFACE_ALPHA = 2
local WAVE_LOOP_SEAM_FRACTION = 0.18
local BAKE_YIELD_CELL_BUDGET = 4096
local FOAM_MAX_RECALCULATE_INTERVAL = 0.22
local FOAM_GRADIENT_SAMPLE_DISTANCE = 3
local MAX_OBSTACLE_IMPACT_VERTICES = 32
local OBSTACLE_IMPACT_VERTEX_BYTES = 2
local RING_LOD_ENTRY_BYTES = 4
local RING_LOD_VERTEX_OFFSET = 0
local RING_LOD_LEVEL_OFFSET = 2
local RING_FACE_ENTRY_BYTES = 2
local RING_LEVEL_NEAR = 0
local RING_LEVEL_MID = 1
local RING_LEVEL_FAR = 2
local RING_LEVEL_EXTREME = 3
local VOLUME_BOTTOM_GRID_OFFSET = 32000
local VERTEX_BAKE_STATIC_STRIDE = 8
local VERTEX_BAKE_STATIC_BYTES = VERTEX_BAKE_STATIC_STRIDE * 4
local VERTEX_STATIC_BASE_WORLD_X = 0
local VERTEX_STATIC_BASE_WORLD_Z = 1
local VERTEX_STATIC_WAVE_SCALE = 2
local VERTEX_STATIC_SHORE_FOAM = 3
local VERTEX_STATIC_OBSTACLE_FOAM = 4
local VERTEX_STATIC_OCEAN_WEIGHT = 5
local VERTEX_STATIC_LAKE_WEIGHT = 6
local VERTEX_STATIC_SHALLOW_WEIGHT = 7

local ensureWaveLoop: (InternalOceanTile) -> ()
local sampleWaveLoopSurfaceField: (InternalOceanTile, number, number, number) -> (number, number)

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / math.max(edge1 - edge0, 1e-6), 0, 1)
	return t * t * (3 - 2 * t)
end

local function rangeAlpha(value: number, startValue: number, fullValue: number): number
	return math.clamp((value - startValue) / math.max(fullValue - startValue, 1e-6), 0, 1)
end

local function mixNumber(low: number, high: number, alpha: number): number
	return low + (high - low) * math.clamp(alpha, 0, 1)
end

local function fract(value: number): number
	return value - math.floor(value)
end

local function hash01(seed: number, x: number, z: number, salt: number): number
	return fract(math.sin(x * 127.1 + z * 311.7 + seed * 17.13 + salt * 101.3) * 43758.5453123)
end

local function isFinalBakedSurfaceTexture(config: TileConfig): boolean
	return config.FoamTextureFromVerticesEnabled and not config.RuntimeSurfaceColorEnabled
end

local function usesSurfaceBufferForVisuals(config: TileConfig): boolean
	return config.RuntimeSurfaceColorEnabled or not config.FoamTextureFromVerticesEnabled
end

local function getWaterGradientColor(config: TileConfig, tint: number): Color3
	local tintAlpha = math.clamp(tint, 0, 1)
	local tintColor = config.WaterTintColor or DEFAULT_WATER_TINT_COLOR

	return config.WaterColor:Lerp(tintColor, tintAlpha)
end

local function blendSurfaceColor(config: TileConfig, foam: number, tint: number): (Color3, number)
	local foamAlpha = math.clamp(foam, 0, 1)
	local tintAlpha = math.clamp(tint, 0, 1)
	local waterAlpha = math.clamp(config.WaterVertexAlpha, 0, 1)
	local fullFoamAlpha = math.clamp(config.FoamVertexAlpha, 0, 1)
	local waterColor = getWaterGradientColor(config, tintAlpha)
	local color = waterColor:Lerp(config.FoamColor, foamAlpha)
	local alpha = waterAlpha + (fullFoamAlpha - waterAlpha) * foamAlpha

	return color, math.clamp(alpha, 0, 1)
end

local function cellularEdge(u: number, v: number, seed: number, jitter: number): (number, number)
	local cellX = math.floor(u)
	local cellZ = math.floor(v)
	local localU = u - cellX
	local localV = v - cellZ
	local nearest = math.huge
	local secondNearest = math.huge
	local nearestHash = 0

	for offsetZ = -1, 1 do
		for offsetX = -1, 1 do
			local sampleCellX = cellX + offsetX
			local sampleCellZ = cellZ + offsetZ
			local pointU = 0.5 + (hash01(seed, sampleCellX, sampleCellZ, 1) - 0.5) * jitter
			local pointV = 0.5 + (hash01(seed, sampleCellX, sampleCellZ, 2) - 0.5) * jitter
			local deltaU = offsetX + pointU - localU
			local deltaV = offsetZ + pointV - localV
			local distance = deltaU * deltaU + deltaV * deltaV

			if distance < nearest then
				secondNearest = nearest
				nearest = distance
				nearestHash = hash01(seed, sampleCellX, sampleCellZ, 3)
			elseif distance < secondNearest then
				secondNearest = distance
			end
		end
	end

	return math.max(math.sqrt(secondNearest) - math.sqrt(nearest), 0), nearestHash
end

local function getHighWaveFoamThreshold(config: TileConfig, waveScale: number): number
	return math.max(config.HighWaveFoamThreshold, math.abs(waveScale) * 0.42, 0.12)
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

local function sampleWaveFoamSignals(
	config: TileConfig,
	sampleHeight: number,
	waveScale: number,
	sampleFoam: number
): (number, number)
	local waveHeight = sampleHeight * waveScale
	local highWaveThreshold = getHighWaveFoamThreshold(config, waveScale)
	local crestHeight = math.max(waveHeight, 0)
	local greenAlpha = rangeAlpha(crestHeight, highWaveThreshold * 0.08, highWaveThreshold * 1.8)
	local crestStrength = math.max(config.CrestFoamStrength, 0)
	local foamAlpha = math.max(
		rangeAlpha(crestHeight, highWaveThreshold, highWaveThreshold * 2) * config.HighWaveFoamStrength,
		math.clamp(sampleFoam, 0, 1)
	) * crestStrength

	return math.clamp(foamAlpha, 0, 1), greenAlpha
end

local function sampleWaveFoamShape(
	config: TileConfig,
	sampleHeight: number,
	waveScale: number,
	sampleFoam: number,
	gradientX: number,
	gradientZ: number
): (number, number, number, number)
	local foamAlpha, greenAlpha = sampleWaveFoamSignals(config, sampleHeight, waveScale, sampleFoam)
	local waveHeight = sampleHeight * waveScale
	local highWaveThreshold = getHighWaveFoamThreshold(config, waveScale)
	local crestHeight = math.max(waveHeight, 0)
	local gradientMagnitude = math.sqrt(gradientX * gradientX + gradientZ * gradientZ)
	local heightAlpha = rangeAlpha(crestHeight, highWaveThreshold * 0.08, highWaveThreshold * 1.55)
	local peakMask = heightAlpha * (1 - smoothstep(0.1, 0.58, gradientMagnitude))
	local slopeMask = heightAlpha * smoothstep(0.035, 0.36, gradientMagnitude) * (1 - peakMask * 0.35)
	local crestMask = math.clamp(math.max(peakMask, foamAlpha * 0.85), 0, 1)
	local crestStrength = math.max(config.CrestFoamStrength, 0)
	local shapedFoam = math.max(
		foamAlpha,
		peakMask * config.HighWaveFoamStrength * crestStrength * 0.85,
		slopeMask * crestStrength * 0.32
	)

	return math.clamp(shapedFoam, 0, 1), greenAlpha, crestMask, math.clamp(slopeMask, 0, 1)
end

local function sampleCellularFoamPattern(
	config: TileConfig,
	localX: number,
	localZ: number,
	sampleHeight: number,
	gradientX: number,
	gradientZ: number,
	crestMask: number,
	slopeMask: number,
	time: number
): number
	local tileScale = math.max(config.FoamTextureStudsPerTile, 0.1)
	local noiseScale = math.clamp(math.sqrt(math.max(config.FoamNoiseSize, 16) / 128), 0.35, 2.8)
	local gradientMagnitude = math.sqrt(gradientX * gradientX + gradientZ * gradientZ)
	local directionX = 0
	local directionZ = 0
	local crest = math.clamp(crestMask, 0, 1)
	local slope = math.clamp(slopeMask, 0, 1)
	local domainDensity = mixNumber(0.58, 1.42, math.max(crest, slope * 0.58))
	local baseU = (localX / tileScale) * noiseScale * domainDensity
	local baseV = (localZ / tileScale) * noiseScale * domainDensity

	if gradientMagnitude > 0.0005 then
		directionX = gradientX / gradientMagnitude
		directionZ = gradientZ / gradientMagnitude
	else
		local angle = hash01(config.FoamNoiseSeed, math.floor(baseU), math.floor(baseV), 11) * TAU
		directionX = math.cos(angle)
		directionZ = math.sin(angle)
	end

	local tangentX = -directionZ
	local tangentZ = directionX
	local alongSlope = baseU * directionX + baseV * directionZ
	local acrossSlope = baseU * tangentX + baseV * tangentZ
	local heightShift = math.clamp(sampleHeight / math.max(tileScale * 0.32, 0.001), -1, 1)
	local compression = 1 + crest * 2.65 + slope * 0.35
	local stretch = 1 / (1 + slope * 1.55)
	local coarseWarp = (hash01(config.FoamNoiseSeed, math.floor(baseU * 0.5), math.floor(baseV * 0.5), 19) - 0.5) * 0.18

	alongSlope = alongSlope * stretch + heightShift * (0.18 + crest * 0.62) + time * 0.045
	acrossSlope = acrossSlope * compression + heightShift * crest * 0.32

	local edgeDistance, cellRandom = cellularEdge(
		alongSlope + coarseWarp,
		acrossSlope - coarseWarp,
		config.FoamNoiseSeed,
		0.82
	)
	local lineWidth = mixNumber(0.018, 0.078, crest) + slope * 0.014
	local feather = mixNumber(0.02, 0.045, math.max(crest, slope))
	local web = 1 - smoothstep(lineWidth, lineWidth + feather, edgeDistance)
	local density = math.clamp(0.28 + crest * 0.78 + slope * 0.26, 0, 1.25)
	local brokenLine = 0.62 + cellRandom * 0.38

	return math.clamp((web ^ mixNumber(1.55, 0.82, crest)) * brokenLine * density, 0, 1)
end

local function sampleContinuousCrestFoamLine(
	config: TileConfig,
	sampleHeight: number,
	waveScale: number,
	gradientX: number,
	gradientZ: number,
	crestMask: number
): number
	local highWaveThreshold = getHighWaveFoamThreshold(config, waveScale)
	local crestHeight = math.max(sampleHeight * waveScale, 0)
	local gradientMagnitude = math.sqrt(gradientX * gradientX + gradientZ * gradientZ)
	local heightBand = smoothstep(highWaveThreshold * 0.34, highWaveThreshold * 1.14, crestHeight)
	local ridge = 1 - smoothstep(0.1, 0.64, gradientMagnitude)
	local ribbon = math.max(crestMask, heightBand * ridge)
	local crestStrength = math.max(config.CrestFoamStrength, 0)

	return math.clamp(ribbon * crestStrength * (0.52 + config.HighWaveFoamStrength * 0.36), 0, 1)
end

local function applyFoamPatternAlpha(config: TileConfig, foamAlpha: number, pattern: number): number
	local influence = math.clamp(config.FoamNoiseInfluence, 0, 1)
	local cutout = (1 - influence) + math.clamp(pattern, 0, 1) * influence

	return math.clamp(foamAlpha * math.max(config.FoamVertexBoost, 0) * cutout, 0, 1)
end

local function sampleInteractiveFoam(config: TileConfig, waterBuffer: WaterBuffer.WaterBuffer, localX: number, localZ: number): number
	local slope, velocity = waterBuffer:SampleSurfaceActivity(localX, localZ)
	local slopeFoam = math.clamp(
		(slope - config.InteractiveFoamSlopeThreshold) / math.max(config.InteractiveFoamSlopeThreshold, 0.001),
		0,
		1
	)
	local velocityFoam = math.clamp(
		(velocity - config.InteractiveFoamVelocityThreshold) / math.max(config.InteractiveFoamVelocityThreshold * 2, 0.001),
		0,
		1
	)

	return math.clamp(math.max(slopeFoam, velocityFoam) * config.InteractiveFoamStrength, 0, 1)
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

local function createFoamBuffer(sourcePart: BasePart, config: TileConfig): WaterFoamBuffer.WaterFoamBuffer?
	if not config.FoamBufferEnabled or not usesSurfaceBufferForVisuals(config) then
		return nil
	end

	return WaterFoamBuffer.new({
		Resolution = config.FoamBufferResolution,
		SizeX = math.max(sourcePart.Size.X, 1),
		SizeZ = math.max(sourcePart.Size.Z, 1),
		Decay = config.FoamBufferDecay,
		Growth = config.FoamBufferGrowth,
		SlopeThreshold = config.InteractiveFoamSlopeThreshold,
		VelocityThreshold = config.InteractiveFoamVelocityThreshold,
		InteractiveStrength = config.InteractiveFoamStrength,
		ShallowStrength = config.ShoreFoamStrength,
		ObstacleStrength = config.ObstacleFoamStrength,
		MaxFoam = 1,
	})
end

local function configureFoamBuffer(bufferState: WaterFoamBuffer.WaterFoamBuffer, config: TileConfig)
	bufferState.Decay = config.FoamBufferDecay
	bufferState.Growth = config.FoamBufferGrowth
	bufferState.SlopeThreshold = config.InteractiveFoamSlopeThreshold
	bufferState.VelocityThreshold = config.InteractiveFoamVelocityThreshold
	bufferState.InteractiveStrength = config.InteractiveFoamStrength
	bufferState.ShallowStrength = config.ShoreFoamStrength
	bufferState.ObstacleStrength = config.ObstacleFoamStrength
	bufferState.MaxFoam = 1
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

local function waveSurfaceOffset(frameIndex: number, vertexIndex: number, vertexCount: number): number
	return (frameIndex * vertexCount + (vertexIndex - 1)) * WAVE_LOOP_SURFACE_BYTES
end

local function writeWaveLoopSurface(
	config: TileConfig,
	surface: buffer,
	frameIndex: number,
	vertexIndex: number,
	vertexCount: number,
	foam: number,
	tint: number
)
	local _, alpha = blendSurfaceColor(config, foam, tint)
	local offset = waveSurfaceOffset(frameIndex, vertexIndex, vertexCount)

	buffer.writeu8(surface, offset + WAVE_LOOP_SURFACE_FOAM, math.clamp(math.floor(foam * 255 + 0.5), 0, 255))
	buffer.writeu8(surface, offset + WAVE_LOOP_SURFACE_TINT, math.clamp(math.floor(tint * 255 + 0.5), 0, 255))
	buffer.writeu8(surface, offset + WAVE_LOOP_SURFACE_ALPHA, math.clamp(math.floor(alpha * 255 + 0.5), 0, 255))
	buffer.writeu8(surface, offset + 3, 0)
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

local function configureMeshPart(meshPart: MeshPart, sourcePart: BasePart, config: TileConfig, useVertexColors: boolean)
	meshPart.Name = "OceanTile_" .. sourcePart.Name
	meshPart.Anchored = true
	meshPart.CanCollide = false
	meshPart.CanTouch = false
	meshPart.CanQuery = false
	meshPart.CastShadow = false
	meshPart.Material = DEFAULT_MATERIAL
	meshPart.Color = if useVertexColors then VERTEX_COLOR_TINT else config.WaterColor
	meshPart.Transparency = config.Transparency
	meshPart.Reflectance = config.Reflectance
end

local function createBlankFoamImage(config: TileConfig): (EditableImage?, buffer?)
	local size = math.clamp(math.round(config.FoamTextureResolution), 16, 1024)
	local ok, editableImage = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
	end)

	if not ok or editableImage == nil then
		return nil, nil
	end

	local bytes = buffer.create(size * size * 4)

	for index = 0, size * size - 1 do
		local offset = index * 4
		buffer.writeu8(bytes, offset, 255)
		buffer.writeu8(bytes, offset + 1, 255)
		buffer.writeu8(bytes, offset + 2, 255)
		buffer.writeu8(bytes, offset + 3, 0)
	end

	editableImage:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), bytes)
	return editableImage, bytes
end

local function configureFoamTexture(tile: InternalOceanTile)
	local meshPart = tile.MeshPart
	local textureId = normalizeAssetId(tile._Config.FoamTextureId)
	local textureKey = if tile._Config.FoamTextureFromVerticesEnabled
		then `surface-buffer:{tile._Config.FoamTextureResolution}:{tile._Config.RuntimeSurfaceColorEnabled}`
		elseif textureId == nil
		then "none"
		else `asset:{textureId}`

	local surface = tile._FoamTexture

	local function createSurfaceAppearance(content: Content)
		if surface then
			surface:Destroy()
		end

		surface = AssetService:CreateSurfaceAppearanceAsync({
			ColorMap = content,
		})
		surface.Name = "FoamSurface"
		surface.Parent = meshPart
		tile._FoamTexture = surface
	end

	if textureKey ~= tile._FoamTextureKey and tile._Config.FoamTextureFromVerticesEnabled then
		if tile._FoamEditableImage then
			tile._FoamEditableImage:Destroy()
			tile._FoamEditableImage = nil
		end

		local editableImage, bytes = createBlankFoamImage(tile._Config)

		if editableImage ~= nil then
			tile._FoamEditableImage = editableImage
			tile._FoamImageBuffer = bytes
			tile._FoamTextureRowCursor = 0
			tile._FoamTextureBake = nil
			tile._FoamTextureBakeKey = ""
			createSurfaceAppearance(Content.fromObject(editableImage))
		end
	elseif textureKey ~= tile._FoamTextureKey and textureId == nil then
		if tile._FoamEditableImage then
			tile._FoamEditableImage:Destroy()
			tile._FoamEditableImage = nil
		end

		tile._FoamImageBuffer = nil
		tile._FoamTextureRowCursor = 0
		tile._FoamTextureBake = nil
		tile._FoamTextureBakeKey = ""

		if surface ~= nil then
			surface:Destroy()
			surface = nil
			tile._FoamTexture = nil
		end
	elseif textureKey ~= tile._FoamTextureKey and textureId ~= nil then
		if tile._FoamEditableImage then
			tile._FoamEditableImage:Destroy()
			tile._FoamEditableImage = nil
		end
		tile._FoamImageBuffer = nil
		tile._FoamTextureRowCursor = 0
		tile._FoamTextureBake = nil
		tile._FoamTextureBakeKey = ""

		local assetId = tonumber(string.match(textureId, "^rbxassetid://(%d+)$") or textureId)

		if assetId ~= nil then
			createSurfaceAppearance(Content.fromAssetId(assetId))
		elseif surface ~= nil then
			surface:Destroy()
			surface = nil
			tile._FoamTexture = nil
		end
	end

	tile._FoamTextureKey = textureKey

	if surface ~= nil then
		surface.Color = if tile._Config.FoamTextureFromVerticesEnabled then VERTEX_COLOR_TINT else tile._Config.FoamColor
	end
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

local function tryCreateColorIds(editableMesh: EditableMesh, config: TileConfig): { number }?
	local ok, colorIds = pcall(function()
		if config.FoamTextureFromVerticesEnabled then
			local color, vertexAlpha = blendSurfaceColor(config, 0, 0)

			return { editableMesh:AddColor(color, vertexAlpha) }
		end

		local ids = table.create(COLOR_BUCKETS + 1)

		for foamBucket = 0, SURFACE_FOAM_COLOR_BUCKETS do
			local foam = foamBucket / SURFACE_FOAM_COLOR_BUCKETS

			for tintBucket = 0, SURFACE_TINT_COLOR_BUCKETS do
				local tint = tintBucket / SURFACE_TINT_COLOR_BUCKETS
				local color, vertexAlpha = blendSurfaceColor(config, foam, tint)

				table.insert(ids, editableMesh:AddColor(color, vertexAlpha))
			end
		end

		return ids
	end)

	if not ok then
		return nil
	end

	return colorIds
end

local function setFaceBuckets(tile: InternalOceanTile, face: FaceState, bucketA: number, bucketB: number, bucketC: number): boolean
	local colorIds = tile._ColorIds

	if colorIds == nil then
		return false
	end

	local colorIdA = colorIds[bucketA + 1]
	local colorIdB = colorIds[bucketB + 1]
	local colorIdC = colorIds[bucketC + 1]

	if colorIdA == nil or colorIdB == nil or colorIdC == nil then
		return false
	end

	local ok = pcall(function()
		tile.EditableMesh:SetFaceColors(face.id, { colorIdA, colorIdB, colorIdC })
	end)

	if not ok then
		tile._ColorIds = nil
		return false
	end

	face.buckets[1] = bucketA
	face.buckets[2] = bucketB
	face.buckets[3] = bucketC
	return true
end

local function surfaceColorBucket(foam: number, tint: number): number
	local foamBucket = math.clamp(math.floor(foam * SURFACE_FOAM_COLOR_BUCKETS + 0.5), 0, SURFACE_FOAM_COLOR_BUCKETS)
	local tintBucket = math.clamp(math.floor(tint * SURFACE_TINT_COLOR_BUCKETS + 0.5), 0, SURFACE_TINT_COLOR_BUCKETS)

	return foamBucket * (SURFACE_TINT_COLOR_BUCKETS + 1) + tintBucket
end

local function createSurfaceUv(tile: InternalOceanTile, baseLocal: Vector3, foamEnabled: boolean): number?
	if not foamEnabled or not tile._UvEnabled then
		return nil
	end

	local halfSize = tile.SourcePart.Size * 0.5
	local u = math.clamp((baseLocal.X + halfSize.X) / math.max(tile.SourcePart.Size.X, 0.001), 0, 1)
	local v = math.clamp((baseLocal.Z + halfSize.Z) / math.max(tile.SourcePart.Size.Z, 0.001), 0, 1)
	local ok, uvId = pcall(function()
		return tile.EditableMesh:AddUV(Vector2.new(u, v))
	end)

	if not ok or uvId == nil then
		tile._UvEnabled = false
		return nil
	end

	return uvId
end

local function setSurfaceFaceUvs(tile: InternalOceanTile, face: FaceState)
	if not tile._UvEnabled then
		return
	end

	local a = tile._Vertices[face.a]
	local b = tile._Vertices[face.b]
	local c = tile._Vertices[face.c]

	if a == nil or b == nil or c == nil or a.uvId == nil or b.uvId == nil or c.uvId == nil then
		return
	end

	local ok = pcall(function()
		tile.EditableMesh:SetFaceUVs(face.id, { a.uvId, b.uvId, c.uvId })
	end)

	if not ok then
		tile._UvEnabled = false
	end
end

local function addMeshVertex(
	tile: InternalOceanTile,
	baseLocal: Vector3,
	gridX: number,
	gridZ: number,
	waveInfluence: number,
	foamEnabled: boolean
): number
	local editableMesh = tile.EditableMesh
	local vertices = tile._Vertices
	local vertexId = editableMesh:AddVertex(baseLocal)

	table.insert(vertices, {
		id = vertexId,
		baseLocal = baseLocal,
		gridX = gridX,
		gridZ = gridZ,
		uvId = createSurfaceUv(tile, baseLocal, foamEnabled),
		waveInfluence = math.clamp(waveInfluence, 0, 1),
		foamEnabled = foamEnabled,
		color = 0,
		foam = 0,
		foamAccumulation = 0,
		foamPattern = 1,
		crestTint = 0,
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
		buckets = { 0, 0, 0 },
	}

	table.insert(tile._Faces, face)
	setFaceBuckets(tile, face, 0, 0, 0)
	setSurfaceFaceUvs(tile, face)
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

local function buildSideStrip(
	tile: InternalOceanTile,
	edgeCount: number,
	topAt: EdgeVertexMapper,
	gridAt: EdgeGridMapper,
	reverseWinding: boolean
)
	local verticalSegments = math.clamp(math.round(tile._Config.VolumeVerticalSegments), 1, 8)
	local depth = math.max(tile.SourcePart.Size.Y, 0.1)
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
	local depth = math.max(tile.SourcePart.Size.Y, 0.1)
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

local function buildVolumeMesh(tile: InternalOceanTile)
	if not tile._Config.VolumeEnabled then
		return
	end

	local resolutionX = tile._ResolutionX
	local resolutionZ = tile._ResolutionZ

	buildSideStrip(tile, resolutionX + 1, function(index)
		return gridIndex(resolutionX, index, 0)
	end, function(index)
		return index, 0
	end, true)

	buildSideStrip(tile, resolutionX + 1, function(index)
		return gridIndex(resolutionX, index, resolutionZ)
	end, function(index)
		return index, resolutionZ
	end, false)

	buildSideStrip(tile, resolutionZ + 1, function(index)
		return gridIndex(resolutionX, 0, index)
	end, function(index)
		return 0, index
	end, false)

	buildSideStrip(tile, resolutionZ + 1, function(index)
		return gridIndex(resolutionX, resolutionX, index)
	end, function(index)
		return resolutionX, index
	end, true)

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

local function shouldUpdateLodVertex(tile: InternalOceanTile, vertex: VertexState, step: number): boolean
	if step <= 1 then
		return true
	end

	if vertex.gridX == 0 or vertex.gridX == tile._ResolutionX then
		return true
	end

	if vertex.gridZ == 0 or vertex.gridZ == tile._ResolutionZ then
		return true
	end

	return vertex.gridX % step == 0 and vertex.gridZ % step == 0
end

local function ringLodEntryOffset(entryIndex: number): number
	return entryIndex * RING_LOD_ENTRY_BYTES
end

local function ringFaceEntryOffset(entryIndex: number): number
	return entryIndex * RING_FACE_ENTRY_BYTES
end

local function getRingLodKey(config: TileConfig): string
	return `{config.Lod0Radius}:{config.Lod1Radius}:{config.Lod2Radius}:{config.LodRecenterDistance}:{config.VertexSpacing}:{config.MidLodVertexStep}:{config.FarLodVertexStep}:{config.ExtremeLodVertexStep}:{config.FarWaveDetail}:{config.FoamDistance}`
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

local function getRingFoamScale(lodLevel: number): number
	if lodLevel <= RING_LEVEL_NEAR then
		return 1
	end

	if lodLevel == RING_LEVEL_MID then
		return 0.42
	end

	return 0
end

local function applySurfaceAlphaVertices(
	tile: InternalOceanTile,
	ringIndices: buffer,
	ringCount: number,
	foamActive: boolean
): (number, number)
	local foamTotal = 0
	local colorTotal = 0
	local config = tile._Config

	for entryIndex = 0, ringCount - 1 do
		local entryOffset = ringLodEntryOffset(entryIndex)
		local vertexIndex = buffer.readu16(ringIndices, entryOffset + RING_LOD_VERTEX_OFFSET)
		local vertex = tile._Vertices[vertexIndex]

		if vertex == nil then
			continue
		end

		local foam = 0
		local crestTint = 0

		if foamActive and vertex.foamEnabled then
			foam = math.clamp(vertex.foamAccumulation, 0, 1)
			crestTint = math.clamp(vertex.crestTint, 0, 1)
		else
			vertex.foamAccumulation = 0
			vertex.foamPattern = 1
			vertex.crestTint = 0
		end

		if config.FoamTextureFromVerticesEnabled then
			vertex.foam = 0
			vertex.color = surfaceColorBucket(0, 0)
			foamTotal += foam
			colorTotal += math.max(foam, crestTint)
		else
			local patternedFoam = applyFoamPatternAlpha(config, foam, vertex.foamPattern)

			vertex.foam = patternedFoam
			vertex.color = surfaceColorBucket(patternedFoam, crestTint)
			foamTotal += patternedFoam
			colorTotal += math.max(patternedFoam, crestTint)
		end
	end

	return foamTotal, colorTotal
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

		if lodLevel >= RING_LEVEL_FAR then
			vertex.color = 0
			vertex.foam = 0
			vertex.foamAccumulation = 0
			vertex.foamPattern = 1
			vertex.crestTint = 0
		end

		if shouldUpdateLodVertex(tile, vertex, step) then
			local offset = ringLodEntryOffset(entryCount)

			buffer.writeu16(indices, offset + RING_LOD_VERTEX_OFFSET, vertexIndex)
			buffer.writeu16(indices, offset + RING_LOD_LEVEL_OFFSET, lodLevel)
			entryCount += 1
		end
	end

	local maxFaceCount = #tile._Faces
	local foamFaces = buffer.create(math.max(maxFaceCount, 1) * RING_FACE_ENTRY_BYTES)
	local foamFaceCount = 0
	local foamFaceRadius = config.Lod1Radius + seamWidth
	local resolutionX = tile._ResolutionX
	local resolutionZ = tile._ResolutionZ

	for z = 0, resolutionZ - 1 do
		local z0 = buffer.readf32(tile._GridZCoordinates, z * 4)
		local z1 = buffer.readf32(tile._GridZCoordinates, (z + 1) * 4)
		local cellZ = (z0 + z1) * 0.5

		for x = 0, resolutionX - 1 do
			local x0 = buffer.readf32(tile._GridXCoordinates, x * 4)
			local x1 = buffer.readf32(tile._GridXCoordinates, (x + 1) * 4)
			local cellX = (x0 + x1) * 0.5
			local ringDistance = math.max(math.abs(cellX - centerX), math.abs(cellZ - centerZ))

			if ringDistance <= foamFaceRadius then
				local faceIndex = (z * resolutionX + x) * 2 + 1
				local offsetA = ringFaceEntryOffset(foamFaceCount)

				buffer.writeu16(foamFaces, offsetA, faceIndex)
				foamFaceCount += 1

				local offsetB = ringFaceEntryOffset(foamFaceCount)

				buffer.writeu16(foamFaces, offsetB, faceIndex + 1)
				foamFaceCount += 1
			end
		end
	end

	tile._RingLodIndices = indices
	tile._RingLodCount = entryCount
	tile._RingLodCenterX = centerX
	tile._RingLodCenterZ = centerZ
	tile._RingLodKey = key
	tile._RingLodDirty = false

	if tile._PreviousRingFoamFaceIndices ~= nil and tile._PreviousRingFoamFaceCount > 0 then
		tile._RingFoamFullRefresh = true
	else
		tile._PreviousRingFoamFaceIndices = tile._RingFoamFaceIndices
		tile._PreviousRingFoamFaceCount = tile._RingFoamFaceCount
	end

	tile._RingFoamFaceIndices = foamFaces
	tile._RingFoamFaceCount = foamFaceCount
end

local function sampleDepth(depthMap: WaterDepthMap.WaterDepthMap?, config: TileConfig, localX: number, localZ: number): number
	if depthMap == nil then
		return config.FallbackDepth
	end

	return depthMap:SampleDepth(localX, localZ)
end

local function sampleObstacleFoam(obstacleMap: WaterObstacleMap.WaterObstacleMap?, localX: number, localZ: number): number
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

local function updateFoamBuffer(
	tile: InternalOceanTile,
	time: number,
	deltaTime: number,
	detail: number,
	physicsActive: boolean,
	centerLocalX: number,
	centerLocalZ: number,
	radius: number
)
	local foamBuffer = tile._FoamBuffer
	local waterBuffer = tile._WaterBuffer
	local depthMap = tile._DepthMap
	local obstacleMap = tile._ObstacleMap

	if foamBuffer == nil then
		return
	end

	if detail <= 0.12 then
		return
	end

	local halfSize = tile.SourcePart.Size * 0.5
	local minX = math.max(centerLocalX - radius, -halfSize.X)
	local maxX = math.min(centerLocalX + radius, halfSize.X)
	local minZ = math.max(centerLocalZ - radius, -halfSize.Z)
	local maxZ = math.min(centerLocalZ + radius, halfSize.Z)
	local quality = if physicsActive then 3 elseif detail > 0.45 then 2 else 1

	if minX >= maxX or minZ >= maxZ then
		return
	end

	ensureWaveLoop(tile)

	-- Treat wave crests and green tint as writers into the persistent surface field.
	local function sampleWaveSurface(localX: number, localZ: number): (number, number)
		local waveFoam, waveTint = sampleWaveLoopSurfaceField(tile, localX, localZ, time)

		return waveFoam, waveTint
	end

	foamBuffer:UpdateRegionFromMaps(
		waterBuffer,
		depthMap,
		obstacleMap,
		deltaTime,
		minX,
		maxX,
		minZ,
		maxZ,
		quality,
		sampleWaveSurface
	)

	if time - tile._LastFoamMaxRecalculateTime >= FOAM_MAX_RECALCULATE_INTERVAL then
		tile._LastFoamMaxRecalculateTime = time
		foamBuffer:RecalculateMax()
	end
end

local function sampleRuntimeSurfaceFoamData(
	tile: InternalOceanTile,
	vertex: VertexState,
	localX: number,
	localZ: number
): (number, number, number)
	local config = tile._Config
	local depth = sampleDepth(tile._DepthMap, config, localX, localZ)
	local lakeDepth = math.max(config.LakeDepth, config.ShallowDepth + 0.001)
	local oceanDepth = math.max(config.OceanDepth, lakeDepth + 0.001)
	local shallowToLake = smoothstep(config.ShallowDepth, lakeDepth, depth)
	local deepFactor = smoothstep(config.ShallowDepth, oceanDepth, depth)
	local shoreFoam = if vertex.foamEnabled then (1 - shallowToLake) * config.ShoreFoamStrength else 0
	local obstacleFoam = if vertex.foamEnabled
		then sampleObstacleFoam(tile._ObstacleMap, localX, localZ) * config.ObstacleFoamStrength
		else 0
	local obstacleAttenuation = sampleObstacleAttenuation(tile._ObstacleMap, localX, localZ, config.ObstacleWaveDamping)
	local depthWaveScale = config.ShallowWaveScale + (config.DeepWaveScale - config.ShallowWaveScale) * deepFactor

	return shoreFoam, obstacleFoam, depthWaveScale * obstacleAttenuation * vertex.waveInfluence
end

local function sampleRuntimeSurfaceColor(
	tile: InternalOceanTile,
	vertex: VertexState,
	baseLocal: Vector3,
	dx: number,
	dy: number,
	dz: number,
	visualWaveScale: number,
	interactiveHeight: number,
	foamField: number,
	tintField: number,
	time: number
): (number, number, number)
	local config = tile._Config
	local _shoreFoam, _obstacleFoam, bakedWaveScale =
		sampleRuntimeSurfaceFoamData(tile, vertex, baseLocal.X, baseLocal.Z)
	local sourceWaveScale = if math.abs(bakedWaveScale) > 0.001 then bakedWaveScale else 1
	local rawHeight = dy / sourceWaveScale
	local effectiveWaveScale = sourceWaveScale * visualWaveScale
	local patternGradientScale = math.max(config.FoamTextureStudsPerTile, 1)
	local gradientX = (dx * visualWaveScale) / patternGradientScale
	local gradientZ = (dz * visualWaveScale) / patternGradientScale
	local _waveFoam, _greenAlpha, crestMask, slopeMask =
		sampleWaveFoamShape(config, rawHeight, effectiveWaveScale, 0, gradientX, gradientZ)
	local foamSeed = math.clamp(foamField, 0, 1)
	local foamPattern = 1

	if foamSeed > 0.001 then
		local materialCrestMask = math.max(crestMask, foamSeed * 0.64)
		local materialSlopeMask = math.max(slopeMask, foamSeed * 0.36)

		foamPattern = sampleCellularFoamPattern(
			config,
			baseLocal.X,
			baseLocal.Z,
			dy * visualWaveScale + interactiveHeight,
			gradientX,
			gradientZ,
			materialCrestMask,
			materialSlopeMask,
			time
		)
	end

	return math.clamp(foamSeed, 0, 1), math.clamp(tintField, 0, 1), foamPattern
end

local function getWaveLoopGeometryKey(config: TileConfig): string
	return `{FOAM_BAKE_VERSION}:{math.clamp(math.round(config.WaveLoopFrames), 2, 240)}:{math.max(config.WaveLoopDuration, 0.25)}:{config.ShallowWaveScale}:{config.DeepWaveScale}:{config.ShallowDepth}:{config.LakeDepth}:{config.OceanDepth}:{config.ObstacleWaveDamping}`
end

local function getWaveLoopKey(config: TileConfig): string
	local geometryKey = getWaveLoopGeometryKey(config)

	return `{geometryKey}:crest-field:{config.CrestFoamStrength}:{config.HighWaveFoamThreshold}:{config.HighWaveFoamStrength}`
end

local function bakeWaveLoop(tile: InternalOceanTile)
	local config = tile._Config
	local vertexCount = #tile._Vertices
	local frames = math.clamp(math.round(config.WaveLoopFrames), 2, 240)
	local duration = math.max(config.WaveLoopDuration, 0.25)
	local positions = buffer.create(vertexCount * frames * WAVE_LOOP_POSITION_BYTES)
	local heights = buffer.create(vertexCount * frames * WAVE_LOOP_HEIGHT_BYTES)
	local surface = buffer.create(vertexCount * frames * WAVE_LOOP_SURFACE_BYTES)
	local static = buffer.create(vertexCount * VERTEX_BAKE_STATIC_BYTES)
	local baseCFrame = tile.BaseCFrame
	local obstacleVertices = buffer.create(MAX_OBSTACLE_IMPACT_VERTICES * OBSTACLE_IMPACT_VERTEX_BYTES)
	local obstacleVertexCount = 0
	local processedSinceYield = 0
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
		local shoreFactor = 1 - shallowToLake
		local obstacleFoam = if vertex.foamEnabled then sampleObstacleFoam(tile._ObstacleMap, localX, localZ) else 0
		local obstacleAttenuation = sampleObstacleAttenuation(tile._ObstacleMap, localX, localZ, config.ObstacleWaveDamping)
		local depthWaveScale = config.ShallowWaveScale + (config.DeepWaveScale - config.ShallowWaveScale) * deepFactor
		local waveScale = depthWaveScale * obstacleAttenuation * vertex.waveInfluence

		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_BASE_WORLD_X), baseWorld.X)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_BASE_WORLD_Z), baseWorld.Z)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_WAVE_SCALE), waveScale)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_SHORE_FOAM), if vertex.foamEnabled then shoreFactor * config.ShoreFoamStrength else 0)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_OBSTACLE_FOAM), obstacleFoam * config.ObstacleFoamStrength)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_OCEAN_WEIGHT), oceanWeight)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_LAKE_WEIGHT), lakeWeight)
		buffer.writef32(static, vertexBakeStaticOffset(vertexIndex, VERTEX_STATIC_SHALLOW_WEIGHT), shallowWeight)

		if vertex.foamEnabled and obstacleFoam >= 0.55 and obstacleVertexCount < MAX_OBSTACLE_IMPACT_VERTICES then
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
			local displacementX, sampleHeight, displacementZ, sampleFoam =
				tile._Spectrum:SampleBakedWeighted3XZ(baseWorldX, baseWorldZ, bakeTime, 1, oceanWeight, lakeWeight, shallowWeight)
			local loopProgress = frameIndex / frames
			local seamStart = 1 - WAVE_LOOP_SEAM_FRACTION

			if loopProgress >= seamStart then
				local seamAlpha = smoothstep(seamStart, 1, loopProgress)
				local previousX, previousHeight, previousZ, previousFoam =
					tile._Spectrum:SampleBakedWeighted3XZ(baseWorldX, baseWorldZ, bakeTime - duration, 1, oceanWeight, lakeWeight, shallowWeight)

				displacementX += (previousX - displacementX) * seamAlpha
				sampleHeight += (previousHeight - sampleHeight) * seamAlpha
				displacementZ += (previousZ - displacementZ) * seamAlpha
				sampleFoam += (previousFoam - sampleFoam) * seamAlpha
			end

			local waveScale = buffer.readf32(static, staticOffset + VERTEX_STATIC_WAVE_SCALE * 4)
			local delta = baseCFrame:VectorToObjectSpace(Vector3.new(displacementX, sampleHeight, displacementZ) * waveScale)
			local positionOffset = wavePositionOffset(frameIndex, vertexIndex, vertexCount, 0)

			buffer.writef32(positions, positionOffset, delta.X)
			buffer.writef32(positions, positionOffset + 4, delta.Y)
			buffer.writef32(positions, positionOffset + 8, delta.Z)
			buffer.writef32(heights, waveHeightOffset(frameIndex, vertexIndex, vertexCount), delta.Y)

			local drawnFoam, crestTint, crestMask = sampleWaveFoamShape(config, sampleHeight, waveScale, sampleFoam, 0, 0)
			local crestLine = sampleContinuousCrestFoamLine(config, sampleHeight, waveScale, 0, 0, crestMask)
			local waveFoam = math.clamp(math.max(drawnFoam, crestLine), 0, 1)

			writeWaveLoopSurface(config, surface, frameIndex, vertexIndex, vertexCount, waveFoam, crestTint)

			processedSinceYield += 1

			if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
				processedSinceYield = 0
				task.wait()
			end
		end
	end

	tile._WaveLoopPositions = positions
	tile._WaveLoopHeights = heights
	tile._WaveLoopSurface = surface
	tile._WaveLoopFrames = frames
	tile._WaveLoopFrameStride = vertexCount
	tile._WaveLoopDuration = duration
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
		and tile._WaveLoopSurface ~= nil
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

local function readWaveLoopSurface(
	surface: buffer,
	frameA: number,
	frameB: number,
	alpha: number,
	vertexCount: number,
	vertexIndex: number
): (number, number, number)
	local surfaceOffsetA = waveSurfaceOffset(frameA, vertexIndex, vertexCount)
	local surfaceOffsetB = waveSurfaceOffset(frameB, vertexIndex, vertexCount)
	local foamA = buffer.readu8(surface, surfaceOffsetA + WAVE_LOOP_SURFACE_FOAM) / 255
	local foamB = buffer.readu8(surface, surfaceOffsetB + WAVE_LOOP_SURFACE_FOAM) / 255
	local tintA = buffer.readu8(surface, surfaceOffsetA + WAVE_LOOP_SURFACE_TINT) / 255
	local tintB = buffer.readu8(surface, surfaceOffsetB + WAVE_LOOP_SURFACE_TINT) / 255
	local alphaA = buffer.readu8(surface, surfaceOffsetA + WAVE_LOOP_SURFACE_ALPHA) / 255
	local alphaB = buffer.readu8(surface, surfaceOffsetB + WAVE_LOOP_SURFACE_ALPHA) / 255

	return foamA + (foamB - foamA) * alpha, tintA + (tintB - tintA) * alpha, alphaA + (alphaB - alphaA) * alpha
end

local function readWaveLoopVertex(
	positions: buffer,
	surface: buffer,
	frameA: number,
	frameB: number,
	alpha: number,
	vertexCount: number,
	vertexIndex: number
): (number, number, number, number, number, number)
	local offsetA = wavePositionOffset(frameA, vertexIndex, vertexCount, 0)
	local offsetB = wavePositionOffset(frameB, vertexIndex, vertexCount, 0)
	local foam, tint, alphaValue = readWaveLoopSurface(surface, frameA, frameB, alpha, vertexCount, vertexIndex)
	local ax = buffer.readf32(positions, offsetA)
	local ay = buffer.readf32(positions, offsetA + 4)
	local az = buffer.readf32(positions, offsetA + 8)

	return
		ax + (buffer.readf32(positions, offsetB) - ax) * alpha,
		ay + (buffer.readf32(positions, offsetB + 4) - ay) * alpha,
		az + (buffer.readf32(positions, offsetB + 8) - az) * alpha,
		foam,
		tint,
		alphaValue
end

sampleWaveLoopSurfaceField = function(tile: InternalOceanTile, localX: number, localZ: number, time: number): (number, number)
	ensureWaveLoop(tile)

	local surface = tile._WaveLoopSurface

	if surface == nil then
		return 0, 0
	end

	local surfaceBuffer = surface
	local resolutionX = tile._ResolutionX
	local resolutionZ = tile._ResolutionZ
	local x0, x1, tx = getAxisCell(tile._GridXCoordinates, resolutionX, localX)
	local z0, z1, tz = getAxisCell(tile._GridZCoordinates, resolutionZ, localZ)
	local frameA, frameB, alpha = getWaveLoopFrame(tile, time)
	local vertexCount = math.max(tile._WaveLoopFrameStride, 1)

	local function readSurface(vertexIndex: number): (number, number)
		local foam, tint = readWaveLoopSurface(surfaceBuffer, frameA, frameB, alpha, vertexCount, vertexIndex)

		return foam, tint
	end

	local foam00, tint00 = readSurface(gridIndex(resolutionX, x0, z0))
	local foam10, tint10 = readSurface(gridIndex(resolutionX, x1, z0))
	local foam01, tint01 = readSurface(gridIndex(resolutionX, x0, z1))
	local foam11, tint11 = readSurface(gridIndex(resolutionX, x1, z1))
	local foam0 = foam00 + (foam10 - foam00) * tx
	local foam1 = foam01 + (foam11 - foam01) * tx
	local tint0 = tint00 + (tint10 - tint00) * tx
	local tint1 = tint01 + (tint11 - tint01) * tx

	return foam0 + (foam1 - foam0) * tz, tint0 + (tint1 - tint0) * tz
end

local function sampleWaveLoop(tile: InternalOceanTile, vertexIndex: number, time: number): (Vector3, number)
	ensureWaveLoop(tile)

	local positions = tile._WaveLoopPositions
	local surface = tile._WaveLoopSurface

	if positions == nil or surface == nil then
		return Vector3.zero, 0
	end

	local frameA, frameB, alpha = getWaveLoopFrame(tile, time)
	local dx, dy, dz, bakedFoam = readWaveLoopVertex(
		positions,
		surface,
		frameA,
		frameB,
		alpha,
		math.max(tile._WaveLoopFrameStride, 1),
		vertexIndex
	)

	return Vector3.new(dx, dy, dz), bakedFoam
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

local function sampleFoamImagePixel(
	tile: InternalOceanTile,
	localX: number,
	localZ: number,
	time: number,
	useLiveSurfaceBuffer: boolean
): (number, number, number, number)
	local config = tile._Config
	local foamBuffer = tile._FoamBuffer
	local foamField = 0
	local tintField = 0

	if useLiveSurfaceBuffer and foamBuffer ~= nil then
		foamField = foamBuffer:SampleFoam(localX, localZ)
		tintField = foamBuffer:SampleTint(localX, localZ)
	else
		local waveFoam, greenAlpha = sampleWaveLoopSurfaceField(tile, localX, localZ, time)
		local depth = sampleDepth(tile._DepthMap, config, localX, localZ)
		local lakeDepth = math.max(config.LakeDepth, config.ShallowDepth + 0.001)
		local shallowToLake = smoothstep(config.ShallowDepth, lakeDepth, depth)
		local shoreFoam = (1 - shallowToLake) * config.ShoreFoamStrength
		local obstacleFoam = sampleObstacleFoam(tile._ObstacleMap, localX, localZ) * config.ObstacleFoamStrength

		foamField = math.max(waveFoam, shoreFoam * 0.82, obstacleFoam * 0.9)
		tintField = greenAlpha
	end

	local foamLayerOpacity = 1 - math.clamp(config.FoamTextureTransparency, 0, 1)
	local finalFoam = math.clamp(math.clamp(foamField, 0, 1) * math.max(config.FoamVertexBoost, 0) * foamLayerOpacity, 0, 1)
	local finalTint = math.clamp(tintField, 0, 1)
	local color, alpha = blendSurfaceColor(config, finalFoam, finalTint)

	return color.R, color.G, color.B, alpha
end

local function getFoamTextureBakeKey(tile: InternalOceanTile, size: number): string
	local config = tile._Config
	local sourceSize = tile.SourcePart.Size
	local waterColor = config.WaterColor
	local waterTintColor = config.WaterTintColor or DEFAULT_WATER_TINT_COLOR
	local foamColor = config.FoamColor

	return `{size}:{sourceSize.X}:{sourceSize.Z}:{config.FoamVertexBoost}:{config.FoamTextureTransparency}:{config.WaterVertexAlpha}:{config.FoamVertexAlpha}:{waterColor.R}:{waterColor.G}:{waterColor.B}:{waterTintColor.R}:{waterTintColor.G}:{waterTintColor.B}:{foamColor.R}:{foamColor.G}:{foamColor.B}:{config.ShoreFoamStrength}:{config.ObstacleFoamStrength}:{getWaveLoopKey(config)}`
end

local function foamTexturePixelOffset(size: number, x: number, y: number): number
	return (y * size + x) * 4
end

local function ensureFoamTextureBake(tile: InternalOceanTile, size: number)
	local key = getFoamTextureBakeKey(tile, size)

	if tile._FoamTextureBake ~= nil and tile._FoamTextureBakeKey == key then
		return
	end

	local frames = math.clamp(math.round(tile._Config.WaveLoopFrames / 4), 4, if size <= 128 then 16 else 8)
	local duration = math.max(tile._Config.WaveLoopDuration, 0.25)
	local framesByIndex = table.create(frames) :: { buffer }
	local processedSinceYield = 0

	for frameIndex = 0, frames - 1 do
		local bakeTime = (frameIndex / frames) * duration
		local bytes = buffer.create(size * size * 4)

		for y = 0, size - 1 do
			local v = (y + 0.5) / size
			local localZ = (v - 0.5) * tile.SourcePart.Size.Z

			for x = 0, size - 1 do
				local u = (x + 0.5) / size
				local localX = (u - 0.5) * tile.SourcePart.Size.X
				local red, green, blue, alpha = sampleFoamImagePixel(tile, localX, localZ, bakeTime, false)
				local offset = foamTexturePixelOffset(size, x, y)

				buffer.writeu8(bytes, offset, math.clamp(math.floor(red * 255 + 0.5), 0, 255))
				buffer.writeu8(bytes, offset + 1, math.clamp(math.floor(green * 255 + 0.5), 0, 255))
				buffer.writeu8(bytes, offset + 2, math.clamp(math.floor(blue * 255 + 0.5), 0, 255))
				buffer.writeu8(bytes, offset + 3, math.clamp(math.floor(alpha * 255 + 0.5), 0, 255))

				processedSinceYield += 1

				if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
					processedSinceYield = 0
					task.wait()
				end
			end
		end

		framesByIndex[frameIndex + 1] = bytes
	end

	tile._FoamTextureBake = framesByIndex
	tile._FoamTextureBakeKey = key
	tile._FoamTextureBakeFrames = frames
	tile._FoamTextureBakeSize = size
end

local function writeRuntimeFoamTexture(tile: InternalOceanTile, editableImage: EditableImage, size: number, time: number)
	local bytes = buffer.create(size * size * 4)

	for y = 0, size - 1 do
		local v = (y + 0.5) / size
		local localZ = (v - 0.5) * tile.SourcePart.Size.Z

		for x = 0, size - 1 do
			local u = (x + 0.5) / size
			local localX = (u - 0.5) * tile.SourcePart.Size.X
			local red, green, blue, alpha = sampleFoamImagePixel(tile, localX, localZ, time, true)
			local offset = foamTexturePixelOffset(size, x, y)

			buffer.writeu8(bytes, offset, math.clamp(math.floor(red * 255 + 0.5), 0, 255))
			buffer.writeu8(bytes, offset + 1, math.clamp(math.floor(green * 255 + 0.5), 0, 255))
			buffer.writeu8(bytes, offset + 2, math.clamp(math.floor(blue * 255 + 0.5), 0, 255))
			buffer.writeu8(bytes, offset + 3, math.clamp(math.floor(alpha * 255 + 0.5), 0, 255))
		end
	end

	tile._FoamImageBuffer = bytes
	tile._FoamTextureRowCursor = 0
	tile._FoamTextureBake = nil
	tile._FoamTextureBakeKey = ""
	tile._FoamTextureBakeFrames = 0
	tile._FoamTextureBakeSize = size
	editableImage:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), bytes)
end

function OceanTileClass:_SetFlat()
	if self._IsFlat then
		return
	end

	for _, vertex in ipairs(self._Vertices) do
		vertex.color = 0
		vertex.foam = 0
		vertex.foamAccumulation = 0
		vertex.foamPattern = 1
		vertex.crestTint = 0

		if not trySetVertexPosition(self, vertex.id, vertex.baseLocal) then
			return
		end
	end

	for _, face in ipairs(self._Faces) do
		setFaceBuckets(self, face, 0, 0, 0)
	end

	self._IsFlat = true
end

function OceanTileClass:_UpdateFoamColors(time: number)
	if self._ColorIds == nil then
		return
	end

	if time - self._LastFoamColorUpdate < self._Config.FoamColorUpdateInterval then
		return
	end

	self._LastFoamColorUpdate = time

	local function updateFace(face: FaceState): boolean
		local bucketA = self._Vertices[face.a].color
		local bucketB = self._Vertices[face.b].color
		local bucketC = self._Vertices[face.c].color

		if bucketA ~= face.buckets[1] or bucketB ~= face.buckets[2] or bucketC ~= face.buckets[3] then
			if not setFaceBuckets(self, face, bucketA, bucketB, bucketC) then
				return false
			end
		end

		return true
	end

	if self._RingFoamFullRefresh then
		self._RingFoamFullRefresh = false
		self._PreviousRingFoamFaceIndices = nil
		self._PreviousRingFoamFaceCount = 0

		for _, face in ipairs(self._Faces) do
			if not updateFace(face) then
				return
			end
		end

		return
	end

	local previousFaceIndices = self._PreviousRingFoamFaceIndices

	if previousFaceIndices ~= nil and self._PreviousRingFoamFaceCount > 0 then
		for entryIndex = 0, self._PreviousRingFoamFaceCount - 1 do
			local faceIndex = buffer.readu16(previousFaceIndices, ringFaceEntryOffset(entryIndex))
			local face = self._Faces[faceIndex]

			if face ~= nil and not updateFace(face) then
				return
			end
		end

		self._PreviousRingFoamFaceIndices = nil
		self._PreviousRingFoamFaceCount = 0
	end

	local faceIndices = self._RingFoamFaceIndices

	if faceIndices == nil or self._RingFoamFaceCount <= 0 then
		return
	end

	for entryIndex = 0, self._RingFoamFaceCount - 1 do
		local faceIndex = buffer.readu16(faceIndices, ringFaceEntryOffset(entryIndex))
		local face = self._Faces[faceIndex]

		if face ~= nil and not updateFace(face) then
			return
		end
	end
end

function OceanTileClass:_UpdateFoamTexture(time: number)
	if not self._Config.FoamTextureFromVerticesEnabled then
		return
	end

	if time - self._LastFoamTextureUpdate < self._Config.FoamTextureUpdateInterval then
		return
	end

	local editableImage = self._FoamEditableImage

	if editableImage == nil then
		return
	end

	self._LastFoamTextureUpdate = time
	local size = math.clamp(math.round(self._Config.FoamTextureResolution), 16, 1024)

	if self._Config.RuntimeSurfaceColorEnabled then
		writeRuntimeFoamTexture(self, editableImage, size, time)
		return
	end

	ensureFoamTextureBake(self, size)
	local frames = self._FoamTextureBake
	local frameCount = self._FoamTextureBakeFrames

	if frames == nil or frameCount <= 0 or self._FoamTextureBakeSize ~= size then
		return
	end

	local duration = math.max(self._Config.WaveLoopDuration, 0.25)
	local frameIndex = (math.floor(((time % duration) / duration) * frameCount) % frameCount) + 1
	local bytes = frames[frameIndex]

	if bytes == nil then
		return
	end

	self._FoamImageBuffer = bytes
	self._FoamTextureRowCursor = frameIndex
	editableImage:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), bytes)
end

function OceanTileClass:_ClearFoam()
	if not self._FoamVisible then
		return
	end

	for _, vertex in ipairs(self._Vertices) do
		vertex.color = 0
		vertex.foam = 0
		vertex.foamAccumulation = 0
		vertex.foamPattern = 1
		vertex.crestTint = 0
	end

	for _, face in ipairs(self._Faces) do
		setFaceBuckets(self, face, 0, 0, 0)
	end

	if self._Config.FoamTextureFromVerticesEnabled and self._FoamEditableImage ~= nil and self._FoamImageBuffer ~= nil then
		local size = math.clamp(math.round(self._Config.FoamTextureResolution), 16, 1024)
		local blank = buffer.create(size * size * 4)

		for index = 0, size * size - 1 do
			local offset = index * 4

			buffer.writeu8(blank, offset, 255)
			buffer.writeu8(blank, offset + 1, 255)
			buffer.writeu8(blank, offset + 2, 255)
			buffer.writeu8(blank, offset + 3, 0)
		end

		self._FoamEditableImage:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), blank)
		self._FoamTextureRowCursor = 0
	end

	if self._SeaSprayEmitter then
		self._SeaSprayEmitter.Rate = 0
	end

	self._PreviousRingFoamFaceIndices = nil
	self._PreviousRingFoamFaceCount = 0
	self._RingFoamFullRefresh = false
	self._FoamVisible = false
end

function OceanTileClass:Update(time: number, camera: Camera?, renderVisible: boolean?)
	if self._Destroyed or self._MeshInvalid then
		return
	end

	self.BaseCFrame = getBaseCFrame(self.SourcePart)
	self.MeshPart.CFrame = self.BaseCFrame

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

		if self._FoamBuffer ~= nil and self._FoamBuffer.MaxValue > 0 then
			self._FoamBuffer:Clear()
		end

		self:_SetFlat()
		return
	end

	local foamActive = distance <= self._Config.FoamDistance and detail > 0.35
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

	if foamActive and self._FoamBuffer ~= nil then
		updateFoamBuffer(self, time, deltaTime, detail, physicsActive, cameraLocal.X, cameraLocal.Z, self._Config.FoamDistance)
	elseif not foamActive and self._FoamBuffer ~= nil and self._FoamBuffer.MaxValue > 0 then
		self._FoamBuffer:Clear()
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

	local bakedSurfaceTexture = isFinalBakedSurfaceTexture(self._Config)
	local foamTotal = 0
	local colorTotal = 0
	local positions: buffer? = nil
	local waveSurface: buffer? = nil
	local frameA = 0
	local frameB = 0
	local frameAlpha = 0
	local vertexCount = 1

	ensureWaveLoop(self)
	positions = self._WaveLoopPositions
	waveSurface = self._WaveLoopSurface

	if positions ~= nil and waveSurface ~= nil then
		frameA, frameB, frameAlpha = getWaveLoopFrame(self, time)
		vertexCount = math.max(self._WaveLoopFrameStride, 1)
	end

	local interactiveBufferActive = physicsActive and waterBuffer ~= nil and waterBuffer:HasActivity()
	ensureRingLodCache(self, cameraLocal.X, cameraLocal.Z)

	local ringIndices = self._RingLodIndices
	local updatedVertexCount = 0

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

		updatedVertexCount += 1

		local vertexDetail = getRingLodDetail(self._Config, detail, lodLevel)
		local vertexDistanceFactor = getRingDistanceFactor(distanceFactor, lodLevel)

		local dx = 0
		local dy = 0
		local dz = 0
		local bakedFoam = 0
		local bakedCrest = 0

		if positions ~= nil and waveSurface ~= nil then
			dx, dy, dz, bakedFoam, bakedCrest = readWaveLoopVertex(
				positions,
				waveSurface,
				frameA,
				frameB,
				frameAlpha,
				vertexCount,
				vertexIndex
			)
		end

		local baseLocal = vertex.baseLocal
		local surfaceFoamScale = if foamActive and vertex.foamEnabled then getRingFoamScale(lodLevel) else 0
		local dynamicFoamActive = foamActive and vertex.foamEnabled and surfaceFoamScale > 0
		local interactiveHeight = if interactiveBufferActive and waterBuffer ~= nil and vertex.foamEnabled and lodLevel == RING_LEVEL_NEAR
			then waterBuffer:SampleHeight(baseLocal.X, baseLocal.Z)
			else 0
		local vertexWaveScale = vertexDetail * vertexDistanceFactor

		if bakedSurfaceTexture then
			foamTotal += math.clamp(bakedFoam * vertexDetail * vertexDistanceFactor, 0, 1)
			vertex.foamAccumulation = 0
			vertex.foamPattern = 1
			vertex.crestTint = 0

			local localPosition = Vector3.new(
				baseLocal.X + dx * vertexWaveScale,
				baseLocal.Y + dy * vertexWaveScale + interactiveHeight * vertexDistanceFactor,
				baseLocal.Z + dz * vertexWaveScale
			)

			if not trySetVertexPosition(self, vertex.id, localPosition) then
				return
			end

			continue
		end

		local fallbackInteractiveFoam = if self._FoamBuffer == nil and dynamicFoamActive and interactiveBufferActive and waterBuffer ~= nil
			then sampleInteractiveFoam(self._Config, waterBuffer, baseLocal.X, baseLocal.Z)
			else 0
		local fallbackStaticFoam = 0

		if self._FoamBuffer == nil and dynamicFoamActive then
			local shoreFoam, obstacleFoam = sampleRuntimeSurfaceFoamData(self, vertex, baseLocal.X, baseLocal.Z)

			fallbackStaticFoam = math.max(shoreFoam * 0.82, obstacleFoam * 0.9)
		end

		local bufferedFoam = if dynamicFoamActive and self._FoamBuffer ~= nil
			then self._FoamBuffer:SampleFoam(baseLocal.X, baseLocal.Z)
			else 0
		local bufferedTint = if dynamicFoamActive and self._FoamBuffer ~= nil
			then self._FoamBuffer:SampleTint(baseLocal.X, baseLocal.Z)
			else 0
		local foamField = if self._FoamBuffer ~= nil
			then bufferedFoam
			else math.max(bakedFoam * vertexDetail, fallbackInteractiveFoam, fallbackStaticFoam)
		local tintField = if self._FoamBuffer ~= nil
			then bufferedTint
			else bakedCrest * vertexDetail
		local foamSeed = 0
		local foamPattern = 1
		local crestTint = 0

		if self._Config.FoamTextureFromVerticesEnabled and surfaceFoamScale > 0 then
			foamSeed = foamField * surfaceFoamScale
			crestTint = math.clamp(tintField * vertexDistanceFactor, 0, 1)
		elseif self._Config.RuntimeSurfaceColorEnabled and surfaceFoamScale > 0 then
			local runtimeFoam, runtimeCrestTint, runtimeFoamPattern = sampleRuntimeSurfaceColor(
				self,
				vertex,
				baseLocal,
				dx,
				dy,
				dz,
				vertexWaveScale,
				interactiveHeight,
				foamField,
				tintField,
				time
			)

			foamSeed = runtimeFoam * surfaceFoamScale
			foamPattern = runtimeFoamPattern
			crestTint = math.clamp(runtimeCrestTint * vertexDistanceFactor, 0, 1)
		elseif surfaceFoamScale > 0 then
			foamSeed = foamField * surfaceFoamScale
			crestTint = math.clamp(tintField * vertexDistanceFactor, 0, 1)

			if foamSeed > 0.001 and vertex.foamEnabled and not self._Config.FoamTextureFromVerticesEnabled then
				local patternGradientScale = math.max(self._Config.FoamTextureStudsPerTile, 1)
				local gradientX = (dx * vertexWaveScale) / patternGradientScale
				local gradientZ = (dz * vertexWaveScale) / patternGradientScale
				local materialFoam = math.clamp(foamField, 0, 1)
				local crestMask = math.clamp(math.max(bakedCrest * vertexDetail, bakedFoam * 0.72, materialFoam * 0.64), 0, 1)
				local slopeMask = math.clamp(
					math.sqrt(gradientX * gradientX + gradientZ * gradientZ) * 3
						+ materialFoam * 0.36,
					0,
					1
				)

				foamPattern = sampleCellularFoamPattern(
					self._Config,
					baseLocal.X,
					baseLocal.Z,
					dy * vertexWaveScale + interactiveHeight,
					gradientX,
					gradientZ,
					crestMask,
					slopeMask,
					time
				)
			end
		end

		local localPosition = Vector3.new(
			baseLocal.X + dx * vertexWaveScale,
			baseLocal.Y + dy * vertexWaveScale + interactiveHeight * vertexDistanceFactor,
			baseLocal.Z + dz * vertexWaveScale
		)

		vertex.foamAccumulation = math.clamp(foamSeed * vertexDistanceFactor, 0, 1)
		vertex.foamPattern = foamPattern
		vertex.crestTint = if vertex.foamEnabled then crestTint else 0
		if not trySetVertexPosition(self, vertex.id, localPosition) then
			return
		end
	end

	if not bakedSurfaceTexture then
		foamTotal, colorTotal = applySurfaceAlphaVertices(self, ringIndices, self._RingLodCount, foamActive)
	end
	self._IsFlat = false

	if foamActive then
		if not self._Config.FoamTextureFromVerticesEnabled then
			self:_UpdateFoamColors(time)
		end

		self:_UpdateFoamTexture(time)
		self._FoamVisible = if self._Config.FoamTextureFromVerticesEnabled
			then self._FoamEditableImage ~= nil
			else foamTotal > 0.001 or colorTotal > 0.001
	else
		self:_ClearFoam()
	end

	if self._SeaSprayEmitter then
		local averageFoam = if foamActive then foamTotal / math.max(updatedVertexCount, 1) else 0
		self._SeaSprayEmitter.Rate = averageFoam * self._Config.SeaSprayRate
	end

	if self._Config.StaticObstacleSplashEnabled
		and self._SplashEmitter ~= nil
		and foamActive
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
	self._WaveLoopSurface = nil
	self._WaveLoopKey = ""
	self._FoamTextureBake = nil
	self._FoamTextureBakeKey = ""
	self._FoamTextureBakeFrames = 0
	self._FoamTextureBakeSize = 0
	self._LastFoamTextureUpdate = 0
end

function OceanTileClass:SetConfig(config: TileConfig)
	local previousConfig = self._Config
	local previousWaveLoopKey = getWaveLoopKey(previousConfig)
	local keepWaveLoop = self._WaveLoopPositions ~= nil
		and self._WaveLoopHeights ~= nil
		and self._WaveLoopSurface ~= nil
		and getWaveLoopGeometryKey(previousConfig) == getWaveLoopGeometryKey(config)
		and previousWaveLoopKey == getWaveLoopKey(config)
	local surfaceSourceChanged = previousWaveLoopKey ~= getWaveLoopKey(config)
		or previousConfig.RuntimeSurfaceColorEnabled ~= config.RuntimeSurfaceColorEnabled

	self._Config = config

	if keepWaveLoop then
		self._WaveLoopKey = getWaveLoopKey(config)
	else
		self._WaveLoopPositions = nil
		self._WaveLoopHeights = nil
		self._WaveLoopSurface = nil
		self._WaveLoopKey = ""
	end

	self._FoamTextureBake = nil
	self._FoamTextureBakeKey = ""
	self._FoamTextureBakeFrames = 0
	self._FoamTextureBakeSize = 0
	self._LastFoamTextureUpdate = 0
	self._RingLodIndices = nil
	self._RingLodCount = 0
	self._RingLodKey = ""
	self._RingLodDirty = true
	self._RingFoamFaceIndices = nil
	self._RingFoamFaceCount = 0
	self._PreviousRingFoamFaceIndices = nil
	self._PreviousRingFoamFaceCount = 0
	self._RingFoamFullRefresh = true
	self._ObstacleImpactVertices = nil
	self._ObstacleImpactVertexCount = 0
	self._ColorIds = tryCreateColorIds(self.EditableMesh, config)

	for _, face in ipairs(self._Faces) do
		face.buckets[1] = -1
		face.buckets[2] = -1
		face.buckets[3] = -1

		if config.FoamTextureFromVerticesEnabled then
			setFaceBuckets(self, face, 0, 0, 0)
		end
	end

	self.MeshPart.Color = if self._ColorIds ~= nil then VERTEX_COLOR_TINT else config.WaterColor
	self.MeshPart.Transparency = config.Transparency
	self.MeshPart.Reflectance = config.Reflectance

	if config.InteractiveWavesEnabled and self._WaterBuffer == nil then
		self._WaterBuffer = createWaterBuffer(self.SourcePart, config)
	elseif not config.InteractiveWavesEnabled then
		self._WaterBuffer = nil
	end

	if usesSurfaceBufferForVisuals(config) and config.FoamBufferEnabled then
		local foamBuffer = self._FoamBuffer
		local sizeX = math.max(self.SourcePart.Size.X, 1)
		local sizeZ = math.max(self.SourcePart.Size.Z, 1)

		if foamBuffer == nil
			or foamBuffer.Resolution ~= math.clamp(math.floor(config.FoamBufferResolution), 2, 62)
			or foamBuffer.SizeX ~= sizeX
			or foamBuffer.SizeZ ~= sizeZ
		then
			self._FoamBuffer = createFoamBuffer(self.SourcePart, config)
		else
			configureFoamBuffer(foamBuffer, config)

			if surfaceSourceChanged then
				foamBuffer:Clear()
			end
		end
	else
		self._FoamBuffer = nil
	end

	configureFoamTexture(self)
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

	if self._FoamBuffer ~= nil then
		local foamAmount = math.clamp(math.abs(strength) * 0.75 + math.min(radius / 18, 1) * 0.28, 0.08, 1)

		self._FoamBuffer:AddFoam(localPosition.X, localPosition.Z, radius * 1.25, foamAmount)
	end

	if math.abs(strength) >= 0.12 then
		self:EmitSplash(worldPosition, math.abs(strength), radius)
	end
end

function OceanTileClass:AddFoam(worldPosition: Vector3, radius: number, amount: number)
	local foamBuffer = self._FoamBuffer

	if foamBuffer == nil or radius <= 0 or amount <= 0 or not isWorldPositionNearCamera(worldPosition, self._Config.FoamDistance) then
		return
	end

	local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)

	foamBuffer:AddFoam(localPosition.X, localPosition.Z, radius, amount)
	self._InteractionWakeFrames = math.max(self._InteractionWakeFrames, 72)
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

	if self._FoamBuffer ~= nil then
		local movement = (newWorldCenter - oldWorldCenter).Magnitude
		local strength = math.clamp(movement / math.max(radius, 0.1), 0, 1) * (strengthScale or 1)

		self._FoamBuffer:AddFoam(newLocal.X, newLocal.Z, radius * 1.15, math.clamp(strength * 0.85 + 0.04, 0, 1))
	end
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
	local bottomLocalY = -math.max(self.SourcePart.Size.Y, 0.1) - (bottomPadding or 0)
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

	if self._HiddenSourcePart then
		self.SourcePart.LocalTransparencyModifier = self._SourceLocalTransparencyModifier
	end

	if self.MeshPart then
		self.MeshPart:Destroy()
	end

	if self.EditableMesh then
		pcall(function()
			self.EditableMesh:Destroy()
		end)
	end

	if self._FoamEditableImage then
		self._FoamEditableImage:Destroy()
		self._FoamEditableImage = nil
	end

	self._FoamImageBuffer = nil
	self._FoamTextureBake = nil
	self._FoamTextureBakeKey = ""
	self._FoamTextureBakeFrames = 0
	self._FoamTextureBakeSize = 0
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
		_ColorIds = nil,
		_WaterBuffer = createWaterBuffer(sourcePart, config),
		_DepthMap = createDepthMap(sourcePart, parent, config),
		_ObstacleMap = createObstacleMap(sourcePart, parent, config),
		_FoamBuffer = createFoamBuffer(sourcePart, config),
		_FoamTexture = nil,
		_FoamEditableImage = nil,
		_FoamTextureKey = nil,
		_FoamImageBuffer = nil,
		_FoamTextureRowCursor = 0,
		_FoamTextureBake = nil,
		_FoamTextureBakeKey = "",
		_FoamTextureBakeFrames = 0,
		_FoamTextureBakeSize = 0,
		_LastFoamTextureUpdate = 0,
		_UvEnabled = true,
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
		_LastFoamColorUpdate = 0,
		_FoamVisible = false,
		_InteractionWakeFrames = 0,
		_RingLodIndices = nil,
		_RingLodCount = 0,
		_RingLodCenterX = 0,
		_RingLodCenterZ = 0,
		_RingLodKey = "",
		_RingLodDirty = true,
		_RingFoamFaceIndices = nil,
		_RingFoamFaceCount = 0,
		_PreviousRingFoamFaceIndices = nil,
		_PreviousRingFoamFaceCount = 0,
		_RingFoamFullRefresh = false,
		_WaveLoopPositions = nil,
		_WaveLoopHeights = nil,
		_WaveLoopSurface = nil,
		_WaveLoopFrames = 0,
		_WaveLoopFrameStride = 0,
		_WaveLoopDuration = math.max(config.WaveLoopDuration, 0.25),
		_WaveLoopKey = "",
		_WaveLoopBaking = false,
		_ObstacleImpactVertices = nil,
		_ObstacleImpactVertexCount = 0,
		_LastObstacleSplashTime = 0,
		_LastFoamMaxRecalculateTime = 0,
	}, OceanTileClass) :: any

	tile._ColorIds = tryCreateColorIds(editableMesh, config)
	buildMesh(tile)

	local meshPart, meshPartError = createMeshPart(editableMesh)

	if meshPart == nil then
		tile:Destroy()
		return nil, meshPartError
	end

	if parent.Parent == nil then
		tile:Destroy()
		meshPart:Destroy()
		return nil, "Ocean tile parent was destroyed"
	end

	configureMeshPart(meshPart, sourcePart, config, tile._ColorIds ~= nil)
	meshPart.CFrame = tile.BaseCFrame
	meshPart.Parent = parent
	tile.MeshPart = meshPart
	configureFoamTexture(tile)
	configureSeaSpray(tile)
	configureSplashParticles(tile)

	if readBooleanAttribute(sourcePart, "OceanHideSourcePart", config.HideSourceParts) then
		sourcePart.LocalTransparencyModifier = 1
		tile._HiddenSourcePart = true
	end

	return tile :: OceanTile, nil
end

return OceanTile
