local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)
local MaterialAnimation = require(script.Parent.Parent.MaterialAnimation)

export type Options = AnimationProjection.Options & {
	Width: number?,
	Height: number?,
	TargetFPS: number?,
	LoopDuration: number?,
	BakedFrameCount: number?,
	Color: Color3?,
	Strength: number?,
	EmissiveStrength: number?,
	ShineLineWidth: number?,
	ShineLineFrequency: number?,
	ShineLineStrength: number?,
	StripeSpeed: number?,
	StripeWaviness: number?,
	StripeBreakup: number?,
}

local DEFAULT_WIDTH = 128
local DEFAULT_HEIGHT = 128
local DEFAULT_TARGET_FPS = 15
local DEFAULT_LOOP_DURATION = 12

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

local TriangularForceFieldAnimation = {}

function TriangularForceFieldAnimation.new(options: Options?): MaterialAnimation.MaterialAnimation
	local width = option(options, "Width") or DEFAULT_WIDTH
	local height = option(options, "Height") or DEFAULT_HEIGHT
	local targetFPS = option(options, "TargetFPS") or DEFAULT_TARGET_FPS
	local loopDuration = option(options, "LoopDuration") or DEFAULT_LOOP_DURATION
	local bakedFrameCount = option(options, "BakedFrameCount") or math.max(2, math.round(loopDuration * targetFPS))
	local projectionMode = AnimationProjection.Resolve(options)
	local color = option(options, "Color") or Color3.fromRGB(255, 255, 255)
	local strength = option(options, "Strength") or 1.15
	local shineLineWidth = option(options, "ShineLineWidth") or 0.02
	local shineLineStrength = option(options, "ShineLineStrength") or 1.0
	local stripeSpeed = option(options, "StripeSpeed") or 1
	local stripeWaviness = option(options, "StripeWaviness") or 0.007
	local stripeBreakup = option(options, "StripeBreakup") or 0.28

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
				PrimaryColor = color,
			},
			Bakes = {
				ForceField = {
					Bake = true,
					SharedKey = sharedKey("TriangularForceField", {
						width,
						height,
						bakedFrameCount,
						projectionMode,
						strength,
						shineLineWidth,
						shineLineStrength,
						stripeSpeed,
						stripeWaviness,
						stripeBreakup,
					}),
					Outputs = {
						forceField = "forceField",
					},
					Nodes = {
						{
							Type = "TriangularStripeForceField",
							Parameters = {
								Strength = strength,
								ShineLineWidth = shineLineWidth,
								ShineLineStrength = shineLineStrength,
								StripeSpeed = stripeSpeed,
								StripeWaviness = stripeWaviness,
								StripeBreakup = stripeBreakup,
							},
						},
					},
				},
			},
		},
		Nodes = {
			{
				Type = "ForceFieldMaterial",
				Parameters = {
					ColorKey = "PrimaryColor",
				},
			},
		},
		SurfaceAppearance = {
			AlphaMode = Enum.AlphaMode.Transparency,
			EmissiveStrength = option(options, "EmissiveStrength") or 8.5,
			EmissiveTint = color,
		},
		YieldEveryFrame = true,
	})
end

return TriangularForceFieldAnimation
