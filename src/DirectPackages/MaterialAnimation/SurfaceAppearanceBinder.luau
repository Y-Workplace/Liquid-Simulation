local AssetService = game:GetService("AssetService")

local MaterialAnimation = require(script.Parent.MaterialAnimation)

export type BindOptions = MaterialAnimation.SurfaceAppearanceConfig

local SurfaceAppearanceBinder = {}

local function mergeOptions(animation: MaterialAnimation.MaterialAnimation, options: BindOptions?): BindOptions
	local merged = {}
	local defaults = animation:GetSurfaceAppearanceConfig()

	if defaults ~= nil then
		for key, value in pairs(defaults) do
			merged[key] = value
		end
	end

	if options ~= nil then
		for key, value in pairs(options) do
			merged[key] = value
		end
	end

	return merged
end

local function applySurfaceOptions(surface: SurfaceAppearance, options: BindOptions)
	if options.Name ~= nil then
		surface.Name = options.Name
	end

	if options.AlphaMode ~= nil then
		surface.AlphaMode = options.AlphaMode
	end

	if options.EmissiveStrength ~= nil then
		surface.EmissiveStrength = options.EmissiveStrength
	end

	if options.EmissiveTint ~= nil then
		surface.EmissiveTint = options.EmissiveTint
	end
end

function SurfaceAppearanceBinder.CreateSurfaceAppearance(
	animation: MaterialAnimation.MaterialAnimation,
	options: BindOptions?
): SurfaceAppearance
	if animation:GetEditable("ColorMap") == nil then
		animation:Init()
	end

	local createOptions = {}
	local colorMap = animation:GetEditable("ColorMap")
	local emissiveMask = animation:GetEditable("EmissiveMask")

	if colorMap ~= nil then
		createOptions.ColorMap = Content.fromObject(colorMap)
	end

	if emissiveMask ~= nil then
		createOptions.EmissiveMask = Content.fromObject(emissiveMask)
	end

	local surface = AssetService:CreateSurfaceAppearanceAsync(createOptions)
	applySurfaceOptions(surface, mergeOptions(animation, options))

	return surface
end

function SurfaceAppearanceBinder.Bind(
	animation: MaterialAnimation.MaterialAnimation,
	parts: { MeshPart },
	options: BindOptions?
): { SurfaceAppearance }
	local surfaces = table.create(#parts)

	for _, part in ipairs(parts) do
		local surface = SurfaceAppearanceBinder.CreateSurfaceAppearance(animation, options)
		surface.Parent = part
		table.insert(surfaces, surface)
	end

	return surfaces
end

return SurfaceAppearanceBinder
