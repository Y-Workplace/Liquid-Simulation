local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)
local MaterialAnimation = require(script.Parent.Parent.MaterialAnimation)

export type Options = AnimationProjection.Options & {
	Width: number?,
	Height: number?,
	TargetFPS: number?,
	ShineInterval: number?,
	BakedFrameCount: number?,
	ShineBandWidth: number?,
	ShinePeak: number?,
	ShineAngleDeg: number?,
	ShineFadeIn: number?,
	ShineFadeOut: number?,
	ShineColor: Color3?,
	ShineBackgroundColor: Color3?,
	ShineBackgroundAlpha: number?,
	ShineEmissiveStrength: number?,
}

local DEFAULT_WIDTH = 64
local DEFAULT_HEIGHT = 64
local DEFAULT_TARGET_FPS = 15
local DEFAULT_SHINE_INTERVAL = 3.5

local function option(options, key: string)
	return if options ~= nil then options[key] else nil
end

local function sharedKey(prefix: string, values: { any }): string
	local parts = { prefix }
	for _, value in ipairs(values) do
		table.insert(parts, tostring(value))
	end

	return table.concat(parts, ":")
end

local ShineAnimation = {}

function ShineAnimation.new(options: Options?): MaterialAnimation.MaterialAnimation
	local width = option(options, "Width") or DEFAULT_WIDTH
	local height = option(options, "Height") or DEFAULT_HEIGHT
	local targetFPS = option(options, "TargetFPS") or DEFAULT_TARGET_FPS
	local shineInterval = option(options, "ShineInterval") or DEFAULT_SHINE_INTERVAL
	local bakedFrameCount = option(options, "BakedFrameCount") or math.max(2, math.round(shineInterval * targetFPS))
	local projectionMode = AnimationProjection.Resolve(options)
	local shineColor = option(options, "ShineColor") or Color3.fromRGB(255, 255, 255)
	local shineBandWidth = option(options, "ShineBandWidth") or 0.18
	local shinePeak = option(options, "ShinePeak") or 1.0
	local shineAngleDeg = option(options, "ShineAngleDeg") or 30
	local shineFadeIn = option(options, "ShineFadeIn") or 0.18
	local shineFadeOut = option(options, "ShineFadeOut") or 0.22

	return MaterialAnimation.new({
		Width = width,
		Height = height,
		TargetFPS = targetFPS,
		BakedFrameCount = bakedFrameCount,
		Projection = option(options, "Projection"),
		SphericalNormalization = option(options, "SphericalNormalization"),
		Channels = { "ColorMap", "EmissiveMask" },
		Workspace = {
			Values = {
				ShineColor = shineColor,
				BackgroundColor = option(options, "ShineBackgroundColor") or Color3.fromRGB(255, 160, 70),
			},
			Bakes = {
				Shine = {
					Bake = true,
					SharedKey = sharedKey("ShineBand", {
						width,
						height,
						bakedFrameCount,
						projectionMode,
						shineBandWidth,
						shinePeak,
						shineAngleDeg,
						shineFadeIn,
						shineFadeOut,
					}),
					Outputs = {
						shine = "shine",
					},
					Nodes = {
						{
							Type = "ShineBand",
							Parameters = {
								ShineBandWidth = shineBandWidth,
								ShinePeak = shinePeak,
								ShineAngleDeg = shineAngleDeg,
								ShineFadeIn = shineFadeIn,
								ShineFadeOut = shineFadeOut,
							},
						},
					},
				},
			},
		},
		Nodes = {
			{
				Type = "ShineMaterial",
				Parameters = {
					BackgroundColorKey = "BackgroundColor",
					ShineBackgroundAlpha = option(options, "ShineBackgroundAlpha"),
				},
			},
		},
		SurfaceAppearance = {
			AlphaMode = Enum.AlphaMode.Transparency,
			EmissiveStrength = option(options, "ShineEmissiveStrength") or 4.0,
			EmissiveTint = shineColor,
		},
	})
end

return ShineAnimation
