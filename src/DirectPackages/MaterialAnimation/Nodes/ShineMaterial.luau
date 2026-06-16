local function valueOr(value: any, fallback: any): any
	return if value == nil then fallback else value
end

local function resolveColor(parameters, context, fallback: Color3): Color3
	if parameters.ShineBackgroundColor ~= nil then
		return parameters.ShineBackgroundColor
	end

	local colorKey = parameters.BackgroundColorKey or "BackgroundColor"
	return context.workspace[colorKey] or fallback
end

return {
	Name = "ShineMaterial",
	Family = "Material",
	Inputs = { "shine" },
	Outputs = { "color", "alpha", "emissive", "emissiveAlpha" },
	DependsOnTime = false,

	Execute = function(inputs, parameters, context)
		local intensity = inputs.shine or 0
		local backgroundAlpha = valueOr(parameters.ShineBackgroundAlpha, 0.52)

		return {
			color = resolveColor(parameters, context, Color3.fromRGB(255, 160, 70)),
			alpha = backgroundAlpha + intensity * (1 - backgroundAlpha),
			emissive = intensity,
			emissiveAlpha = 1,
		}
	end,
}
