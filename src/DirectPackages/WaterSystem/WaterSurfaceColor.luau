--!strict

export type SurfaceColorMode = "SurfaceAppearance" | "FoamSurfaceAppearance" | "PaintVertices"

export type SurfaceColorConfig = {
	Bake: boolean,
	Mode: SurfaceColorMode,
	WaterColorBack: Color3,
	WaterColorTop: Color3,
	WaterColorGain: number,
	WaterAlphaGain: number,
	WaterAlphaBack: number,
	WaterAlphaTop: number,
	FoamColor: Color3,
	CrestFoamAlphaBack: number,
	CrestFoamAlphaTop: number,
	CrestFoamAlphaGain: number,
	WaveFoamAlphaBack: number,
	WaveFoamAlphaTop: number,
	WaveFoamAlphaGain: number,
}

export type SurfaceSample = {
	NormalizedHeight: number,
	WaterColor: Color3,
	WaterAlpha: number,
	FoamColor: Color3,
	FoamAlpha: number,
	CrestFoamAlpha: number,
	WaveFoamAlpha: number,
	ExtraFoamAlpha: number,
	FinalColor: Color3,
	FinalAlpha: number,
}

export type WaterSample = {
	Color: Color3,
	Alpha: number,
}

export type FoamSample = {
	Color: Color3,
	Alpha: number,
}

local WaterSurfaceColor = {}

local DEFAULT_MODE: SurfaceColorMode = "PaintVertices"
local CREST_FOAM_START_HEIGHT = 0.78
local WAVE_FOAM_START_HEIGHT = 0.48
local EPSILON = 1e-6

local VALID_MODES: { [string]: boolean } = {
	SurfaceAppearance = true,
	FoamSurfaceAppearance = true,
	PaintVertices = true,
}

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(lerpNumber(a.R, b.R, t), lerpNumber(a.G, b.G, t), lerpNumber(a.B, b.B, t))
end

local function scaledGradientPosition(normalizedHeight: number, gain: number): number
	return math.clamp(normalizedHeight * math.max(gain, 0), 0, 1)
end

local function crestFoamGradientPosition(normalizedHeight: number, gain: number): number
	local t =
		math.clamp((normalizedHeight - CREST_FOAM_START_HEIGHT) / math.max(1 - CREST_FOAM_START_HEIGHT, EPSILON), 0, 1)
	local topWeighted = t * t * (3 - 2 * t)

	return math.clamp(topWeighted * math.max(gain, 0), 0, 1)
end

local function waveFoamGradientPosition(normalizedHeight: number, gain: number): number
	local t =
		math.clamp((normalizedHeight - WAVE_FOAM_START_HEIGHT) / math.max(1 - WAVE_FOAM_START_HEIGHT, EPSILON), 0, 1)
	local topWeighted = t * t * (3 - 2 * t)

	return math.clamp(topWeighted * math.max(gain, 0), 0, 1)
end

function WaterSurfaceColor.ResolveMode(value: string?): SurfaceColorMode
	if value ~= nil and VALID_MODES[value] == true then
		return value :: SurfaceColorMode
	end

	return DEFAULT_MODE
end

function WaterSurfaceColor.NormalizeHeight(height: number, minHeight: number, maxHeight: number): number
	local range = maxHeight - minHeight

	if math.abs(range) <= EPSILON then
		return 0.5
	end

	return math.clamp((height - minHeight) / range, 0, 1)
end

function WaterSurfaceColor.SampleWater(
	config: SurfaceColorConfig,
	normalizedHeight: number,
	depthAlpha: number?
): WaterSample
	local heightAlpha = math.clamp(normalizedHeight, 0, 1)
	local waterPosition = scaledGradientPosition(heightAlpha, config.WaterColorGain)
	local waterAlphaPosition = scaledGradientPosition(depthAlpha or 1, config.WaterAlphaGain)

	local waterColor = lerpColor(config.WaterColorBack, config.WaterColorTop, waterPosition)
	local waterAlpha = math.clamp(lerpNumber(config.WaterAlphaBack, config.WaterAlphaTop, waterAlphaPosition), 0, 1)

	return {
		Color = waterColor,
		Alpha = waterAlpha,
	}
end

function WaterSurfaceColor.SampleFoam(
	config: SurfaceColorConfig,
	normalizedHeight: number,
	extraFoamAlpha: number?
): FoamSample
	local crestFoamAlpha, waveFoamAlpha = WaterSurfaceColor.SampleFoamLayers(config, normalizedHeight)
	local foamAlpha = math.clamp((math.max(crestFoamAlpha, waveFoamAlpha, extraFoamAlpha or 0)), 0, 1)

	return {
		Color = config.FoamColor,
		Alpha = foamAlpha,
	}
end

function WaterSurfaceColor.SampleFoamLayers(
	config: SurfaceColorConfig,
	normalizedHeight: number
): (number, number)
	local heightAlpha = math.clamp(normalizedHeight, 0, 1)
	local foamPosition = crestFoamGradientPosition(heightAlpha, config.CrestFoamAlphaGain)
	local crestFoamAlpha =
		math.clamp(lerpNumber(config.CrestFoamAlphaBack, config.CrestFoamAlphaTop, foamPosition), 0, 1)
	local waveFoamPosition = waveFoamGradientPosition(heightAlpha, config.WaveFoamAlphaGain)
	local waveFoamAlpha =
		math.clamp(lerpNumber(config.WaveFoamAlphaBack, config.WaveFoamAlphaTop, waveFoamPosition), 0, 1)

	return crestFoamAlpha, waveFoamAlpha
end

function WaterSurfaceColor.Sample(
	config: SurfaceColorConfig,
	normalizedHeight: number,
	extraFoamAlpha: number?,
	depthAlpha: number?
): SurfaceSample
	local heightAlpha = math.clamp(normalizedHeight, 0, 1)
	local water = WaterSurfaceColor.SampleWater(config, heightAlpha, depthAlpha)
	local foam = WaterSurfaceColor.SampleFoam(config, heightAlpha, extraFoamAlpha)
	local crestFoamAlpha, waveFoamAlpha = WaterSurfaceColor.SampleFoamLayers(config, heightAlpha)
	local waterColor = water.Color
	local waterAlpha = water.Alpha
	local foamAlpha = foam.Alpha
	local finalColor = lerpColor(waterColor, config.FoamColor, foamAlpha)
	local finalAlpha = math.clamp(waterAlpha + (1 - waterAlpha) * foamAlpha, 0, 1)

	return {
		NormalizedHeight = heightAlpha,
		WaterColor = waterColor,
		WaterAlpha = waterAlpha,
		FoamColor = config.FoamColor,
		FoamAlpha = foamAlpha,
		CrestFoamAlpha = crestFoamAlpha,
		WaveFoamAlpha = waveFoamAlpha,
		ExtraFoamAlpha = math.clamp(extraFoamAlpha or 0, 0, 1),
		FinalColor = finalColor,
		FinalAlpha = finalAlpha,
	}
end

function WaterSurfaceColor.BuildConfig(options: {
	SurfaceColorBake: boolean,
	SurfaceColorMode: SurfaceColorMode,
	WaterColorBack: Color3,
	WaterColorTop: Color3,
	WaterColorGain: number,
	WaterAlphaGain: number,
	WaterVertexAlpha: number,
	FoamColor: Color3,
	CrestFoamAlphaBack: number,
	CrestFoamAlphaTop: number,
	CrestFoamAlphaGain: number,
	WaveFoamAlphaBack: number,
	WaveFoamAlphaTop: number,
	WaveFoamAlphaGain: number,
}): SurfaceColorConfig
	return {
		Bake = options.SurfaceColorBake,
		Mode = options.SurfaceColorMode,
		WaterColorBack = options.WaterColorBack,
		WaterColorTop = options.WaterColorTop,
		WaterColorGain = options.WaterColorGain,
		WaterAlphaGain = options.WaterAlphaGain,
		WaterAlphaBack = 0,
		WaterAlphaTop = options.WaterVertexAlpha,
		FoamColor = options.FoamColor,
		CrestFoamAlphaBack = options.CrestFoamAlphaBack,
		CrestFoamAlphaTop = options.CrestFoamAlphaTop,
		CrestFoamAlphaGain = options.CrestFoamAlphaGain,
		WaveFoamAlphaBack = options.WaveFoamAlphaBack,
		WaveFoamAlphaTop = options.WaveFoamAlphaTop,
		WaveFoamAlphaGain = options.WaveFoamAlphaGain,
	}
end

return WaterSurfaceColor
