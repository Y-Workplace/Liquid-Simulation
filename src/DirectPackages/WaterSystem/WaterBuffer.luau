--!strict

local PackedFloatBuffer = require(script.Parent.PackedFloatBuffer)

---@class WaterBufferConfig
---@field Resolution number? Number of cells per side.
---@field SizeX number? Surface width in studs.
---@field SizeZ number? Surface depth in studs.
---@field Damping number? Velocity attenuation per simulation step.
---@field DropRadiusCells number? Minimum drop radius in buffer cells.
---@field MaxHeight number? Height clamp in studs.
---@field MaxVelocity number? Velocity clamp in studs per step.
---@field MoveSphereScale number? Volume displacement multiplier.

export type WaterBufferConfig = {
	Resolution: number?,
	SizeX: number?,
	SizeZ: number?,
	Damping: number?,
	DropRadiusCells: number?,
	MaxHeight: number?,
	MaxVelocity: number?,
	MoveSphereScale: number?,
}

---@class WaterBuffer
---@field Resolution number
---@field Stride number
---@field SizeX number
---@field SizeZ number
---@field CellSizeX number
---@field CellSizeZ number
---@field Count number
---@field Height buffer
---@field Velocity buffer
---@field NormalX buffer
---@field NormalZ buffer
---@field _NextHeight buffer
---@field _NextVelocity buffer
---@field Damping number
---@field DropRadiusCells number
---@field MaxHeight number
---@field MaxVelocity number
---@field MoveSphereScale number
---@field Version number
---@field _HasActivity boolean
---@field _NormalVersion number
---@field _LeftColumnOffsets { number }
---@field _RightColumnOffsets { number }
---@field _DownRowOffsets { number }
---@field _UpRowOffsets { number }
---@field _NormalScaleX { number }
---@field _NormalScaleZ { number }
export type WaterBuffer = {
	Resolution: number,
	Stride: number,
	SizeX: number,
	SizeZ: number,
	CellSizeX: number,
	CellSizeZ: number,
	Count: number,
	Height: buffer,
	Velocity: buffer,
	NormalX: buffer,
	NormalZ: buffer,
	_NextHeight: buffer,
	_NextVelocity: buffer,
	Damping: number,
	DropRadiusCells: number,
	MaxHeight: number,
	MaxVelocity: number,
	MoveSphereScale: number,
	Version: number,
	_HasActivity: boolean,
	_NormalVersion: number,
	_LeftColumnOffsets: { number },
	_RightColumnOffsets: { number },
	_DownRowOffsets: { number },
	_UpRowOffsets: { number },
	_NormalScaleX: { number },
	_NormalScaleZ: { number },

	AddDrop: (self: WaterBuffer, localX: number, localZ: number, radius: number, strength: number) -> nil,
	AddDropNormalized: (self: WaterBuffer, x: number, z: number, radius: number, strength: number) -> nil,
	MoveSphere: (
		self: WaterBuffer,
		oldCenter: Vector3,
		newCenter: Vector3,
		radius: number,
		strengthScale: number?
	) -> nil,
	StepSimulation: (self: WaterBuffer, iterations: number?) -> nil,
	FadeActivity: (self: WaterBuffer, factor: number) -> nil,
	UpdateNormals: (self: WaterBuffer) -> nil,
	HasActivity: (self: WaterBuffer) -> boolean,
	SampleHeight: (self: WaterBuffer, localX: number, localZ: number) -> number,
	SampleVelocity: (self: WaterBuffer, localX: number, localZ: number) -> number,
	SampleNormal: (self: WaterBuffer, localX: number, localZ: number) -> Vector3,
	SampleSurfaceActivity: (self: WaterBuffer, localX: number, localZ: number) -> (number, number),
	SetHeight: (self: WaterBuffer, x: number, y: number, height: number) -> nil,
	Clear: (self: WaterBuffer) -> nil,
	GetIndex: (self: WaterBuffer, x: number, y: number) -> number,
}

local WaterBuffer = {}
WaterBuffer.__index = WaterBuffer

local DEFAULT_RESOLUTION = 128
local DEFAULT_SIZE = 128
local DEFAULT_DAMPING = 0.995
local DEFAULT_MAX_HEIGHT = 8
local DEFAULT_MAX_VELOCITY = 8
local DEFAULT_DROP_RADIUS_CELLS = 2.5
local DEFAULT_MOVE_SPHERE_SCALE = 0.1
local MAX_BUFFER_RESOLUTION = 256
local FLOAT_BYTES = 4
local ACTIVITY_EPSILON = 0.00025
local PI = math.pi

local function ClampResolution(resolution: number): number
	return math.clamp(math.floor(resolution), 8, MAX_BUFFER_RESOLUTION)
end

local function IndexOf(stride: number, x: number, y: number): number
	return y * stride + x + 1
end

---@param config WaterBufferConfig?
---@return WaterBuffer
function WaterBuffer.new(config: WaterBufferConfig?): WaterBuffer
	local resolution = ClampResolution((config and config.Resolution) or DEFAULT_RESOLUTION)
	local stride = resolution + 1
	local count = stride * stride
	local sizeX = (config and config.SizeX) or DEFAULT_SIZE
	local sizeZ = (config and config.SizeZ) or DEFAULT_SIZE
	local cellSizeX = sizeX / resolution
	local cellSizeZ = sizeZ / resolution
	local leftColumnOffsets = table.create(stride)
	local rightColumnOffsets = table.create(stride)
	local downRowOffsets = table.create(stride)
	local upRowOffsets = table.create(stride)
	local normalScaleX = table.create(stride)
	local normalScaleZ = table.create(stride)

	for x = 0, resolution do
		local leftX = if x > 0 then x - 1 else x
		local rightX = if x < resolution then x + 1 else x

		leftColumnOffsets[x + 1] = leftX * FLOAT_BYTES
		rightColumnOffsets[x + 1] = rightX * FLOAT_BYTES
		normalScaleX[x + 1] = -1 / math.max((rightX - leftX) * cellSizeX, 0.001)
	end

	for y = 0, resolution do
		local downY = if y > 0 then y - 1 else y
		local upY = if y < resolution then y + 1 else y

		downRowOffsets[y + 1] = downY * stride * FLOAT_BYTES
		upRowOffsets[y + 1] = upY * stride * FLOAT_BYTES
		normalScaleZ[y + 1] = -1 / math.max((upY - downY) * cellSizeZ, 0.001)
	end

	local self = setmetatable({
		Resolution = resolution,
		Stride = stride,
		SizeX = sizeX,
		SizeZ = sizeZ,
		CellSizeX = cellSizeX,
		CellSizeZ = cellSizeZ,
		Count = count,
		Height = PackedFloatBuffer.create(count),
		Velocity = PackedFloatBuffer.create(count),
		NormalX = PackedFloatBuffer.create(count),
		NormalZ = PackedFloatBuffer.create(count),
		_NextHeight = PackedFloatBuffer.create(count),
		_NextVelocity = PackedFloatBuffer.create(count),
		Damping = (config and config.Damping) or DEFAULT_DAMPING,
		DropRadiusCells = (config and config.DropRadiusCells) or DEFAULT_DROP_RADIUS_CELLS,
		MaxHeight = (config and config.MaxHeight) or DEFAULT_MAX_HEIGHT,
		MaxVelocity = (config and config.MaxVelocity) or DEFAULT_MAX_VELOCITY,
		MoveSphereScale = (config and config.MoveSphereScale) or DEFAULT_MOVE_SPHERE_SCALE,
		Version = 0,
		_HasActivity = false,
		_NormalVersion = -1,
		_LeftColumnOffsets = leftColumnOffsets,
		_RightColumnOffsets = rightColumnOffsets,
		_DownRowOffsets = downRowOffsets,
		_UpRowOffsets = upRowOffsets,
		_NormalScaleX = normalScaleX,
		_NormalScaleZ = normalScaleZ,
	}, WaterBuffer) :: any

	return self :: WaterBuffer
end

---@param x number Integer buffer x coordinate.
---@param y number Integer buffer y coordinate.
---@return number
function WaterBuffer:GetIndex(x: number, y: number): number
	return IndexOf(
		self.Stride,
		math.clamp(math.floor(x + 0.5), 0, self.Resolution),
		math.clamp(math.floor(y + 0.5), 0, self.Resolution)
	)
end

---@param x number Integer buffer x coordinate.
---@param y number Integer buffer y coordinate.
---@param height number New height in studs.
function WaterBuffer:SetHeight(x: number, y: number, height: number)
	local index = self:GetIndex(x, y)

	PackedFloatBuffer.write(self.Height, index, math.clamp(height, -self.MaxHeight, self.MaxHeight))
	self._HasActivity = true
	self.Version += 1
end

function WaterBuffer:Clear()
	PackedFloatBuffer.fill(self.Height, self.Count, 0)
	PackedFloatBuffer.fill(self.Velocity, self.Count, 0)
	PackedFloatBuffer.fill(self.NormalX, self.Count, 0)
	PackedFloatBuffer.fill(self.NormalZ, self.Count, 0)
	PackedFloatBuffer.fill(self._NextHeight, self.Count, 0)
	PackedFloatBuffer.fill(self._NextVelocity, self.Count, 0)

	self._HasActivity = false
	self._NormalVersion = -1
	self.Version += 1
end

---@param localX number Local X coordinate in studs.
---@param localZ number Local Z coordinate in studs.
---@param radius number Radius in studs.
---@param strength number Height impulse in studs.
function WaterBuffer:AddDrop(localX: number, localZ: number, radius: number, strength: number)
	if radius <= 0 or strength == 0 then
		return
	end

	local resolution = self.Resolution
	local gridX = (localX / self.SizeX + 0.5) * resolution
	local gridY = (localZ / self.SizeZ + 0.5) * resolution
	local minRadius = math.max(self.CellSizeX, self.CellSizeZ) * self.DropRadiusCells
	local effectiveRadius = math.max(radius, minRadius)
	local cellRadiusX = effectiveRadius / self.CellSizeX
	local cellRadiusY = effectiveRadius / self.CellSizeZ
	local minX = math.clamp(math.floor(gridX - cellRadiusX - 1), 0, resolution)
	local maxX = math.clamp(math.ceil(gridX + cellRadiusX + 1), 0, resolution)
	local minY = math.clamp(math.floor(gridY - cellRadiusY - 1), 0, resolution)
	local maxY = math.clamp(math.ceil(gridY + cellRadiusY + 1), 0, resolution)

	for y = minY, maxY do
		for x = minX, maxX do
			local dx = (x - gridX) * self.CellSizeX
			local dz = (y - gridY) * self.CellSizeZ
			local distance = math.sqrt(dx * dx + dz * dz)
			local drop = math.max(0, 1 - distance / effectiveRadius)

			if drop > 0 then
				drop = 0.5 - math.cos(drop * PI) * 0.5

				local index = IndexOf(self.Stride, x, y)
				local current = PackedFloatBuffer.read(self.Height, index)

				PackedFloatBuffer.write(self.Height, index, math.clamp(current + drop * strength, -self.MaxHeight, self.MaxHeight))
				self._HasActivity = true
			end
		end
	end

	self.Version += 1
end

---@param x number Normalized X coordinate in the WebGL Water range -1..1.
---@param z number Normalized Z coordinate in the WebGL Water range -1..1.
---@param radius number Normalized radius relative to the -1..1 plane.
---@param strength number Height impulse in studs.
function WaterBuffer:AddDropNormalized(x: number, z: number, radius: number, strength: number)
	self:AddDrop(x * self.SizeX * 0.5, z * self.SizeZ * 0.5, radius * math.max(self.SizeX, self.SizeZ) * 0.5, strength)
end

local function SphereVolumeAt(localX: number, localZ: number, center: Vector3, radius: number): number
	local dx = localX - center.X
	local dz = localZ - center.Z
	local horizontalDistance = math.sqrt(dx * dx + dz * dz)
	local t = horizontalDistance / math.max(radius, 0.001)

	if t > 1.35 then
		return 0
	end

	local verticalWeight = 1 - math.clamp((math.abs(center.Y) - radius * 0.15) / math.max(radius * 1.25, 0.001), 0, 1)

	if verticalWeight <= 0 then
		return 0
	end

	local dy = math.exp(-((t * 1.5) ^ 6)) * radius
	local ymin = math.min(0, center.Y - dy)
	local ymax = math.min(math.max(0, center.Y + dy), ymin + 2 * dy)

	return math.max(ymax - ymin, 0) * verticalWeight
end

---@param oldCenter Vector3 Previous sphere center in local surface space.
---@param newCenter Vector3 Current sphere center in local surface space.
---@param radius number Sphere radius in studs.
---@param strengthScale number? Optional volume displacement multiplier.
function WaterBuffer:MoveSphere(oldCenter: Vector3, newCenter: Vector3, radius: number, strengthScale: number?)
	if radius <= 0 then
		return
	end

	local resolution = self.Resolution
	local scale = (strengthScale or 1) * self.MoveSphereScale
	local centerX = (oldCenter.X + newCenter.X) * 0.5
	local centerZ = (oldCenter.Z + newCenter.Z) * 0.5
	local influenceRadius = radius * 1.45 + (Vector3.new(oldCenter.X, 0, oldCenter.Z) - Vector3.new(newCenter.X, 0, newCenter.Z)).Magnitude
	local gridX = (centerX / self.SizeX + 0.5) * resolution
	local gridY = (centerZ / self.SizeZ + 0.5) * resolution
	local cellRadiusX = math.max(influenceRadius / self.CellSizeX, self.DropRadiusCells)
	local cellRadiusY = math.max(influenceRadius / self.CellSizeZ, self.DropRadiusCells)
	local minX = math.clamp(math.floor(gridX - cellRadiusX - 1), 0, resolution)
	local maxX = math.clamp(math.ceil(gridX + cellRadiusX + 1), 0, resolution)
	local minY = math.clamp(math.floor(gridY - cellRadiusY - 1), 0, resolution)
	local maxY = math.clamp(math.ceil(gridY + cellRadiusY + 1), 0, resolution)

	for y = minY, maxY do
		local localZ = (y / resolution - 0.5) * self.SizeZ

		for x = minX, maxX do
			local localX = (x / resolution - 0.5) * self.SizeX
			local oldVolume = SphereVolumeAt(localX, localZ, oldCenter, radius)
			local newVolume = SphereVolumeAt(localX, localZ, newCenter, radius)
			local delta = (oldVolume - newVolume) * scale

			if delta ~= 0 then
				local index = IndexOf(self.Stride, x, y)
				local current = PackedFloatBuffer.read(self.Height, index)

				PackedFloatBuffer.write(self.Height, index, math.clamp(current + delta, -self.MaxHeight, self.MaxHeight))
				self._HasActivity = true
			end
		end
	end

	self.Version += 1
end

---@param iterations number? Number of WebGL-style water steps.
function WaterBuffer:StepSimulation(iterations: number?)
	if not self._HasActivity then
		return
	end

	local steps = math.max(1, math.floor(iterations or 1))
	local resolution = self.Resolution
	local stride = self.Stride
	local height = self.Height
	local velocity = self.Velocity
	local nextHeight = self._NextHeight
	local nextVelocity = self._NextVelocity
	local damping = self.Damping
	local maxHeight = self.MaxHeight
	local maxVelocity = self.MaxVelocity
	local leftColumnOffsets = self._LeftColumnOffsets
	local rightColumnOffsets = self._RightColumnOffsets
	local downRowOffsets = self._DownRowOffsets
	local upRowOffsets = self._UpRowOffsets
	local maxActivity = 0

	for _ = 1, steps do
		maxActivity = 0

		for y = 0, resolution do
			local rowOffset = y * stride * FLOAT_BYTES
			local downRowOffset = downRowOffsets[y + 1]
			local upRowOffset = upRowOffsets[y + 1]

			for x = 0, resolution do
				local offset = rowOffset + x * FLOAT_BYTES
				local oldHeight = buffer.readf32(height, offset)
				local leftOffset = leftColumnOffsets[x + 1]
				local rightOffset = rightColumnOffsets[x + 1]
				local average = (
					buffer.readf32(height, rowOffset + leftOffset)
					+ buffer.readf32(height, rowOffset + rightOffset)
					+ buffer.readf32(height, downRowOffset + x * FLOAT_BYTES)
					+ buffer.readf32(height, upRowOffset + x * FLOAT_BYTES)
				) * 0.25
				local currentVelocity = buffer.readf32(velocity, offset)
				local nextVel = math.clamp(
					(currentVelocity + (average - oldHeight) * 2) * damping,
					-maxVelocity,
					maxVelocity
				)
				local nextH = math.clamp(oldHeight + nextVel, -maxHeight, maxHeight)

				maxActivity = math.max(maxActivity, math.abs(nextH), math.abs(nextVel))
				buffer.writef32(nextVelocity, offset, nextVel)
				buffer.writef32(nextHeight, offset, nextH)
			end
		end

		buffer.copy(height, 0, nextHeight, 0, self.Count * FLOAT_BYTES)
		buffer.copy(velocity, 0, nextVelocity, 0, self.Count * FLOAT_BYTES)
	end

	if maxActivity <= ACTIVITY_EPSILON then
		PackedFloatBuffer.fill(height, self.Count, 0)
		PackedFloatBuffer.fill(velocity, self.Count, 0)
		PackedFloatBuffer.fill(self.NormalX, self.Count, 0)
		PackedFloatBuffer.fill(self.NormalZ, self.Count, 0)
		PackedFloatBuffer.fill(nextHeight, self.Count, 0)
		PackedFloatBuffer.fill(nextVelocity, self.Count, 0)
		self._HasActivity = false
	end

	self.Version += 1
end

function WaterBuffer:FadeActivity(factor: number)
	if not self._HasActivity then
		return
	end

	local scale = math.clamp(factor, 0, 1)

	if scale <= 0.001 then
		self:Clear()
		return
	end

	local maxActivity = 0

	for index = 0, self.Count - 1 do
		local offset = index * FLOAT_BYTES
		local height = buffer.readf32(self.Height, offset) * scale
		local velocity = buffer.readf32(self.Velocity, offset) * scale

		buffer.writef32(self.Height, offset, height)
		buffer.writef32(self.Velocity, offset, velocity)
		maxActivity = math.max(maxActivity, math.abs(height), math.abs(velocity))
	end

	if maxActivity <= ACTIVITY_EPSILON then
		self:Clear()
		return
	end

	self._NormalVersion = -1
	self.Version += 1
end

function WaterBuffer:UpdateNormals()
	if self._NormalVersion == self.Version then
		return
	end

	local resolution = self.Resolution
	local stride = self.Stride
	local height = self.Height
	local normalXBuffer = self.NormalX
	local normalZBuffer = self.NormalZ
	local leftColumnOffsets = self._LeftColumnOffsets
	local rightColumnOffsets = self._RightColumnOffsets
	local downRowOffsets = self._DownRowOffsets
	local upRowOffsets = self._UpRowOffsets
	local normalScaleX = self._NormalScaleX
	local normalScaleZ = self._NormalScaleZ

	for y = 0, resolution do
		local rowOffset = y * stride * FLOAT_BYTES
		local downRowOffset = downRowOffsets[y + 1]
		local upRowOffset = upRowOffsets[y + 1]
		local normalZScale = normalScaleZ[y + 1]

		for x = 0, resolution do
			local offset = rowOffset + x * FLOAT_BYTES
			local dx = buffer.readf32(height, rowOffset + rightColumnOffsets[x + 1])
				- buffer.readf32(height, rowOffset + leftColumnOffsets[x + 1])
			local dz = buffer.readf32(height, upRowOffset + x * FLOAT_BYTES)
				- buffer.readf32(height, downRowOffset + x * FLOAT_BYTES)

			buffer.writef32(normalXBuffer, offset, dx * normalScaleX[x + 1])
			buffer.writef32(normalZBuffer, offset, dz * normalZScale)
		end
	end

	self._NormalVersion = self.Version
end

function WaterBuffer:HasActivity(): boolean
	return self._HasActivity
end

---@param localX number Local X coordinate in studs.
---@param localZ number Local Z coordinate in studs.
---@return number
function WaterBuffer:SampleHeight(localX: number, localZ: number): number
	local gridX = (localX / self.SizeX + 0.5) * self.Resolution
	local gridY = (localZ / self.SizeZ + 0.5) * self.Resolution

	return PackedFloatBuffer.sample(self.Height, self.Resolution, self.Stride, gridX, gridY)
end

---@param localX number Local X coordinate in studs.
---@param localZ number Local Z coordinate in studs.
---@return number
function WaterBuffer:SampleVelocity(localX: number, localZ: number): number
	local gridX = (localX / self.SizeX + 0.5) * self.Resolution
	local gridY = (localZ / self.SizeZ + 0.5) * self.Resolution

	return PackedFloatBuffer.sample(self.Velocity, self.Resolution, self.Stride, gridX, gridY)
end

---@param localX number Local X coordinate in studs.
---@param localZ number Local Z coordinate in studs.
---@return Vector3
function WaterBuffer:SampleNormal(localX: number, localZ: number): Vector3
	local gridX = (localX / self.SizeX + 0.5) * self.Resolution
	local gridY = (localZ / self.SizeZ + 0.5) * self.Resolution
	local normalX = PackedFloatBuffer.sample(self.NormalX, self.Resolution, self.Stride, gridX, gridY)
	local normalZ = PackedFloatBuffer.sample(self.NormalZ, self.Resolution, self.Stride, gridX, gridY)

	return Vector3.new(normalX, 1, normalZ).Unit
end

---@param localX number Local X coordinate in studs.
---@param localZ number Local Z coordinate in studs.
---@return number slope Normalized horizontal normal magnitude.
---@return number velocity Absolute surface velocity.
function WaterBuffer:SampleSurfaceActivity(localX: number, localZ: number): (number, number)
	local gridX = (localX / self.SizeX + 0.5) * self.Resolution
	local gridY = (localZ / self.SizeZ + 0.5) * self.Resolution
	local normalX = PackedFloatBuffer.sample(self.NormalX, self.Resolution, self.Stride, gridX, gridY)
	local normalZ = PackedFloatBuffer.sample(self.NormalZ, self.Resolution, self.Stride, gridX, gridY)
	local rawSlope = math.sqrt(normalX * normalX + normalZ * normalZ)
	local slope = rawSlope / math.sqrt(rawSlope * rawSlope + 1)
	local velocity = math.abs(PackedFloatBuffer.sample(self.Velocity, self.Resolution, self.Stride, gridX, gridY))

	return slope, velocity
end

return WaterBuffer
