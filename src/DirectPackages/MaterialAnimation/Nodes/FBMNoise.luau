local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)

local TAU = math.pi * 2

local function valueOr(value: any, fallback: any): any
	return if value == nil then fallback else value
end

local function tileableNoise(
	x: number,
	y: number,
	width: number,
	height: number,
	scale: number,
	offsetX: number,
	offsetY: number
): number
	local u = x / width
	local v = y / height
	local angleU = u * TAU
	local angleV = v * TAU
	local nx = math.cos(angleU) * scale
	local ny = math.sin(angleU) * scale
	local nz = math.cos(angleV) * scale
	local nw = math.sin(angleV) * scale

	return math.noise(nx + offsetX, ny, nz + nw + offsetY)
end

return {
	Name = "FBMNoise",
	Family = "Source",
	Inputs = {},
	Outputs = { "noise" },
	DependsOnTime = true,

	Execute = function(_inputs, parameters, context)
		local noiseScale = valueOr(parameters.NoiseScale, 0.1)
		local animationRadius = valueOr(parameters.AnimationRadius, 1.5)
		local octaves = valueOr(parameters.Octaves, 3)
		local total = 0
		local amplitude = 0.5
		local frequency = 1
		local offsetX = math.cos(context.t) * animationRadius
		local offsetY = math.sin(context.t) * animationRadius

		for _ = 1, octaves do
			local noise
			if context.projectionMode == "Equirectangular" then
				local projectedX, projectedY, projectedZ =
					AnimationProjection.ProjectPixel(context.x, context.y, context.width, context.height, context.projectionMode)
				noise = math.noise(
					projectedX * noiseScale * frequency / context.width + offsetX,
					projectedY * noiseScale * frequency / context.height + offsetY,
					projectedZ * noiseScale * frequency
				)
			else
				noise = tileableNoise(
					context.x,
					context.y,
					context.width,
					context.height,
					noiseScale * frequency,
					offsetX,
					offsetY
				)
			end

			total += noise * amplitude
			frequency *= 2
			amplitude *= 0.5
		end

		return {
			noise = total,
		}
	end,
}
