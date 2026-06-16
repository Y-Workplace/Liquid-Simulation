--!strict

local PackedFloatBuffer = require(script.Parent.PackedFloatBuffer)

---@class WaterObstacleMapConfig
---@field CFrame CFrame
---@field SizeX number
---@field SizeZ number
---@field Resolution number?
---@field ObstacleRoot Instance?
---@field RayHeight number?
---@field RayDepth number?
---@field InfluenceRadius number?
---@field ExcludeInstances { Instance }?
---@field BakeAnchoredObstacles boolean?

export type Config = {
	CFrame: CFrame,
	SizeX: number,
	SizeZ: number,
	Resolution: number?,
	ObstacleRoot: Instance?,
	RayHeight: number?,
	RayDepth: number?,
	InfluenceRadius: number?,
	ExcludeInstances: { Instance }?,
	BakeAnchoredObstacles: boolean?,
}

---@class WaterObstacleMap
---@field Resolution number
---@field Stride number
---@field SizeX number
---@field SizeZ number
---@field Values buffer
---@field AverageObstacle number
---@field MaxObstacle number
export type WaterObstacleMap = {
	Resolution: number,
	Stride: number,
	SizeX: number,
	SizeZ: number,
	Values: buffer,
	AverageObstacle: number,
	MaxObstacle: number,

	SampleObstacle: (self: WaterObstacleMap, localX: number, localZ: number) -> number,
	GetWaveAttenuation: (self: WaterObstacleMap, localX: number, localZ: number, strength: number?) -> number,
	GetFoamSeed: (self: WaterObstacleMap, localX: number, localZ: number) -> number,
}

local WaterObstacleMap = {}
WaterObstacleMap.__index = WaterObstacleMap

local DEFAULT_RESOLUTION = 16
local DEFAULT_RAY_HEIGHT = 8
local DEFAULT_RAY_DEPTH = 32
local DEFAULT_INFLUENCE_RADIUS = 6

local function IndexOf(stride: number, x: number, y: number): number
	return y * stride + x + 1
end

local function BuildRaycastParams(obstacleRoot: Instance?, excludeInstances: { Instance }?, bakeAnchoredObstacles: boolean?): RaycastParams?
	local params = RaycastParams.new()

	if bakeAnchoredObstacles == true then
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludeInstances or {}
	elseif obstacleRoot ~= nil then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { obstacleRoot }
	else
		return nil
	end

	params.IgnoreWater = true

	return params
end

local function IsValidObstacleHit(result: RaycastResult, bakeAnchoredObstacles: boolean?): boolean
	if bakeAnchoredObstacles ~= true then
		return true
	end

	if result.Instance:IsA("Terrain") then
		return true
	end

	local basePart = result.Instance :: Instance

	if basePart:IsA("BasePart") then
		return basePart.Anchored
	end

	return false
end

local function ExpandInfluence(
	values: buffer,
	resolution: number,
	stride: number,
	sizeX: number,
	sizeZ: number,
	influenceRadius: number
): buffer
	if influenceRadius <= 0 then
		return values
	end

	local count = stride * stride
	local expanded = PackedFloatBuffer.create(count)
	local cellSizeX = sizeX / resolution
	local cellSizeZ = sizeZ / resolution
	local cellRadiusX = influenceRadius / math.max(cellSizeX, 0.001)
	local cellRadiusY = influenceRadius / math.max(cellSizeZ, 0.001)
	local maxCellRadius = math.ceil(math.max(cellRadiusX, cellRadiusY))

	PackedFloatBuffer.copy(values, expanded, count)

	for y = 0, resolution do
		for x = 0, resolution do
			local source = PackedFloatBuffer.read(values, IndexOf(stride, x, y))

			if source <= 0 then
				continue
			end

			local minX = math.max(x - maxCellRadius, 0)
			local maxX = math.min(x + maxCellRadius, resolution)
			local minY = math.max(y - maxCellRadius, 0)
			local maxY = math.min(y + maxCellRadius, resolution)

			for ny = minY, maxY do
				for nx = minX, maxX do
					local dx = (nx - x) / math.max(cellRadiusX, 0.001)
					local dy = (ny - y) / math.max(cellRadiusY, 0.001)
					local distance = math.sqrt(dx * dx + dy * dy)

					if distance <= 1 then
						local weight = source * (1 - distance)
						local index = IndexOf(stride, nx, ny)

						PackedFloatBuffer.write(expanded, index, math.max(PackedFloatBuffer.read(expanded, index), weight))
					end
				end
			end
		end
	end

	return expanded
end

---@param config WaterObstacleMapConfig
---@return WaterObstacleMap
function WaterObstacleMap.new(config: Config): WaterObstacleMap
	local resolution = math.clamp(math.floor(config.Resolution or DEFAULT_RESOLUTION), 2, 64)
	local stride = resolution + 1
	local count = stride * stride
	local values = PackedFloatBuffer.create(count)
	local params = BuildRaycastParams(config.ObstacleRoot, config.ExcludeInstances, config.BakeAnchoredObstacles)
	local halfX = config.SizeX * 0.5
	local halfZ = config.SizeZ * 0.5
	local rayHeight = config.RayHeight or DEFAULT_RAY_HEIGHT
	local rayDepth = config.RayDepth or DEFAULT_RAY_DEPTH
	local up = config.CFrame.UpVector

	if params ~= nil then
		for y = 0, resolution do
			local localZ = (y / resolution) * config.SizeZ - halfZ

			for x = 0, resolution do
				local localX = (x / resolution) * config.SizeX - halfX
				local surfacePoint = config.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
				local rayOrigin = surfacePoint + up * rayHeight
				local result = workspace:Raycast(rayOrigin, -up * rayDepth, params)

				if result ~= nil and IsValidObstacleHit(result, config.BakeAnchoredObstacles) then
					PackedFloatBuffer.write(values, IndexOf(stride, x, y), 1)
				end
			end
		end
	end

	values = ExpandInfluence(
		values,
		resolution,
		stride,
		config.SizeX,
		config.SizeZ,
		config.InfluenceRadius or DEFAULT_INFLUENCE_RADIUS
	)

	local total = 0
	local maxObstacle = 0

	for index = 1, count do
		local value = PackedFloatBuffer.read(values, index)

		total += value
		maxObstacle = math.max(maxObstacle, value)
	end

	local self = setmetatable({
		Resolution = resolution,
		Stride = stride,
		SizeX = config.SizeX,
		SizeZ = config.SizeZ,
		Values = values,
		AverageObstacle = total / count,
		MaxObstacle = maxObstacle,
	}, WaterObstacleMap) :: any

	return self :: WaterObstacleMap
end

---@param localX number
---@param localZ number
---@return number
function WaterObstacleMap:SampleObstacle(localX: number, localZ: number): number
	local gridX = (localX / self.SizeX + 0.5) * self.Resolution
	local gridY = (localZ / self.SizeZ + 0.5) * self.Resolution

	return PackedFloatBuffer.sample(self.Values, self.Resolution, self.Stride, gridX, gridY)
end

---@param localX number
---@param localZ number
---@param strength number?
---@return number
function WaterObstacleMap:GetWaveAttenuation(localX: number, localZ: number, strength: number?): number
	local obstacle = self:SampleObstacle(localX, localZ)
	local amount = strength or 0.65

	return math.clamp(1 - obstacle * amount, 0, 1)
end

---@param localX number
---@param localZ number
---@return number
function WaterObstacleMap:GetFoamSeed(localX: number, localZ: number): number
	return self:SampleObstacle(localX, localZ)
end

return WaterObstacleMap
