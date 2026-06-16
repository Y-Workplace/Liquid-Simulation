local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)
local MaterialAnimation = require(script.Parent.Parent.MaterialAnimation)

export type Options = AnimationProjection.Options & {
	Width: number?,
	Height: number?,
	TargetFPS: number?,
	BakedFrameCount: number?,
	NoiseScale: number?,
	PigmentThreshold: number?,
	ColorA: Color3?,
	ColorB: Color3?,
	AnimationRadius: number?,
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

local NotesAnimation = {}

function NotesAnimation.new(options: Options?): MaterialAnimation.MaterialAnimation
	local width = option(options, "Width") or DEFAULT_WIDTH
	local height = option(options, "Height") or DEFAULT_HEIGHT
	local targetFPS = option(options, "TargetFPS") or DEFAULT_TARGET_FPS
	local bakedFrameCount = option(options, "BakedFrameCount") or DEFAULT_BAKED_FRAME_COUNT
	local projectionMode = AnimationProjection.Resolve(options)
	local noiseScale = option(options, "NoiseScale") or 0.1
	local animationRadius = option(options, "AnimationRadius") or 1.5

	return MaterialAnimation.new({
		Width = width,
		Height = height,
		TargetFPS = targetFPS,
		BakedFrameCount = bakedFrameCount,
		Projection = option(options, "Projection"),
		SphericalNormalization = option(options, "SphericalNormalization"),
		Channels = { "ColorMap" },
		Workspace = {
			Values = {
				PrimaryColor = option(options, "ColorA") or Color3.fromRGB(180, 70, 10),
				SecondaryColor = option(options, "ColorB") or Color3.fromRGB(255, 160, 70),
			},
			Bakes = {
				Pigment = {
					Bake = true,
					SharedKey = sharedKey("NotesPigment", {
						width,
						height,
						bakedFrameCount,
						projectionMode,
						noiseScale,
						animationRadius,
					}),
					Outputs = {
						noise = "pigment",
					},
					Nodes = {
						{
							Type = "FBMNoise",
							Parameters = {
								NoiseScale = noiseScale,
								AnimationRadius = animationRadius,
								Octaves = 3,
							},
						},
					},
				},
			},
		},
		Nodes = {
			{
				Type = "NoiseToPalette",
				Inputs = {
					noise = "pigment",
				},
				Parameters = {
					PigmentThreshold = option(options, "PigmentThreshold") or 0.3,
					ColorAKey = "PrimaryColor",
					ColorBKey = "SecondaryColor",
				},
			},
		},
	})
end

return NotesAnimation
