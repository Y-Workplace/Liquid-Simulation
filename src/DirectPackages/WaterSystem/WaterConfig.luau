--!strict

local OceanTile = require(script.Parent.OceanTile)
local WaveSpectrum = require(script.Parent.WaveSpectrum)
local Types = require(script.Parent.Types)
local Defaults = require(script.Parent.Defaults)
local AttributeUtils = require(script.Parent.AttributeUtils)

type WaterSystemOptions = Types.WaterSystemOptions

local DEFAULT_OPTIONS = Defaults.DEFAULT_OPTIONS :: any
local DEFAULT_CASCADES = Defaults.DEFAULT_CASCADES :: any
local readNumberAttribute = AttributeUtils.readNumberAttribute
local readBooleanAttribute = AttributeUtils.readBooleanAttribute
local readColorAttribute = AttributeUtils.readColorAttribute
local readStringAttribute = AttributeUtils.readStringAttribute

local function cascadeAttr(index: number, key: string): string
	return "OceanCascade" .. tostring(index) .. key
end

local function resolveConfig(folder: Instance, options: WaterSystemOptions): OceanTile.TileConfig
	local lod0Radius =
		math.max(readNumberAttribute(folder, "OceanLod0Radius", options.Lod0Radius or DEFAULT_OPTIONS.Lod0Radius), 0)
	local lod1Radius = math.max(
		readNumberAttribute(folder, "OceanLod1Radius", options.Lod1Radius or DEFAULT_OPTIONS.Lod1Radius),
		lod0Radius
	)
	local lod2Radius = math.max(
		readNumberAttribute(folder, "OceanLod2Radius", options.Lod2Radius or DEFAULT_OPTIONS.Lod2Radius),
		lod1Radius
	)
	local lodRecenterDistance = math.max(
		readNumberAttribute(
			folder,
			"OceanLodRecenterDistance",
			options.LodRecenterDistance or DEFAULT_OPTIONS.LodRecenterDistance
		),
		0.5
	)

	return {
		Resolution = math.clamp(
			math.round(readNumberAttribute(folder, "OceanResolution", options.Resolution or DEFAULT_OPTIONS.Resolution)),
			2,
			160
		),
		VertexSpacing = math.max(
			readNumberAttribute(folder, "OceanVertexSpacing", options.VertexSpacing or DEFAULT_OPTIONS.VertexSpacing),
			0.5
		),
		MaxDistance = readNumberAttribute(folder, "OceanMaxDistance", options.MaxDistance or 1024),
		FadeStartDistance = readNumberAttribute(folder, "OceanFadeStartDistance", options.FadeStartDistance or 512),
		PhysicsDistance = math.max(
			readNumberAttribute(
				folder,
				"OceanPhysicsDistance",
				options.PhysicsDistance or DEFAULT_OPTIONS.PhysicsDistance
			),
			0
		),
		FoamDistance = math.max(
			readNumberAttribute(folder, "OceanFoamDistance", options.FoamDistance or DEFAULT_OPTIONS.FoamDistance),
			0
		),
		Lod0Radius = lod0Radius,
		Lod1Radius = lod1Radius,
		Lod2Radius = lod2Radius,
		LodRecenterDistance = lodRecenterDistance,
		VolumeEnabled = readBooleanAttribute(folder, "OceanVolumeEnabled", options.VolumeEnabled ~= false),
		VolumeSideSpacing = math.max(
			readNumberAttribute(
				folder,
				"OceanVolumeSideSpacing",
				options.VolumeSideSpacing or DEFAULT_OPTIONS.VolumeSideSpacing
			),
			1
		),
		VolumeVerticalSegments = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanVolumeVerticalSegments",
					options.VolumeVerticalSegments or DEFAULT_OPTIONS.VolumeVerticalSegments
				)
			),
			1,
			8
		),
		VolumeBottomResolution = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanVolumeBottomResolution",
					options.VolumeBottomResolution or DEFAULT_OPTIONS.VolumeBottomResolution
				)
			),
			1,
			24
		),
		VolumeWaveScale = math.clamp(
			readNumberAttribute(
				folder,
				"OceanVolumeWaveScale",
				options.VolumeWaveScale or DEFAULT_OPTIONS.VolumeWaveScale
			),
			0,
			1
		),
		InteractiveWavesEnabled = readBooleanAttribute(
			folder,
			"OceanInteractiveWavesEnabled",
			options.InteractiveWavesEnabled ~= false
		),
		InteractiveResolution = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanInteractiveResolution",
					options.InteractiveResolution or DEFAULT_OPTIONS.InteractiveResolution
				)
			),
			8,
			256
		),
		InteractiveSimulationIterations = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanInteractiveSimulationIterations",
					options.InteractiveSimulationIterations or DEFAULT_OPTIONS.InteractiveSimulationIterations
				)
			),
			1,
			8
		),
		InteractiveDamping = math.clamp(
			readNumberAttribute(
				folder,
				"OceanInteractiveDamping",
				options.InteractiveDamping or DEFAULT_OPTIONS.InteractiveDamping
			),
			0,
			1
		),
		InteractiveMaxHeight = math.max(
			readNumberAttribute(
				folder,
				"OceanInteractiveMaxHeight",
				options.InteractiveMaxHeight or DEFAULT_OPTIONS.InteractiveMaxHeight
			),
			0.1
		),
		InteractiveMaxVelocity = math.max(
			readNumberAttribute(
				folder,
				"OceanInteractiveMaxVelocity",
				options.InteractiveMaxVelocity or DEFAULT_OPTIONS.InteractiveMaxVelocity
			),
			0.1
		),
		InteractiveMoveSphereScale = math.max(
			readNumberAttribute(
				folder,
				"OceanInteractiveMoveSphereScale",
				options.InteractiveMoveSphereScale or DEFAULT_OPTIONS.InteractiveMoveSphereScale
			),
			0
		),
		InteractiveFoamStrength = math.max(
			readNumberAttribute(
				folder,
				"OceanInteractiveFoamStrength",
				options.InteractiveFoamStrength or DEFAULT_OPTIONS.InteractiveFoamStrength
			),
			0
		),
		InteractiveFoamSlopeThreshold = math.max(
			readNumberAttribute(
				folder,
				"OceanInteractiveFoamSlopeThreshold",
				options.InteractiveFoamSlopeThreshold or DEFAULT_OPTIONS.InteractiveFoamSlopeThreshold
			),
			0.001
		),
		InteractiveFoamVelocityThreshold = math.max(
			readNumberAttribute(
				folder,
				"OceanInteractiveFoamVelocityThreshold",
				options.InteractiveFoamVelocityThreshold or DEFAULT_OPTIONS.InteractiveFoamVelocityThreshold
			),
			0.001
		),
		InteractiveLodDissipation = math.clamp(
			readNumberAttribute(
				folder,
				"OceanInteractiveLodDissipation",
				options.InteractiveLodDissipation or DEFAULT_OPTIONS.InteractiveLodDissipation
			),
			0,
			1
		),
		DepthMapEnabled = readBooleanAttribute(folder, "OceanDepthMapEnabled", options.DepthMapEnabled ~= false),
		DepthMapResolution = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanDepthMapResolution",
					options.DepthMapResolution or DEFAULT_OPTIONS.DepthMapResolution
				)
			),
			2,
			32
		),
		MaxRaycastDepth = math.max(
			readNumberAttribute(
				folder,
				"OceanMaxRaycastDepth",
				options.MaxRaycastDepth or DEFAULT_OPTIONS.MaxRaycastDepth
			),
			1
		),
		FallbackDepth = math.max(
			readNumberAttribute(folder, "OceanFallbackDepth", options.FallbackDepth or DEFAULT_OPTIONS.FallbackDepth),
			0
		),
		ShallowWaveScale = math.clamp(
			readNumberAttribute(
				folder,
				"OceanShallowWaveScale",
				options.ShallowWaveScale or DEFAULT_OPTIONS.ShallowWaveScale
			),
			0,
			2
		),
		DeepWaveScale = math.clamp(
			readNumberAttribute(folder, "OceanDeepWaveScale", options.DeepWaveScale or DEFAULT_OPTIONS.DeepWaveScale),
			0,
			3
		),
		ShoreFoamStrength = math.clamp(
			readNumberAttribute(
				folder,
				"OceanShoreFoamStrength",
				options.ShoreFoamStrength or DEFAULT_OPTIONS.ShoreFoamStrength
			),
			0,
			3
		),
		ObstacleMapEnabled = readBooleanAttribute(
			folder,
			"OceanObstacleMapEnabled",
			options.ObstacleMapEnabled ~= false
		),
		ObstacleRootName = readStringAttribute(
			folder,
			"OceanObstacleRootName",
			options.ObstacleRootName or DEFAULT_OPTIONS.ObstacleRootName
		),
		BakeAnchoredObstacles = readBooleanAttribute(
			folder,
			"OceanBakeAnchoredObstacles",
			options.BakeAnchoredObstacles ~= false
		),
		ObstacleMapResolution = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanObstacleMapResolution",
					options.ObstacleMapResolution or DEFAULT_OPTIONS.ObstacleMapResolution
				)
			),
			2,
			64
		),
		ObstacleInfluenceRadius = math.max(
			readNumberAttribute(
				folder,
				"OceanObstacleInfluenceRadius",
				options.ObstacleInfluenceRadius or DEFAULT_OPTIONS.ObstacleInfluenceRadius
			),
			0
		),
		ObstacleRayHeight = math.max(
			readNumberAttribute(
				folder,
				"OceanObstacleRayHeight",
				options.ObstacleRayHeight or DEFAULT_OPTIONS.ObstacleRayHeight
			),
			0.1
		),
		ObstacleRayDepth = math.max(
			readNumberAttribute(
				folder,
				"OceanObstacleRayDepth",
				options.ObstacleRayDepth or DEFAULT_OPTIONS.ObstacleRayDepth
			),
			0.1
		),
		ObstacleWaveDamping = math.clamp(
			readNumberAttribute(
				folder,
				"OceanObstacleWaveDamping",
				options.ObstacleWaveDamping or DEFAULT_OPTIONS.ObstacleWaveDamping
			),
			0,
			1
		),
		ObstacleFoamStrength = math.clamp(
			readNumberAttribute(
				folder,
				"OceanObstacleFoamStrength",
				options.ObstacleFoamStrength or DEFAULT_OPTIONS.ObstacleFoamStrength
			),
			0,
			3
		),
		FoamBufferEnabled = readBooleanAttribute(folder, "OceanFoamBufferEnabled", options.FoamBufferEnabled ~= false),
		FoamBufferResolution = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanFoamBufferResolution",
					options.FoamBufferResolution or DEFAULT_OPTIONS.FoamBufferResolution
				)
			),
			2,
			62
		),
		FoamBufferDecay = math.max(
			readNumberAttribute(
				folder,
				"OceanFoamBufferDecay",
				options.FoamBufferDecay or DEFAULT_OPTIONS.FoamBufferDecay
			),
			0
		),
		FoamBufferGrowth = math.max(
			readNumberAttribute(
				folder,
				"OceanFoamBufferGrowth",
				options.FoamBufferGrowth or DEFAULT_OPTIONS.FoamBufferGrowth
			),
			0
		),
		CrestFoamStrength = math.clamp(
			readNumberAttribute(
				folder,
				"OceanCrestFoamStrength",
				options.CrestFoamStrength or DEFAULT_OPTIONS.CrestFoamStrength
			),
			0,
			3
		),
		HighWaveFoamThreshold = math.max(
			readNumberAttribute(
				folder,
				"OceanHighWaveFoamThreshold",
				options.HighWaveFoamThreshold or DEFAULT_OPTIONS.HighWaveFoamThreshold
			),
			0.001
		),
		HighWaveFoamStrength = math.clamp(
			readNumberAttribute(
				folder,
				"OceanHighWaveFoamStrength",
				options.HighWaveFoamStrength or DEFAULT_OPTIONS.HighWaveFoamStrength
			),
			0,
			3
		),
		ShallowDepth = math.max(
			readNumberAttribute(folder, "OceanShallowDepth", options.ShallowDepth or DEFAULT_OPTIONS.ShallowDepth),
			0
		),
		LakeDepth = math.max(
			readNumberAttribute(folder, "OceanLakeDepth", options.LakeDepth or DEFAULT_OPTIONS.LakeDepth),
			0.001
		),
		OceanDepth = math.max(
			readNumberAttribute(folder, "OceanOceanDepth", options.OceanDepth or DEFAULT_OPTIONS.OceanDepth),
			0.001
		),
		WaveLoopFrames = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanWaveLoopFrames",
					options.WaveLoopFrames or DEFAULT_OPTIONS.WaveLoopFrames
				)
			),
			2,
			240
		),
		WaveLoopDuration = math.max(
			readNumberAttribute(
				folder,
				"OceanWaveLoopDuration",
				options.WaveLoopDuration or DEFAULT_OPTIONS.WaveLoopDuration
			),
			0.25
		),
		FarWaveDetail = math.clamp(
			readNumberAttribute(folder, "OceanFarWaveDetail", options.FarWaveDetail or DEFAULT_OPTIONS.FarWaveDetail),
			0.05,
			1
		),
		MidLodVertexStep = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanMidLodVertexStep",
					options.MidLodVertexStep or DEFAULT_OPTIONS.MidLodVertexStep
				)
			),
			1,
			16
		),
		FarLodVertexStep = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanFarLodVertexStep",
					options.FarLodVertexStep or DEFAULT_OPTIONS.FarLodVertexStep
				)
			),
			1,
			24
		),
		ExtremeLodVertexStep = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanExtremeLodVertexStep",
					options.ExtremeLodVertexStep or DEFAULT_OPTIONS.ExtremeLodVertexStep
				)
			),
			1,
			32
		),
		StaticObstacleSplashEnabled = readBooleanAttribute(
			folder,
			"OceanStaticObstacleSplashEnabled",
			options.StaticObstacleSplashEnabled ~= false
		),
		StaticObstacleSplashInterval = math.max(
			readNumberAttribute(
				folder,
				"OceanStaticObstacleSplashInterval",
				options.StaticObstacleSplashInterval or DEFAULT_OPTIONS.StaticObstacleSplashInterval
			),
			0.05
		),
		WaterColor = readColorAttribute(folder, "OceanWaterColor", options.WaterColor or DEFAULT_OPTIONS.WaterColor),
		WaterTintColor = readColorAttribute(
			folder,
			"OceanWaterTintColor",
			options.WaterTintColor or DEFAULT_OPTIONS.WaterTintColor
		),
		FoamColor = readColorAttribute(folder, "OceanFoamColor", options.FoamColor or DEFAULT_OPTIONS.FoamColor),
		RuntimeSurfaceColorEnabled = readBooleanAttribute(
			folder,
			"OceanRuntimeSurfaceColorEnabled",
			options.RuntimeSurfaceColorEnabled == true
		),
		WaterVertexAlpha = math.clamp(
			readNumberAttribute(folder, "OceanWaterVertexAlpha", options.WaterVertexAlpha or 0.5),
			0,
			1
		),
		FoamVertexAlpha = math.clamp(
			readNumberAttribute(folder, "OceanFoamVertexAlpha", options.FoamVertexAlpha or 1),
			0,
			1
		),
		FoamVertexBoost = math.max(
			readNumberAttribute(folder, "OceanFoamVertexBoost", options.FoamVertexBoost or 1.35),
			0
		),
		FoamNoiseInfluence = math.clamp(
			readNumberAttribute(folder, "OceanFoamNoiseInfluence", options.FoamNoiseInfluence or 0.72),
			0,
			1
		),
		Transparency = math.clamp(readNumberAttribute(folder, "OceanTransparency", options.Transparency or 0.28), 0, 1),
		Reflectance = math.clamp(readNumberAttribute(folder, "OceanReflectance", options.Reflectance or 0.08), 0, 1),
		HideSourceParts = readBooleanAttribute(folder, "OceanHideSourceParts", options.HideSourceParts ~= false),
		FoamColorUpdateInterval = math.max(readNumberAttribute(folder, "OceanFoamColorUpdateInterval", 0.12), 0),
		FoamTextureId = readStringAttribute(folder, "OceanFoamTextureId", options.FoamTextureId or ""),
		FoamTextureTransparency = math.clamp(
			readNumberAttribute(
				folder,
				"OceanFoamTextureTransparency",
				options.FoamTextureTransparency or DEFAULT_OPTIONS.FoamTextureTransparency
			),
			0,
			1
		),
		FoamTextureStudsPerTile = math.max(
			readNumberAttribute(
				folder,
				"OceanFoamTextureStudsPerTile",
				options.FoamTextureStudsPerTile or DEFAULT_OPTIONS.FoamTextureStudsPerTile
			),
			0.1
		),
		FoamTextureFromVerticesEnabled = readBooleanAttribute(
			folder,
			"OceanFoamTextureFromVerticesEnabled",
			options.FoamTextureFromVerticesEnabled ~= false
		),
		FoamTextureUpdateInterval = math.max(
			readNumberAttribute(
				folder,
				"OceanFoamTextureUpdateInterval",
				options.FoamTextureUpdateInterval or DEFAULT_OPTIONS.FoamTextureUpdateInterval
			),
			0
		),
		FoamTextureResolution = math.clamp(
			math.round(
				readNumberAttribute(
					folder,
					"OceanFoamTextureResolution",
					options.FoamTextureResolution or DEFAULT_OPTIONS.FoamTextureResolution
				)
			),
			16,
			1024
		),
		FoamNoiseSize = math.clamp(
			math.round(
				readNumberAttribute(folder, "OceanFoamNoiseSize", options.FoamNoiseSize or DEFAULT_OPTIONS.FoamNoiseSize)
			),
			16,
			512
		),
		FoamNoiseSeed = math.round(
			readNumberAttribute(folder, "OceanFoamNoiseSeed", options.FoamNoiseSeed or DEFAULT_OPTIONS.FoamNoiseSeed)
		),
		SeaSprayEnabled = readBooleanAttribute(folder, "OceanEnableSeaSpray", true),
		SeaSprayTextureId = readStringAttribute(folder, "OceanSeaSprayTextureId", options.SeaSprayTextureId or ""),
		SeaSprayRate = math.max(readNumberAttribute(folder, "OceanSeaSprayRate", 90), 0),
		SplashParticlesEnabled = readBooleanAttribute(
			folder,
			"OceanSplashParticlesEnabled",
			options.SplashParticlesEnabled ~= false
		),
		SplashParticleTextureId = readStringAttribute(
			folder,
			"OceanSplashParticleTextureId",
			options.SplashParticleTextureId or ""
		),
		SplashParticleMinSpeed = math.max(
			readNumberAttribute(
				folder,
				"OceanSplashParticleMinSpeed",
				options.SplashParticleMinSpeed or DEFAULT_OPTIONS.SplashParticleMinSpeed
			),
			0
		),
		SplashParticleMaxSpeed = math.max(
			readNumberAttribute(
				folder,
				"OceanSplashParticleMaxSpeed",
				options.SplashParticleMaxSpeed or DEFAULT_OPTIONS.SplashParticleMaxSpeed
			),
			0
		),
		SplashParticleEmitScale = math.max(
			readNumberAttribute(
				folder,
				"OceanSplashParticleEmitScale",
				options.SplashParticleEmitScale or DEFAULT_OPTIONS.SplashParticleEmitScale
			),
			0
		),
	}
end

local function cascadeNumber(folder: Instance, index: number, key: string, fallback: number): number
	local cascadeValue = readNumberAttribute(folder, cascadeAttr(index, key), fallback)

	if cascadeValue ~= fallback then
		return cascadeValue
	end

	local oceanValue = readNumberAttribute(folder, "Ocean" .. key, fallback)

	if oceanValue ~= fallback then
		return oceanValue
	end

	if key == "WindSpeed" then
		return readNumberAttribute(folder, "WaveSpeed", fallback)
	elseif key == "WindDirection" then
		return readNumberAttribute(folder, "WaveDirection", fallback)
	elseif key == "DisplacementScale" then
		return readNumberAttribute(folder, "WaveHeight", fallback)
	elseif key == "FoamAmount" then
		return readNumberAttribute(folder, "FoamStrength", fallback)
	end

	return fallback
end

local function resolveCascades(folder: Instance): { WaveSpectrum.CascadeConfig }
	local cascades = table.create(#DEFAULT_CASCADES)

	for index, source in ipairs(DEFAULT_CASCADES) do
		table.insert(cascades, {
			TileLength = Vector2.new(
				cascadeNumber(folder, index, "TileLengthX", source.TileLength.X),
				cascadeNumber(folder, index, "TileLengthY", source.TileLength.Y)
			),
			DisplacementScale = cascadeNumber(folder, index, "DisplacementScale", source.DisplacementScale),
			NormalScale = cascadeNumber(folder, index, "NormalScale", source.NormalScale),
			WindSpeed = cascadeNumber(folder, index, "WindSpeed", source.WindSpeed),
			WindDirection = cascadeNumber(folder, index, "WindDirection", source.WindDirection),
			FetchLength = cascadeNumber(folder, index, "FetchLength", source.FetchLength),
			Swell = math.clamp(cascadeNumber(folder, index, "Swell", source.Swell), 0, 2),
			Spread = math.clamp(cascadeNumber(folder, index, "Spread", source.Spread), 0, 1),
			Detail = math.clamp(cascadeNumber(folder, index, "Detail", source.Detail), 0, 1),
			Whitecap = math.clamp(cascadeNumber(folder, index, "Whitecap", source.Whitecap), 0, 2),
			FoamAmount = math.clamp(cascadeNumber(folder, index, "FoamAmount", source.FoamAmount), 0, 10),
		})
	end

	return cascades
end

local function resolveSpectrumOptions(folder: Instance, options: WaterSystemOptions): WaveSpectrum.SpectrumOptions
	local heightFallback = options.HeightScale or DEFAULT_OPTIONS.HeightScale
	local timeFallback = options.TimeScale or DEFAULT_OPTIONS.TimeScale

	return {
		ComponentCount = math.max(
			math.round(
				readNumberAttribute(
					folder,
					"OceanComponentCount",
					options.ComponentCount or DEFAULT_OPTIONS.ComponentCount
				)
			),
			1
		),
		HeightScale = readNumberAttribute(
			folder,
			"OceanHeightScale",
			readNumberAttribute(folder, "WaveScale", readNumberAttribute(folder, "WaveHeight", heightFallback))
		),
		Choppiness = readNumberAttribute(folder, "OceanChoppiness", options.Choppiness or DEFAULT_OPTIONS.Choppiness),
		TimeScale = readNumberAttribute(
			folder,
			"OceanTimeScale",
			readNumberAttribute(folder, "WaveSpeed", timeFallback)
		),
		Seed = math.round(readNumberAttribute(folder, "OceanSeed", options.Seed or DEFAULT_OPTIONS.Seed)),
	}
end

return {
	resolveConfig = resolveConfig,
	resolveCascades = resolveCascades,
	resolveSpectrumOptions = resolveSpectrumOptions,
}
