local function valueOr(value: any, fallback: any): any
	return if value == nil then fallback else value
end

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function resolveColor(parameters, context, directKey: string, keyParameter: string, fallbackKey: string, fallback: Color3): Color3
	if parameters[directKey] ~= nil then
		return parameters[directKey]
	end

	return context.workspace[parameters[keyParameter] or fallbackKey] or fallback
end

return {
	Name = "NoiseToPalette",
	Family = "Material",
	Inputs = { "noise" },
	Outputs = { "color", "alpha" },
	DependsOnTime = false,

	Execute = function(inputs, parameters, context)
		local colorA = resolveColor(parameters, context, "ColorA", "ColorAKey", "PrimaryColor", Color3.fromRGB(180, 70, 10))
		local colorB = resolveColor(parameters, context, "ColorB", "ColorBKey", "SecondaryColor", Color3.fromRGB(255, 160, 70))
		local pigmentThreshold = valueOr(parameters.PigmentThreshold, 0.3)
		local alpha = valueOr(parameters.Alpha, 1)
		local noise = math.clamp(((inputs.noise or 0) + 1) * 0.5, 0, 1)
		local mix = math.clamp((noise - pigmentThreshold) / (1 - pigmentThreshold), 0, 1)

		return {
			color = Color3.new(
				lerp(colorA.R, colorB.R, mix),
				lerp(colorA.G, colorB.G, mix),
				lerp(colorA.B, colorB.B, mix)
			),
			alpha = alpha,
		}
	end,
}
