--!strict

export type SurfaceColorMode = "SurfaceAppearance" | "FoamSurfaceAppearance" | "PaintVertices"

export type SurfaceColorConfig = {
	Bake: boolean,
	Mode: SurfaceColorMode,
	WaterColorBack: Color3,
	WaterColorTop: Color3,
	WaterColorGain: number,
	WaterAlphaBack: number,
	WaterAlphaTop: number,
	FoamColor: Color3,
	CrestFoamAlphaBack: number,
	CrestFoamAlphaTop: number,
	CrestFoamAlphaGain: number,
}

export type SurfaceSample = {
	NormalizedHeight: number,
	WaterColor: Color3,
	WaterAlpha: number,
	FoamColor: Color3,
	FoamAlpha: number,
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
	local waterAlphaPosition = math.clamp(depthAlpha or 1, 0, 1)
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
	local heightAlpha = math.clamp(normalizedHeight, 0, 1)
	local foamPosition = crestFoamGradientPosition(heightAlpha, config.CrestFoamAlphaGain)
	local crestFoamAlpha =
		math.clamp(lerpNumber(config.CrestFoamAlphaBack, config.CrestFoamAlphaTop, foamPosition), 0, 1)
	local foamAlpha = math.clamp((math.max(crestFoamAlpha, extraFoamAlpha or 0)), 0, 1)

	return {
		Color = config.FoamColor,
		Alpha = foamAlpha,
	}
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
	WaterVertexAlpha: number,
	FoamColor: Color3,
	CrestFoamAlphaBack: number,
	CrestFoamAlphaTop: number,
	CrestFoamAlphaGain: number,
}): SurfaceColorConfig
	return {
		Bake = options.SurfaceColorBake,
		Mode = options.SurfaceColorMode,
		WaterColorBack = options.WaterColorBack,
		WaterColorTop = options.WaterColorTop,
		WaterColorGain = options.WaterColorGain,
		WaterAlphaBack = 0,
		WaterAlphaTop = options.WaterVertexAlpha,
		FoamColor = options.FoamColor,
		CrestFoamAlphaBack = options.CrestFoamAlphaBack,
		CrestFoamAlphaTop = options.CrestFoamAlphaTop,
		CrestFoamAlphaGain = options.CrestFoamAlphaGain,
	}
end

return WaterSurfaceColor
