local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)

local function valueOr(value: any, fallback: any): any
	return if value == nil then fallback else value
end

local function bandIntensity(proj: number, cycleT: number, bandWidth: number, fadeIn: number, fadeOut: number, peak: number): number
	local bandHalf = bandWidth * 0.5
	local bandCenter = cycleT * (1 + bandWidth) - bandHalf

	local dist = math.abs(proj - bandCenter)
	if dist >= bandHalf then
		return 0
	end

	local bandT = 1 - (dist / bandHalf)
	local bandShape = 0.5 - 0.5 * math.cos(bandT * math.pi)

	local envelope
	if cycleT < fadeIn then
		envelope = cycleT / fadeIn
	elseif cycleT > (1 - fadeOut) then
		envelope = (1 - cycleT) / fadeOut
	else
		envelope = 1
	end

	envelope = envelope * envelope * (3 - 2 * envelope)

	return bandShape * envelope * peak
end

return {
	Name = "ShineBand",
	Family = "Source",
	Inputs = {},
	Outputs = { "shine" },
	DependsOnTime = true,

	Execute = function(_inputs, parameters, context)
		local shineBandWidth = valueOr(parameters.ShineBandWidth, 0.18)
		local shinePeak = valueOr(parameters.ShinePeak, 1.0)
		local shineAngleDeg = valueOr(parameters.ShineAngleDeg, 30)
		local shineFadeIn = valueOr(parameters.ShineFadeIn, 0.18)
		local shineFadeOut = valueOr(parameters.ShineFadeOut, 0.22)
		local shineCos = math.cos(math.rad(shineAngleDeg))
		local shineSin = math.sin(math.rad(shineAngleDeg))
		local projectedX, projectedY =
			AnimationProjection.ProjectPixel(context.x, context.y, context.width, context.height, context.projectionMode)
		local cx = projectedX - context.width * 0.5
		local cy = projectedY - context.height * 0.5
		local diag = math.sqrt(context.width * context.width + context.height * context.height)
		local proj = (cx * shineCos + cy * shineSin) / diag + 0.5

		return {
			shine = bandIntensity(proj, context.cycleT, shineBandWidth, shineFadeIn, shineFadeOut, shinePeak),
		}
	end,
}
