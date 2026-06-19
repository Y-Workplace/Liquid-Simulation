--!strict

local Types = require(script.Parent.Types)

type WaterSystemOptions = Types.WaterSystemOptions

local Defaults = {}

local CONTEXT_OPTION_KEYS: { [string]: { [string]: string } } = {
	Source = {
		FolderName = "SourceFolderName",
		GeneratedFolderName = "GeneratedFolderName",
		HideParts = "HideSourceParts",
		RuntimePanel = "RuntimePanel",
	},
	Mesh = {
		Resolution = "Resolution",
		VertexSpacing = "VertexSpacing",
	},
	Streaming = {
		UpdatesPerSecond = "UpdatesPerSecond",
		MaxDistance = "MaxDistance",
		FadeStartDistance = "FadeStartDistance",
		LoadDistance = "LoadDistance",
		UnloadDistance = "UnloadDistance",
		LodScanInterval = "LodScanInterval",
		NearUpdateDistance = "NearUpdateDistance",
		MidUpdateDistance = "MidUpdateDistance",
		NearUpdatesPerSecond = "NearUpdatesPerSecond",
		MidUpdatesPerSecond = "MidUpdatesPerSecond",
		FarUpdatesPerSecond = "FarUpdatesPerSecond",
	},
	Spatial = {
		PhysicsDistance = "PhysicsDistance",
		FoamDistance = "FoamDistance",
	},
	Lod = {
		Lod0Radius = "Lod0Radius",
		Lod1Radius = "Lod1Radius",
		Lod2Radius = "Lod2Radius",
		LodRecenterDistance = "LodRecenterDistance",
		FarWaveDetail = "FarWaveDetail",
		MidVertexStep = "MidLodVertexStep",
		FarVertexStep = "FarLodVertexStep",
		ExtremeVertexStep = "ExtremeLodVertexStep",
	},
	Volume = {
		Enabled = "VolumeEnabled",
		SideSpacing = "VolumeSideSpacing",
		VerticalSegments = "VolumeVerticalSegments",
		BottomResolution = "VolumeBottomResolution",
		WaveScale = "VolumeWaveScale",
		MinDepth = "VolumeMinDepth",
	},
	ChunkLod = {
		Enabled = "ChunkLodEnabled",
		Lod0Distance = "ChunkLod0Distance",
		Lod1Distance = "ChunkLod1Distance",
		Lod2Distance = "ChunkLod2Distance",
		Hysteresis = "ChunkLodHysteresis",
		SwitchCooldown = "ChunkLodSwitchCooldown",
		Lod0Resolution = "ChunkLod0Resolution",
		Lod1Resolution = "ChunkLod1Resolution",
		Lod2Resolution = "ChunkLod2Resolution",
		Lod3Resolution = "ChunkLod3Resolution",
	},
	ViewCulling = {
		Enabled = "ViewCullingEnabled",
		Padding = "ViewCullingPadding",
	},
	Interactive = {
		WavesEnabled = "InteractiveWavesEnabled",
		Resolution = "InteractiveResolution",
		SimulationIterations = "InteractiveSimulationIterations",
		Damping = "InteractiveDamping",
		MaxHeight = "InteractiveMaxHeight",
		MaxVelocity = "InteractiveMaxVelocity",
		MoveSphereScale = "InteractiveMoveSphereScale",
		FoamStrength = "InteractiveFoamStrength",
		FoamSlopeThreshold = "InteractiveFoamSlopeThreshold",
		FoamVelocityThreshold = "InteractiveFoamVelocityThreshold",
		LodDissipation = "InteractiveLodDissipation",
	},
	Depth = {
		MapEnabled = "DepthMapEnabled",
		MapResolution = "DepthMapResolution",
		MaxRaycastDepth = "MaxRaycastDepth",
		FallbackDepth = "FallbackDepth",
		ShallowDepth = "ShallowDepth",
		LakeDepth = "LakeDepth",
		OceanDepth = "OceanDepth",
	},
	Waves = {
		ComponentCount = "ComponentCount",
		ShallowScale = "ShallowWaveScale",
		DeepScale = "DeepWaveScale",
		BeachCurl = "BeachWaveCurl",
		LoopFrames = "WaveLoopFrames",
		LoopDuration = "WaveLoopDuration",
		HeightScale = "HeightScale",
		Choppiness = "Choppiness",
		TimeScale = "TimeScale",
		Seed = "Seed",
	},
	Obstacle = {
		MapEnabled = "ObstacleMapEnabled",
		RootName = "ObstacleRootName",
		BakeAnchored = "BakeAnchoredObstacles",
		MapResolution = "ObstacleMapResolution",
		InfluenceRadius = "ObstacleInfluenceRadius",
		RayHeight = "ObstacleRayHeight",
		RayDepth = "ObstacleRayDepth",
		WaveDamping = "ObstacleWaveDamping",
		FoamStrength = "ObstacleFoamStrength",
		StaticSplashEnabled = "StaticObstacleSplashEnabled",
		StaticSplashInterval = "StaticObstacleSplashInterval",
	},
	Foam = {
		Color = "FoamColor",
		ShoreStrength = "ShoreFoamStrength",
		BufferEnabled = "FoamBufferEnabled",
		BufferResolution = "FoamBufferResolution",
		BufferDecay = "FoamBufferDecay",
		BufferGrowth = "FoamBufferGrowth",
		CrestAlphaBack = "CrestFoamAlphaBack",
		CrestAlphaTop = "CrestFoamAlphaTop",
		CrestAlphaGain = "CrestFoamAlphaGain",
		WaveAlphaBack = "WaveFoamAlphaBack",
		WaveAlphaTop = "WaveFoamAlphaTop",
		WaveAlphaGain = "WaveFoamAlphaGain",
		TrailStrength = "FoamTrailStrength",
		TrailLength = "FoamTrailLength",
		TrailFeather = "FoamTrailFeather",
		TextureId = "FoamTextureId",
		TextureTransparency = "FoamTextureTransparency",
		TextureStudsPerTile = "FoamTextureStudsPerTile",
		TextureFromVerticesEnabled = "FoamTextureFromVerticesEnabled",
		TextureUpdateInterval = "FoamTextureUpdateInterval",
		TextureResolution = "FoamTextureResolution",
		NoiseSize = "FoamNoiseSize",
		NoiseSeed = "FoamNoiseSeed",
		VertexAlpha = "FoamVertexAlpha",
		VertexBoost = "FoamVertexBoost",
		NoiseInfluence = "FoamNoiseInfluence",
	},
	Surface = {
		WaterColor = "WaterColor",
		WaterTintColor = "WaterTintColor",
		WaterColorBack = "WaterColorBack",
		WaterColorTop = "WaterColorTop",
		WaterColorGain = "WaterColorGain",
		WaterAlphaGain = "WaterAlphaGain",
		ColorBake = "SurfaceColorBake",
		ColorMode = "SurfaceColorMode",
		RuntimeColorEnabled = "RuntimeSurfaceColorEnabled",
		OceanRuntimeColorEnabled = "OceanRuntimeSurfaceColorEnabled",
		WaterVertexAlpha = "WaterVertexAlpha",
		NormalEnabled = "WaterNormalEnabled",
		NormalResolution = "WaterNormalResolution",
		NormalStrength = "WaterNormalStrength",
		NormalScale = "WaterNormalScale",
		NormalSpeed = "WaterNormalSpeed",
		NormalUpdateInterval = "WaterNormalUpdateInterval",
		WaterNormalEnabled = "WaterNormalEnabled",
		WaterNormalResolution = "WaterNormalResolution",
		WaterNormalStrength = "WaterNormalStrength",
		WaterNormalScale = "WaterNormalScale",
		WaterNormalSpeed = "WaterNormalSpeed",
		WaterNormalUpdateInterval = "WaterNormalUpdateInterval",
		FresnelEnabled = "FresnelEnabled",
		FresnelStrength = "FresnelStrength",
		FresnelPower = "FresnelPower",
		Transparency = "Transparency",
		Reflectance = "Reflectance",
	},
	Caustics = {
		Enabled = "CausticsEnabled",
		Color = "CausticsColor",
		Strength = "CausticsStrength",
		ShallowStrength = "ShallowCausticsStrength",
		DeepStrength = "DeepCausticsStrength",
		Scale = "CausticsScale",
		Speed = "CausticsSpeed",
		DepthFade = "CausticsDepthFade",
		VoronoiStrength = "CausticsVoronoiStrength",
	},
	Particles = {
		SeaSprayTextureId = "SeaSprayTextureId",
		SplashEnabled = "SplashParticlesEnabled",
		SplashTextureId = "SplashParticleTextureId",
		SplashMinSpeed = "SplashParticleMinSpeed",
		SplashMaxSpeed = "SplashParticleMaxSpeed",
		SplashEmitScale = "SplashParticleEmitScale",
	},
	Physics = {
		PhysicalInteractionEnabled = "PhysicalInteractionEnabled",
		PhysicalScanInterval = "PhysicalScanInterval",
		PhysicalMaxTrackedParts = "PhysicalMaxTrackedParts",
		PhysicalMinSpeed = "PhysicalMinSpeed",
		PhysicalImpactSpeed = "PhysicalImpactSpeed",
		PhysicalRadiusScale = "PhysicalRadiusScale",
		BuoyancyEnabled = "BuoyancyEnabled",
		BuoyancyStrength = "BuoyancyStrength",
		BuoyancyDamping = "BuoyancyDamping",
		BuoyancyLinearDrag = "BuoyancyLinearDrag",
		BuoyancyAngularDrag = "BuoyancyAngularDrag",
		BuoyancyScanInterval = "BuoyancyScanInterval",
		BuoyancyMaxParts = "BuoyancyMaxParts",
	},
	Player = {
		InteractionEnabled = "PlayerInteractionEnabled",
		SurfaceFloatEnabled = "PlayerSurfaceFloatEnabled",
		SurfaceInfluenceDepth = "PlayerSurfaceInfluenceDepth",
		SurfaceSmoothness = "PlayerSurfaceSmoothness",
		SurfaceOffset = "PlayerSurfaceOffset",
		SurfaceMaxVerticalSpeed = "PlayerSurfaceMaxVerticalSpeed",
		SwimAnimationEnabled = "PlayerSwimAnimationEnabled",
		SwimMovementThreshold = "PlayerSwimMovementThreshold",
		SwimDepth = "PlayerSwimDepth",
	},
	Underwater = {
		EffectsEnabled = "UnderwaterEffectsEnabled",
		DepthStart = "UnderwaterDepthStart",
		DepthFull = "UnderwaterDepthFull",
		DepthOfFieldEnabled = "UnderwaterDepthOfFieldEnabled",
		DepthOfFieldFocusDistance = "UnderwaterDepthOfFieldFocusDistance",
		DepthOfFieldInFocusRadius = "UnderwaterDepthOfFieldInFocusRadius",
		DepthOfFieldNearIntensity = "UnderwaterDepthOfFieldNearIntensity",
		DepthOfFieldFarIntensity = "UnderwaterDepthOfFieldFarIntensity",
	},
	Camera = {
		DropsEnabled = "CameraDropsEnabled",
		DropCount = "CameraDropCount",
		DropDuration = "CameraDropDuration",
	},
}

Defaults.CONTEXT_OPTION_KEYS = CONTEXT_OPTION_KEYS

Defaults.DEFAULT_CONFIG = {
	Source = {
		FolderName = "Water",
		GeneratedFolderName = "GeneratedOcean",
		HideParts = true,
		RuntimePanel = false,
	},
	Mesh = {
		Resolution = 512,
		VertexSpacing = 1,
	},
	Streaming = {
		UpdatesPerSecond = 30,
		MaxDistance = 1024,
		FadeStartDistance = 512,
		LoadDistance = 1024,
		UnloadDistance = 1152,
		LodScanInterval = 0.35,
		NearUpdateDistance = 256,
		MidUpdateDistance = 512,
		NearUpdatesPerSecond = 30,
		MidUpdatesPerSecond = 8,
		FarUpdatesPerSecond = 2,
	},
	Spatial = {
		PhysicsDistance = 220,
		FoamDistance = 220,
	},
	Lod = {
		Lod0Radius = 220,
		Lod1Radius = 512,
		Lod2Radius = 1024,
		LodRecenterDistance = 64,
		FarWaveDetail = 0.42,
		MidVertexStep = 2,
		FarVertexStep = 4,
		ExtremeVertexStep = 8,
	},
	Volume = {
		Enabled = true,
		SideSpacing = 36,
		VerticalSegments = 3,
		BottomResolution = 6,
		WaveScale = 0.18,
		MinDepth = 3.5,
	},
	ChunkLod = {
		Enabled = true,
		Lod0Distance = 100,
		Lod1Distance = 300,
		Lod2Distance = 600,
		Hysteresis = 64,
		SwitchCooldown = 0.85,
		Lod0Resolution = 96,
		Lod1Resolution = 64,
		Lod2Resolution = 32,
		Lod3Resolution = 16,
	},
	ViewCulling = {
		Enabled = true,
		Padding = 96,
	},
	Interactive = {
		WavesEnabled = true,
		Resolution = 64,
		SimulationIterations = 1,
		Damping = 0.995,
		MaxHeight = 5,
		MaxVelocity = 8,
		MoveSphereScale = 0.18,
		FoamStrength = 0.85,
		FoamSlopeThreshold = 0.16,
		FoamVelocityThreshold = 0.18,
		LodDissipation = 0.82,
	},
	Depth = {
		MapEnabled = true,
		MapResolution = 12,
		MaxRaycastDepth = 180,
		FallbackDepth = 180,
		ShallowDepth = 10,
		LakeDepth = 42,
		OceanDepth = 96,
	},
	Waves = {
		ComponentCount = 14,
		ShallowScale = 0.12,
		DeepScale = 1.08,
		BeachCurl = 0.78,
		LoopFrames = 48,
		LoopDuration = 18,
		HeightScale = 1.15,
		Choppiness = 1,
		TimeScale = 1,
		Seed = 1234,
	},
	Obstacle = {
		MapEnabled = true,
		RootName = "WaterObstacles",
		BakeAnchored = true,
		MapResolution = 18,
		InfluenceRadius = 14,
		RayHeight = 16,
		RayDepth = 54,
		WaveDamping = 0.65,
		FoamStrength = 0.9,
		StaticSplashEnabled = true,
		StaticSplashInterval = 0.45,
	},
	Foam = {
		Color = Color3.fromRGB(238, 236, 222),
		ShoreStrength = 1.32,
		BufferEnabled = true,
		BufferResolution = 48,
		BufferDecay = 0.72,
		BufferGrowth = 7.5,
		CrestAlphaBack = 0,
		CrestAlphaTop = 1,
		CrestAlphaGain = 1,
		WaveAlphaBack = 0,
		WaveAlphaTop = 0.42,
		WaveAlphaGain = 0.78,
		TrailStrength = 0.94,
		TrailLength = 3.65,
		TrailFeather = 0.72,
		TextureId = "",
		TextureTransparency = 0,
		TextureStudsPerTile = 14,
		TextureFromVerticesEnabled = false,
		TextureUpdateInterval = 0.08,
		TextureResolution = 64,
		NoiseSize = 128,
		NoiseSeed = 1234,
		VertexAlpha = 1,
		VertexBoost = 1.35,
		NoiseInfluence = 0.46,
	},
	Surface = {
		WaterColorBack = Color3.fromRGB(29, 41, 54),
		WaterColorTop = Color3.fromRGB(31, 143, 128),
		WaterColorGain = 0.75,
		WaterAlphaGain = 30,
		ColorBake = true,
		ColorMode = "PaintVertices", -- PaintVertices, FoamSurfaceAppearance, SurfaceAppearance
		RuntimeColorEnabled = false,
		OceanRuntimeColorEnabled = false,
		WaterVertexAlpha = 0.75,
		WaterNormalEnabled = true,
		WaterNormalResolution = 64,
		WaterNormalStrength = 0.42,
		WaterNormalScale = 34,
		WaterNormalSpeed = 0.38,
		WaterNormalUpdateInterval = 0.05,
		FresnelEnabled = false,
		FresnelStrength = 0.5,
		FresnelPower = 1.35,
		Transparency = 0.02,
		Reflectance = 0,
	},
	Caustics = {
		Enabled = true,
		Color = Color3.fromRGB(255, 255, 255),
		Strength = 0.32,
		ShallowStrength = 1,
		DeepStrength = 0.03,
		Scale = 18,
		Speed = 0.42,
		DepthFade = 0.42,
		VoronoiStrength = 0.18,
	},
	Particles = {
		SeaSprayTextureId = "126577857814450",
		SplashEnabled = true,
		SplashTextureId = "126577857814450",
		SplashMinSpeed = 5,
		SplashMaxSpeed = 18,
		SplashEmitScale = 1,
	},
	Physics = {
		PhysicalInteractionEnabled = true,
		PhysicalScanInterval = 0.08,
		PhysicalMaxTrackedParts = 80,
		PhysicalMinSpeed = 0.75,
		PhysicalImpactSpeed = 8,
		PhysicalRadiusScale = 0.55,
		BuoyancyEnabled = true,
		BuoyancyStrength = 22,
		BuoyancyDamping = 6,
		BuoyancyLinearDrag = 1.15,
		BuoyancyAngularDrag = 0.9,
		BuoyancyScanInterval = 0.1,
		BuoyancyMaxParts = 96,
	},
	Player = {
		InteractionEnabled = true,
		SurfaceFloatEnabled = true,
		SurfaceInfluenceDepth = 3.5,
		SurfaceSmoothness = 10,
		SurfaceOffset = -0.35,
		SurfaceMaxVerticalSpeed = 18,
		SwimAnimationEnabled = true,
		SwimMovementThreshold = 0.12,
		SwimDepth = 2.8,
	},
	Underwater = {
		EffectsEnabled = true,
		DepthStart = 0.25,
		DepthFull = 18,
		DepthOfFieldEnabled = true,
		DepthOfFieldFocusDistance = 0,
		DepthOfFieldInFocusRadius = 25,
		DepthOfFieldNearIntensity = 0,
		DepthOfFieldFarIntensity = 0.75,
	},
	Camera = {
		DropsEnabled = true,
		DropCount = 14,
		DropDuration = 1.4,
	},
}

function Defaults.flattenConfig(config: { [string]: any }): { [string]: any }
	local result = {}

	for contextName, context in pairs(config) do
		local keys = CONTEXT_OPTION_KEYS[contextName]

		if type(context) == "table" and keys ~= nil then
			for contextKey, value in pairs(context) do
				local flatKey = keys[contextKey] or contextKey

				result[flatKey] = value
			end
		else
			result[contextName] = context
		end
	end

	return result
end

Defaults.DEFAULT_OPTIONS = Defaults.flattenConfig(Defaults.DEFAULT_CONFIG)

Defaults.DEFAULT_CASCADES = {
	{
		TileLength = Vector2.new(200, 200),
		DisplacementScale = 2,
		NormalScale = 2,
		WindSpeed = 40,
		WindDirection = 0,
		FetchLength = 800,
		Swell = 0.95,
		Spread = 0.18,
		Detail = 1,
		Whitecap = 0.55,
		FoamAmount = 6,
	},
	{
		TileLength = Vector2.new(80, 80),
		DisplacementScale = 1,
		NormalScale = 1,
		WindSpeed = 20,
		WindDirection = 12,
		FetchLength = 360,
		Swell = 0.7,
		Spread = 0.28,
		Detail = 0.92,
		Whitecap = 0.45,
		FoamAmount = 4,
	},
	{
		TileLength = Vector2.new(52, 52),
		DisplacementScale = 1,
		NormalScale = 1,
		WindSpeed = 20,
		WindDirection = -18,
		FetchLength = 550,
		Swell = 0.8,
		Spread = 0.2,
		Detail = 1,
		Whitecap = 0.5,
		FoamAmount = 5,
	},
}

function Defaults.cloneOptions(options: WaterSystemOptions?): WaterSystemOptions
	local result = {}

	for key, value in pairs(Defaults.DEFAULT_OPTIONS :: any) do
		(result :: any)[key] = value
	end

	if options ~= nil then
		for key, value in pairs(options :: any) do
			local contextKeys = CONTEXT_OPTION_KEYS[key]

			if type(value) == "table" and contextKeys ~= nil then
				for contextKey, contextValue in pairs(value) do
					local flatKey = contextKeys[contextKey] or contextKey

					result[flatKey] = contextValue
				end
			else
				result[key] = value
			end
		end
	end

	return result :: WaterSystemOptions
end

return Defaults
