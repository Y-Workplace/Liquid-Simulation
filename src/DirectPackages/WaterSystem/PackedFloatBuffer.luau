--!strict

local PackedFloatBuffer = {}

export type FloatBuffer = buffer

local FLOAT_BYTES = 4

---@param count number
---@return buffer
function PackedFloatBuffer.create(count: number): buffer
	return buffer.create(math.max(0, math.floor(count)) * FLOAT_BYTES)
end

---@param values buffer
---@param index number One-based float index.
---@return number
function PackedFloatBuffer.read(values: buffer, index: number): number
	return buffer.readf32(values, (index - 1) * FLOAT_BYTES)
end

---@param values buffer
---@param index number One-based float index.
---@param value number
function PackedFloatBuffer.write(values: buffer, index: number, value: number)
	buffer.writef32(values, (index - 1) * FLOAT_BYTES, value)
end

---@param values buffer
---@param count number
---@param value number?
function PackedFloatBuffer.fill(values: buffer, count: number, value: number?)
	local target = value or 0

	if target == 0 then
		buffer.fill(values, 0, 0, math.max(0, math.floor(count)) * FLOAT_BYTES)
		return
	end

	for index = 1, count do
		buffer.writef32(values, (index - 1) * FLOAT_BYTES, target)
	end
end

---@param source buffer
---@param target buffer
---@param count number
function PackedFloatBuffer.copy(source: buffer, target: buffer, count: number)
	buffer.copy(target, 0, source, 0, math.max(0, math.floor(count)) * FLOAT_BYTES)
end

---@param values buffer
---@param resolution number
---@param stride number
---@param gridX number
---@param gridY number
---@return number
function PackedFloatBuffer.sample(values: buffer, resolution: number, stride: number, gridX: number, gridY: number): number
	local clampedX = math.clamp(gridX, 0, resolution)
	local clampedY = math.clamp(gridY, 0, resolution)
	local x0 = math.floor(clampedX)
	local y0 = math.floor(clampedY)
	local x1 = math.min(x0 + 1, resolution)
	local y1 = math.min(y0 + 1, resolution)
	local tx = clampedX - x0
	local ty = clampedY - y0
	local row0 = y0 * stride * FLOAT_BYTES
	local row1 = y1 * stride * FLOAT_BYTES
	local h00 = buffer.readf32(values, row0 + x0 * FLOAT_BYTES)
	local h10 = buffer.readf32(values, row0 + x1 * FLOAT_BYTES)
	local h01 = buffer.readf32(values, row1 + x0 * FLOAT_BYTES)
	local h11 = buffer.readf32(values, row1 + x1 * FLOAT_BYTES)
	local top = h00 + (h10 - h00) * tx
	local bottom = h01 + (h11 - h01) * tx

	return top + (bottom - top) * ty
end

return PackedFloatBuffer
