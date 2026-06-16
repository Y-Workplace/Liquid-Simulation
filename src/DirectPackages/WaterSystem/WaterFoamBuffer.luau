--!strict

local WaterBufferModule = require(script.Parent.WaterBuffer)
local WaterDepthMapModule = require(script.Parent.WaterDepthMap)
local WaterObstacleMapModule = require(script.Parent.WaterObstacleMap)
local PackedFloatBuffer = require(script.Parent.PackedFloatBuffer)

type WaterBuffer = WaterBufferModule.WaterBuffer
type WaterDepthMap = WaterDepthMapModule.WaterDepthMap
type WaterObstacleMap = WaterObstacleMapModule.WaterObstacleMap

---@class WaterFoamBufferConfig
---@field Resolution number?
---@field SizeX number?
---@field SizeZ number?
---@field Decay number?
---@field Growth number?
---@field SlopeThreshold number?
---@field VelocityThreshold number?
---@field InteractiveStrength number?
---@field ShallowStrength number?
---@field ObstacleStrength number?
---@field MaxFoam number?

type SurfaceContributionSampler = (number, number) -> (number, number)

export type Config = {
	Resolution: number?,
	SizeX: number?,
	SizeZ: number?,
	Decay: number?,
	Growth: number?,
	SlopeThreshold: number?,
	VelocityThreshold: number?,
	InteractiveStrength: number?,
	ShallowStrength: number?,
	ObstacleStrength: number?,
	MaxFoam: number?,
}

---@class WaterFoamBuffer
---@field Resolution number
---@field Stride number
---@field SizeX number
---@field SizeZ number
---@field Count number
---@field Values buffer
---@field TintValues buffer
---@field Decay number
---@field Growth number
---@field SlopeThreshold number
---@field VelocityThreshold number
---@field InteractiveStrength number
---@field ShallowStrength number
---@field ObstacleStrength number
---@field MaxFoam number
---@field Version number
---@field MaxValue number
---@field MaxTintValue number
export type WaterFoamBuffer = {
	Resolution: number,
	Stride: number,
	SizeX: number,
	SizeZ: number,
	Count: number,
	Values: buffer,
	TintValues: buffer,
	Decay: number,
	Growth: number,
	SlopeThreshold: number,
	VelocityThreshold: number,
	InteractiveStrength: number,
	ShallowStrength: number,
	ObstacleStrength: number,
	MaxFoam: number,
	Version: number,
	MaxValue: number,
	MaxTintValue: number,

	AddFoam: (self: WaterFoamBuffer, localX: number, localZ: number, radius: number, amount: number, tintAmount: number?) -> nil,
	UpdateFromMaps: (
		self: WaterFoamBuffer,
		buffer: WaterBuffer?,
		depthMap: WaterDepthMap?,
		obstacleMap: WaterObstacleMap?,
		dt: number,
		extraSampler: SurfaceContributionSampler?
	) -> nil,
	UpdateRegionFromMaps: (
		self: WaterFoamBuffer,
		buffer: WaterBuffer?,
		depthMap: WaterDepthMap?,
		obstacleMap: WaterObstacleMap?,
		dt: number,
		minX: number,
		maxX: number,
		minZ: number,
		maxZ: number,
		quality: number,
		extraSampler: SurfaceContributionSampler?
	) -> nil,
	Clear: (self: WaterFoamBuffer) -> nil,
	RecalculateMax: (self: WaterFoamBuffer) -> number,
	SampleFoam: (self: WaterFoamBuffer, localX: number, localZ: number) -> number,
	SampleTint: (self: WaterFoamBuffer, localX: number, localZ: number) -> number,
	GetIndex: (self: WaterFoamBuffer, x: number, y: number) -> number,
}

local WaterFoamBuffer = {}
WaterFoamBuffer.__index = WaterFoamBuffer

local DEFAULT_RESOLUTION = 32
local DEFAULT_SIZE = 128
local DEFAULT_DECAY = 0.72
local DEFAULT_GROWTH = 7.5
local DEFAULT_SLOPE_THRESHOLD = 0.16
local DEFAULT_VELOCITY_THRESHOLD = 0.18
local DEFAULT_INTERACTIVE_STRENGTH = 0.85
local DEFAULT_SHALLOW_STRENGTH = 0.2
local DEFAULT_OBSTACLE_STRENGTH = 0.78
local DEFAULT_MAX_FOAM = 1

local function IndexOf(stride: number, x: number, y: number): number
	return y * stride + x + 1
end

local function Hash01(x: number, y: number): number
	local value = math.sin(x * 12.9898 + y * 78.233) * 43758.5453123

	return value - math.floor(value)
end

---@param config WaterFoamBufferConfig?
---@return WaterFoamBuffer
function WaterFoamBuffer.new(config: Config?): WaterFoamBuffer
	local resolution = math.clamp(math.floor((config and config.Resolution) or DEFAULT_RESOLUTION), 2, 62)
	local stride = resolution + 1
	local count = stride * stride

	local self = setmetatable({
		Resolution = resolution,
		Stride = stride,
		SizeX = (config and config.SizeX) or DEFAULT_SIZE,
		SizeZ = (config and config.SizeZ) or DEFAULT_SIZE,
		Count = count,
		Values = PackedFloatBuffer.create(count),
		TintValues = PackedFloatBuffer.create(count),
		Decay = (config and config.Decay) or DEFAULT_DECAY,
		Growth = (config and config.Growth) or DEFAULT_GROWTH,
		SlopeThreshold = (config and config.SlopeThreshold) or DEFAULT_SLOPE_THRESHOLD,
		VelocityThreshold = (config and config.VelocityThreshold) or DEFAULT_VELOCITY_THRESHOLD,
		InteractiveStrength = (config and config.InteractiveStrength) or DEFAULT_INTERACTIVE_STRENGTH,
		ShallowStrength = (config and config.ShallowStrength) or DEFAULT_SHALLOW_STRENGTH,
		ObstacleStrength = (config and config.ObstacleStrength) or DEFAULT_OBSTACLE_STRENGTH,
		MaxFoam = (config and config.MaxFoam) or DEFAULT_MAX_FOAM,
		Version = 0,
		MaxValue = 0,
		MaxTintValue = 0,
	}, WaterFoamBuffer) :: any

	return self :: WaterFoamBuffer
end

---@param x number
---@param y number
---@return number
function WaterFoamBuffer:GetIndex(x: number, y: number): number
	return IndexOf(
		self.Stride,
		math.clamp(math.floor(x + 0.5), 0, self.Resolution),
		math.clamp(math.floor(y + 0.5), 0, self.Resolution)
	)
end

---@param localX number
---@param localZ number
---@param radius number
---@param amount number
---@param tintAmount number?
function WaterFoamBuffer:AddFoam(localX: number, localZ: number, radius: number, amount: number, tintAmount: number?)
	local foamAmount = math.max(amount, 0)
	local greenAmount = math.max(tintAmount or 0, 0)

	if radius <= 0 or (foamAmount <= 0 and greenAmount <= 0) then
		return
	end

	local resolution = self.Resolution
	local gridX = (localX / self.SizeX + 0.5) * resolution
	local gridY = (localZ / self.SizeZ + 0.5) * resolution
	local cellSizeX = self.SizeX / resolution
	local cellSizeZ = self.SizeZ / resolution
	local cellRadiusX = radius / math.max(cellSizeX, 0.001)
	local cellRadiusY = radius / math.max(cellSizeZ, 0.001)
	local minX = math.clamp(math.floor(gridX - cellRadiusX - 1), 0, resolution)
	local maxX = math.clamp(math.ceil(gridX + cellRadiusX + 1), 0, resolution)
	local minY = math.clamp(math.floor(gridY - cellRadiusY - 1), 0, resolution)
	local maxY = math.clamp(math.ceil(gridY + cellRadiusY + 1), 0, resolution)
	local angle = Hash01(math.floor(gridX * 2), math.floor(gridY * 2)) * math.pi * 2
	local dirX = math.cos(angle)
	local dirY = math.sin(angle)

	for y = minY, maxY do
		for x = minX, maxX do
			local dx = (x - gridX) / math.max(cellRadiusX, 0.001)
			local dy = (y - gridY) / math.max(cellRadiusY, 0.001)
			local distance = math.sqrt(dx * dx + dy * dy)

			if distance <= 1 then
				local along = dx * dirX + dy * dirY
				local across = dx * (-dirY) + dy * dirX
				local filamentDistance = math.sqrt((along / 1.35) ^ 2 + (across * 1.85) ^ 2)
				local radialWeight = (1 - distance) ^ 2
				local filamentWeight = if filamentDistance <= 1 then (1 - filamentDistance) ^ 2 else 0
				local weight = math.max(radialWeight * 0.56, filamentWeight)
				local index = IndexOf(self.Stride, x, y)

				if foamAmount > 0 then
					local value = PackedFloatBuffer.read(self.Values, index) + foamAmount * weight
					local nextValue = math.clamp(value, 0, self.MaxFoam)

					PackedFloatBuffer.write(self.Values, index, nextValue)
					self.MaxValue = math.max(self.MaxValue, nextValue)
				end

				if greenAmount > 0 then
					local value = PackedFloatBuffer.read(self.TintValues, index) + greenAmount * weight
					local nextValue = math.clamp(value, 0, self.MaxFoam)

					PackedFloatBuffer.write(self.TintValues, index, nextValue)
					self.MaxTintValue = math.max(self.MaxTintValue, nextValue)
					self.MaxValue = math.max(self.MaxValue, nextValue)
				end
			end
		end
	end

	self.Version += 1
end

function WaterFoamBuffer:Clear()
	PackedFloatBuffer.fill(self.Values, self.Count, 0)
	PackedFloatBuffer.fill(self.TintValues, self.Count, 0)
	self.MaxValue = 0
	self.MaxTintValue = 0
	self.Version += 1
end

---@param buffer WaterBuffer?
---@param depthMap WaterDepthMap?
---@param obstacleMap WaterObstacleMap?
---@param dt number
---@param extraSampler SurfaceContributionSampler?
function WaterFoamBuffer:UpdateFromMaps(
	buffer: WaterBuffer?,
	depthMap: WaterDepthMap?,
	obstacleMap: WaterObstacleMap?,
	dt: number,
	extraSampler: SurfaceContributionSampler?
)
	self:UpdateRegionFromMaps(
		buffer,
		depthMap,
		obstacleMap,
		dt,
		-self.SizeX * 0.5,
		self.SizeX * 0.5,
		-self.SizeZ * 0.5,
		self.SizeZ * 0.5,
		3,
		extraSampler
	)
	self:RecalculateMax()
end

---@param buffer WaterBuffer?
---@param depthMap WaterDepthMap?
---@param obstacleMap WaterObstacleMap?
---@param dt number
---@param minX number
---@param maxX number
---@param minZ number
---@param maxZ number
---@param quality number 3 = crest/shore/obstacle, 2 = shore/obstacle, 1 = shore.
---@param extraSampler SurfaceContributionSampler?
function WaterFoamBuffer:UpdateRegionFromMaps(
	buffer: WaterBuffer?,
	depthMap: WaterDepthMap?,
	obstacleMap: WaterObstacleMap?,
	dt: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	quality: number,
	extraSampler: SurfaceContributionSampler?
)
	local resolution = self.Resolution
	local stride = self.Stride
	local decay = self.Decay * dt
	local growth = self.Growth * dt
	local gridMinX = math.clamp(math.floor((minX / self.SizeX + 0.5) * resolution), 0, resolution)
	local gridMaxX = math.clamp(math.ceil((maxX / self.SizeX + 0.5) * resolution), 0, resolution)
	local gridMinY = math.clamp(math.floor((minZ / self.SizeZ + 0.5) * resolution), 0, resolution)
	local gridMaxY = math.clamp(math.ceil((maxZ / self.SizeZ + 0.5) * resolution), 0, resolution)
	local maxValue = self.MaxValue
	local maxTintValue = self.MaxTintValue

	for y = gridMinY, gridMaxY do
		local localZ = (y / resolution - 0.5) * self.SizeZ

		for x = gridMinX, gridMaxX do
			local localX = (x / resolution - 0.5) * self.SizeX
			local index = IndexOf(stride, x, y)
			local function readCell(values: buffer, xx: number, yy: number): number
				local clampedX = math.clamp(xx, 0, resolution)
				local clampedY = math.clamp(yy, 0, resolution)
				return PackedFloatBuffer.read(values, IndexOf(stride, clampedX, clampedY))
			end

			local function dissipate(values: buffer): number
				local current = math.max(PackedFloatBuffer.read(values, index) - decay, 0)
				local left = readCell(values, x - 1, y)
				local right = readCell(values, x + 1, y)
				local down = readCell(values, x, y - 1)
				local up = readCell(values, x, y + 1)
				local downLeft = readCell(values, x - 1, y - 1)
				local upRight = readCell(values, x + 1, y + 1)
				local upLeft = readCell(values, x - 1, y + 1)
				local downRight = readCell(values, x + 1, y - 1)
				local neighborAvg = (left + right + down + up) * 0.25
				local diffusion = math.clamp(0.18 * dt, 0, 0.32)
				local cardinalBridge = math.max(math.min(left, right), math.min(down, up))
				local diagonalBridge = math.max(math.min(downLeft, upRight), math.min(upLeft, downRight))

				return math.max(
					current,
					neighborAvg * diffusion + current * (1 - diffusion),
					cardinalBridge * 0.78,
					diagonalBridge * 0.56
				)
			end

			local currentFoam = dissipate(self.Values)
			local currentTint = dissipate(self.TintValues)
			local targetFoam = 0
			local targetTint = 0

			-- Sum every continuous source into one surface field, then let the buffer handle dissipation.
			if depthMap ~= nil then
				targetFoam += depthMap:GetShoreFactor(localX, localZ) * self.ShallowStrength
			end

			if quality >= 2 and obstacleMap ~= nil then
				targetFoam += obstacleMap:GetFoamSeed(localX, localZ) * self.ObstacleStrength
			end

			if quality >= 3 and buffer ~= nil then
				local slope, velocity = buffer:SampleSurfaceActivity(localX, localZ)
				local slopeFoam = math.clamp((slope - self.SlopeThreshold) / math.max(self.SlopeThreshold, 0.001), 0, 1)
				local velocityFoam =
					math.clamp((velocity - self.VelocityThreshold) / math.max(self.VelocityThreshold * 2, 0.001), 0, 1)

				targetFoam += math.max(slopeFoam, velocityFoam) * self.InteractiveStrength
			end

			if extraSampler ~= nil then
				local extraFoam, extraTint = extraSampler(localX, localZ)

				targetFoam += math.clamp(extraFoam or 0, 0, self.MaxFoam)
				targetTint += math.clamp(extraTint or 0, 0, self.MaxFoam)
			end

			targetFoam = math.clamp(targetFoam, 0, self.MaxFoam)
			targetTint = math.clamp(targetTint, 0, self.MaxFoam)

			local nextValue = math.clamp(currentFoam + math.max(targetFoam - currentFoam, 0) * growth, 0, self.MaxFoam)
			local nextTintValue = math.clamp(currentTint + math.max(targetTint - currentTint, 0) * growth, 0, self.MaxFoam)

			PackedFloatBuffer.write(self.Values, index, nextValue)
			PackedFloatBuffer.write(self.TintValues, index, nextTintValue)
			maxValue = math.max(maxValue, nextValue)
			maxTintValue = math.max(maxTintValue, nextTintValue)
			maxValue = math.max(maxValue, nextTintValue)
		end
	end

	self.MaxValue = maxValue
	self.MaxTintValue = maxTintValue
	self.Version += 1
end

---@return number
function WaterFoamBuffer:RecalculateMax(): number
	local maxValue = 0
	local maxTintValue = 0

	for index = 1, self.Count do
		maxValue = math.max(maxValue, PackedFloatBuffer.read(self.Values, index))
		maxTintValue = math.max(maxTintValue, PackedFloatBuffer.read(self.TintValues, index))
	end

	self.MaxValue = math.max(maxValue, maxTintValue)
	self.MaxTintValue = maxTintValue

	return self.MaxValue
end

---@param localX number
---@param localZ number
---@return number
function WaterFoamBuffer:SampleFoam(localX: number, localZ: number): number
	local gridX = (localX / self.SizeX + 0.5) * self.Resolution
	local gridY = (localZ / self.SizeZ + 0.5) * self.Resolution

	return PackedFloatBuffer.sample(self.Values, self.Resolution, self.Stride, gridX, gridY)
end

---@param localX number
---@param localZ number
---@return number
function WaterFoamBuffer:SampleTint(localX: number, localZ: number): number
	local gridX = (localX / self.SizeX + 0.5) * self.Resolution
	local gridY = (localZ / self.SizeZ + 0.5) * self.Resolution

	return PackedFloatBuffer.sample(self.TintValues, self.Resolution, self.Stride, gridX, gridY)
end

return WaterFoamBuffer
