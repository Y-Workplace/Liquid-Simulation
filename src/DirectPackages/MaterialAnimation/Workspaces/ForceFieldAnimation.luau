local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)
local MaterialAnimation = require(script.Parent.Parent.MaterialAnimation)

export type Options = AnimationProjection.Options & {
	Width: number?,
	Height: number?,
	TargetFPS: number?,
	BakedFrameCount: number?,
	Color: Color3?,
	WarpScale: number?,
	CoreIntensity: number?,
	BloomSpread: number?,
	Strength: number?,
	EmissiveStrength: number?,
	NoiseScale: number?,
	TimeRadius: number?,
}

local DEFAULT_WIDTH = 64
local DEFAULT_HEIGHT = 64
local DEFAULT_TARGET_FPS = 15
local DEFAULT_BAKED_FRAME_COUNT = 180

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

local ForceFieldAnimation = {}

function ForceFieldAnimation.new(options: Options?): MaterialAnimation.MaterialAnimation
	local width = option(options, "Width") or DEFAULT_WIDTH
	local height = option(options, "Height") or DEFAULT_HEIGHT
	local targetFPS = option(options, "TargetFPS") or DEFAULT_TARGET_FPS
	local bakedFrameCount = option(options, "BakedFrameCount") or DEFAULT_BAKED_FRAME_COUNT
	local projectionMode = AnimationProjection.Resolve(options)
	local color = option(options, "Color") or Color3.fromRGB(255, 160, 70)
	local warpScale = option(options, "WarpScale") or 1.5
	local coreIntensity = option(options, "CoreIntensity") or 25
	local bloomSpread = option(options, "BloomSpread") or 4.5
	local strength = option(options, "Strength") or 1
	local noiseScale = option(options, "NoiseScale") or 0.2
	local timeRadius = option(options, "TimeRadius") or 1.35

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
					SharedKey = sharedKey("ForceField", {
						width,
						height,
						bakedFrameCount,
						projectionMode,
						warpScale,
						coreIntensity,
						bloomSpread,
						strength,
						noiseScale,
						timeRadius,
					}),
					Outputs = {
						forceField = "forceField",
					},
					Nodes = {
						{
							Type = "ForceFieldIntensity",
							Parameters = {
								WarpScale = warpScale,
								CoreIntensity = coreIntensity,
								BloomSpread = bloomSpread,
								Strength = strength,
								NoiseScale = noiseScale,
								TimeRadius = timeRadius,
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
			EmissiveStrength = option(options, "EmissiveStrength") or 3.75,
			EmissiveTint = color,
		},
	})
end

return ForceFieldAnimation
