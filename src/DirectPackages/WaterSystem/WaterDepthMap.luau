--!strict

local PackedFloatBuffer = require(script.Parent.PackedFloatBuffer)

---@class WaterDepthMapConfig
---@field CFrame CFrame
---@field SizeX number
---@field SizeZ number
---@field Resolution number?
---@field MaxDepth number?
---@field FallbackDepth number?
---@field SourcePart BasePart?
---@field IgnoreInstances { Instance }?

export type Config = {
	CFrame: CFrame,
	SizeX: number,
	SizeZ: number,
	Resolution: number?,
	MaxDepth: number?,
	FallbackDepth: number?,
	SourcePart: BasePart?,
	IgnoreInstances: { Instance }?,
}

---@class WaterDepthMap
---@field Resolution number
---@field Stride number
---@field SizeX number
---@field SizeZ number
---@field MaxDepth number
---@field FallbackDepth number
---@field Values buffer
---@field AverageDepth number
---@field MinDepth number
---@field MaxSampleDepth number
export type WaterDepthMap = {
	Resolution: number,
	Stride: number,
	SizeX: number,
	SizeZ: number,
	MaxDepth: number,
	FallbackDepth: number,
	Values: buffer,
	AverageDepth: number,
	MinDepth: number,
	MaxSampleDepth: number,

	SampleDepth: (self: WaterDepthMap, localX: number, localZ: number) -> number,
	GetDeepFactor: (self: WaterDepthMap, localX: number, localZ: number) -> number,
	GetShoreFactor: (self: WaterDepthMap, localX: number, localZ: number) -> number,
}

local WaterDepthMap = {}
WaterDepthMap.__index = WaterDepthMap

local DEFAULT_RESOLUTION = 9
local DEFAULT_MAX_DEPTH = 180
local DEFAULT_FALLBACK_DEPTH = 24
local SHALLOW_DEPTH = 4
local DEEP_DEPTH = 42

local function IndexOf(stride: number, x: number, y: number): number
	return y * stride + x + 1
end

local function SmoothStep(edge0: number, edge1: number, value: number): number
	if edge0 == edge1 then
		return if value >= edge1 then 1 else 0
	end

	local alpha = math.clamp((value - edge0) / (edge1 - edge0), 0, 1)

	return alpha * alpha * (3 - 2 * alpha)
end

local function BuildRaycastParams(sourcePart: BasePart?, ignoreInstances: { Instance }?): RaycastParams
	local params = RaycastParams.new()
	local ignore = {}

	if sourcePart ~= nil then
		table.insert(ignore, sourcePart)
	end

	if ignoreInstances ~= nil then
		for _, instance in ignoreInstances do
			table.insert(ignore, instance)
		end
	end

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true

	return params
end

---@param config WaterDepthMapConfig
---@return WaterDepthMap
function WaterDepthMap.new(config: Config): WaterDepthMap
	local resolution = math.clamp(math.floor(config.Resolution or DEFAULT_RESOLUTION), 2, 32)
	local stride = resolution + 1
	local count = stride * stride
	local values = PackedFloatBuffer.create(count)
	local maxDepth = config.MaxDepth or DEFAULT_MAX_DEPTH
	local fallbackDepth = math.clamp(config.FallbackDepth or DEFAULT_FALLBACK_DEPTH, 0, maxDepth)
	local halfX = config.SizeX * 0.5
	local halfZ = config.SizeZ * 0.5
	local up = config.CFrame.UpVector
	local params = BuildRaycastParams(config.SourcePart, config.IgnoreInstances)
	local total = 0
	local minDepth = math.huge
	local maxSampleDepth = 0

	for y = 0, resolution do
		local localZ = (y / resolution) * config.SizeZ - halfZ

		for x = 0, resolution do
			local localX = (x / resolution) * config.SizeX - halfX
			local surfacePoint = config.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
			local rayOrigin = surfacePoint + up * 0.5
			local result = workspace:Raycast(rayOrigin, -up * maxDepth, params)
			local depth = fallbackDepth

			if result ~= nil then
				depth = math.clamp((rayOrigin - result.Position).Magnitude - 0.5, 0, maxDepth)
			end

			local index = IndexOf(stride, x, y)

			PackedFloatBuffer.write(values, index, depth)
			total += depth
			minDepth = math.min(minDepth, depth)
			maxSampleDepth = math.max(maxSampleDepth, depth)
		end
	end

	local self = setmetatable({
		Resolution = resolution,
		Stride = stride,
		SizeX = config.SizeX,
		SizeZ = config.SizeZ,
		MaxDepth = maxDepth,
		FallbackDepth = fallbackDepth,
		Values = values,
		AverageDepth = total / count,
		MinDepth = if minDepth < math.huge then minDepth else fallbackDepth,
		MaxSampleDepth = maxSampleDepth,
	}, WaterDepthMap) :: any

	return self :: WaterDepthMap
end

---@param localX number
---@param localZ number
---@return number
function WaterDepthMap:SampleDepth(localX: number, localZ: number): number
	local gridX = (localX / self.SizeX + 0.5) * self.Resolution
	local gridY = (localZ / self.SizeZ + 0.5) * self.Resolution

	return PackedFloatBuffer.sample(self.Values, self.Resolution, self.Stride, gridX, gridY)
end

---@param localX number
---@param localZ number
---@return number
function WaterDepthMap:GetDeepFactor(localX: number, localZ: number): number
	return SmoothStep(SHALLOW_DEPTH, DEEP_DEPTH, self:SampleDepth(localX, localZ))
end

---@param localX number
---@param localZ number
---@return number
function WaterDepthMap:GetShoreFactor(localX: number, localZ: number): number
	return 1 - self:GetDeepFactor(localX, localZ)
end

return WaterDepthMap
