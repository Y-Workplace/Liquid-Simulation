local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)
local MaterialAnimation = require(script.Parent.Parent.MaterialAnimation)

export type Options = AnimationProjection.Options & {
	Width: number?,
	Height: number?,
	TargetFPS: number?,
	BakedFrameCount: number?,
	NoiseScale: number?,
	ColorA: Color3?,
	ColorB: Color3?,
	ColorC: Color3?,
	ColorD: Color3?,
	ColorE: Color3?,
	AnimationRadius: number?,
}

local DEFAULT_WIDTH = 128
local DEFAULT_HEIGHT = 128
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

local TriangularNotesAnimation = {}

function TriangularNotesAnimation.new(options: Options?): MaterialAnimation.MaterialAnimation
	local width = option(options, "Width") or DEFAULT_WIDTH
	local height = option(options, "Height") or DEFAULT_HEIGHT
	local targetFPS = option(options, "TargetFPS") or DEFAULT_TARGET_FPS
	local bakedFrameCount = option(options, "BakedFrameCount") or DEFAULT_BAKED_FRAME_COUNT
	local projectionMode = AnimationProjection.Resolve(options)
	local colorA = option(options, "ColorA") or Color3.fromRGB(22, 180, 222)
	local colorB = option(options, "ColorB") or Color3.fromRGB(103, 226, 232)
	local colorC = option(options, "ColorC") or Color3.fromRGB(129, 239, 238)
	local colorD = option(options, "ColorD") or Color3.fromRGB(29, 118, 228)
	local colorE = option(options, "ColorE") or Color3.fromRGB(41, 205, 226)
	local animationRadius = option(options, "AnimationRadius") or 0.565

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
				ColorA = colorA,
				ColorB = colorB,
				ColorC = colorC,
				ColorD = colorD,
				ColorE = colorE,
			},
			Bakes = {
				Color = {
					Bake = true,
					SharedKey = sharedKey("TriangularNotesColor", {
						width,
						height,
						bakedFrameCount,
						projectionMode,
						colorA,
						colorB,
						colorC,
						colorD,
						colorE,
						animationRadius,
					}),
					Outputs = {
						color = "color",
						alpha = "alpha",
					},
					Nodes = {
						{
							Type = "TriangularNotesLayers",
							Parameters = {
								ColorAKey = "ColorA",
								ColorBKey = "ColorB",
								ColorCKey = "ColorC",
								ColorDKey = "ColorD",
								ColorEKey = "ColorE",
								AnimationRadius = animationRadius,
							},
						},
					},
				},
			},
		},
		Nodes = {},
		YieldEveryFrame = true,
	})
end

return TriangularNotesAnimation
