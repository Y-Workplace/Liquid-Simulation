local function resolveColor(parameters, context, fallback: Color3): Color3
	if parameters.Color ~= nil then
		return parameters.Color
	end

	local colorKey = parameters.ColorKey or "PrimaryColor"
	return context.workspace[colorKey] or fallback
end

return {
	Name = "ForceFieldMaterial",
	Family = "Material",
	Inputs = { "forceField" },
	Outputs = { "color", "alpha", "emissive", "emissiveAlpha" },
	DependsOnTime = false,

	Execute = function(inputs, parameters, context)
		local intensity = inputs.forceField or 0

		return {
			color = resolveColor(parameters, context, Color3.fromRGB(255, 160, 70)),
			alpha = intensity,
			emissive = intensity,
			emissiveAlpha = 1,
		}
	end,
}
