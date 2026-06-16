local TAU = math.pi * 2

export type ProjectionMode = "Flat" | "Equirectangular"

export type Options = {
	Projection: ProjectionMode?,
	SphericalNormalization: boolean?,
}

local AnimationProjection = {}

function AnimationProjection.Resolve(options: Options?): ProjectionMode
	if options == nil then
		return "Flat"
	end

	if options.Projection == "Equirectangular" or options.SphericalNormalization == true then
		return "Equirectangular"
	end

	return "Flat"
end

function AnimationProjection.ProjectPixel(
	x: number,
	y: number,
	width: number,
	height: number,
	mode: ProjectionMode
): (number, number, number)
	if mode ~= "Equirectangular" then
		return x, y, 0
	end

	local u = if width > 1 then x / (width - 1) else 0
	local v = if height > 1 then y / (height - 1) else 0
	local longitude = (u - 0.5) * TAU
	local latitude = (0.5 - v) * math.pi
	local cosLatitude = math.cos(latitude)

	local sphereX = math.sin(longitude) * cosLatitude
	local sphereY = math.sin(latitude)
	local sphereZ = math.cos(longitude) * cosLatitude

	return (sphereX * 0.5 + 0.5) * width, (sphereY * -0.5 + 0.5) * height, sphereZ
end

function AnimationProjection.ProjectDirection(
	x: number,
	y: number,
	width: number,
	height: number,
	mode: ProjectionMode
): (number, number, number)
	if mode ~= "Equirectangular" then
		return x / width, y / height, 0
	end

	local u = if width > 1 then x / (width - 1) else 0
	local v = if height > 1 then y / (height - 1) else 0
	local longitude = (u - 0.5) * TAU
	local latitude = (0.5 - v) * math.pi
	local cosLatitude = math.cos(latitude)

	if math.abs(cosLatitude) < 0.000001 then
		local poleY = if latitude > 0 then 1 else -1
		return 0, poleY, 0
	end

	return math.sin(longitude) * cosLatitude, math.sin(latitude), math.cos(longitude) * cosLatitude
end

return AnimationProjection
