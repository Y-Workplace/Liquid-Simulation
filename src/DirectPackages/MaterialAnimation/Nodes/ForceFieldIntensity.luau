local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)

local TAU = math.pi * 2

local function valueOr(value: any, fallback: any): any
	return if value == nil then fallback else value
end

local function tileableNoise(
	width: number,
	height: number,
	timeRadius: number,
	x: number,
	y: number,
	t: number,
	scale: number,
	seed: number
): number
	local u = (x / width) % 1
	local v = (y / height) % 1
	local angleU = u * TAU
	local angleV = v * TAU
	local timeX = math.cos(t + seed) * timeRadius
	local timeY = math.sin(t + seed) * timeRadius

	local nx = math.cos(angleU) * scale + timeX
	local ny = math.sin(angleU) * scale + seed
	local nz = (math.cos(angleV) + math.sin(angleV)) * scale + timeY

	return math.noise(nx, ny, nz)
end

local function sphereNoise(
	timeRadius: number,
	directionX: number,
	directionY: number,
	directionZ: number,
	t: number,
	scale: number,
	seed: number,
	warpX: number?,
	warpY: number?
): number
	local timeX = math.cos(t + seed) * timeRadius
	local timeY = math.sin(t + seed) * timeRadius
	local warpedDirectionX = directionX + (warpX or 0)
	local warpedDirectionY = directionY + (warpY or 0)

	return math.noise(warpedDirectionX * scale + timeX, warpedDirectionY * scale + seed, directionZ * scale + timeY)
end

return {
	Name = "ForceFieldIntensity",
	Family = "Source",
	Inputs = {},
	Outputs = { "forceField" },
	DependsOnTime = true,

	Execute = function(_inputs, parameters, context)
		local warpScale = valueOr(parameters.WarpScale, 1.5)
		local coreIntensity = valueOr(parameters.CoreIntensity, 25)
		local bloomSpread = valueOr(parameters.BloomSpread, 4.5)
		local strength = valueOr(parameters.Strength, 1)
		local noiseScale = valueOr(parameters.NoiseScale, 0.2)
		local timeRadius = valueOr(parameters.TimeRadius, 1.35)
		local ridge

		if context.projectionMode == "Equirectangular" then
			local directionX, directionY, directionZ =
				AnimationProjection.ProjectDirection(context.x, context.y, context.width, context.height, "Equirectangular")
			local warp1 = sphereNoise(timeRadius, directionX, directionY, directionZ, context.t, noiseScale, 0.0)
			local warp2 = sphereNoise(timeRadius, directionX, directionY, directionZ, context.t, noiseScale, 1.5)
			ridge = math.abs(
				sphereNoise(
					timeRadius,
					directionX,
					directionY,
					directionZ,
					context.t,
					noiseScale,
					3.0,
					warp2 * warpScale,
					warp1 * warpScale
				)
			)
		else
			local warp1 =
				tileableNoise(context.width, context.height, timeRadius, context.x, context.y, context.t, noiseScale, 0.0)
			local warp2 = tileableNoise(
				context.width,
				context.height,
				timeRadius,
				context.x + warp1 * context.width,
				context.y - warp1 * context.height,
				context.t,
				noiseScale,
				1.5
			)

			local warpedX = context.x + warp2 * warpScale * context.width
			local warpedY = context.y + warp1 * warpScale * context.height
			ridge =
				math.abs(tileableNoise(context.width, context.height, timeRadius, warpedX, warpedY, context.t, noiseScale, 3.0))
		end

		local core = math.exp(-ridge * coreIntensity)
		local glow = math.exp(-ridge * bloomSpread) * 0.55

		return {
			forceField = math.clamp((core + glow) * strength, 0, 1),
		}
	end,
}
