--!strict

local Players = game:GetService("Players")

local Types = require(script.Parent.Types)

type PhysicalContactOffset = Types.PhysicalContactOffset

local function isHumanoidRootOnly(part: BasePart, playerInteractionEnabled: boolean): boolean
	local model = part:FindFirstAncestorOfClass("Model")

	if model == nil then
		return true
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if humanoid == nil then
		return true
	end

	if Players:GetPlayerFromCharacter(model) ~= nil and not playerInteractionEnabled then
		return false
	end

	return part.Name == "HumanoidRootPart"
end

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / math.max(edge1 - edge0, 1e-6), 0, 1)

	return t * t * (3 - 2 * t)
end

local function getInteractionRadius(part: BasePart, scale: number): number
	local size = part.Size
	local horizontal = math.max(size.X, size.Z)
	local model = part:FindFirstAncestorOfClass("Model")
	local humanoid = if model ~= nil then model:FindFirstChildOfClass("Humanoid") else nil

	if humanoid ~= nil and part.Name == "HumanoidRootPart" then
		horizontal = math.max(horizontal, humanoid.HipHeight * 1.8, 5)
	end

	return math.clamp(horizontal * scale, 2.75, 42)
end

local function getPartBottom(part: BasePart): number
	local model = part:FindFirstAncestorOfClass("Model")
	local humanoid = if model ~= nil then model:FindFirstChildOfClass("Humanoid") else nil

	if humanoid ~= nil and part.Name == "HumanoidRootPart" then
		return part.Position.Y - humanoid.HipHeight - part.Size.Y * 0.5
	end

	return part.Position.Y - part.Size.Y * 0.5
end

local function getPhysicalAreaScale(part: BasePart, radius: number): number
	local footprint = math.sqrt(math.max(part.Size.X * part.Size.Z, radius * radius, 0.001))

	return math.clamp(footprint / 8, 0.35, 8)
end

local function getPhysicalReach(part: BasePart, radius: number): number
	local size = part.Size
	local halfDiagonal = math.sqrt(size.X * size.X + size.Z * size.Z) * 0.5

	return math.max(radius, halfDiagonal)
end

local function getWaterProxyCenter(center: Vector3, waterHeight: number, radius: number): Vector3
	local relativeY = math.clamp((center.Y - waterHeight) * 0.25, -radius * 0.45, radius * 0.45)

	return Vector3.new(center.X, waterHeight + relativeY, center.Z)
end

local function flattenDirection(vector: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)

	if flat.Magnitude > 0.001 then
		return flat.Unit
	end

	local fallbackFlat = Vector3.new(fallback.X, 0, fallback.Z)

	if fallbackFlat.Magnitude > 0.001 then
		return fallbackFlat.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function addPhysicalContactOffset(
	offsets: { PhysicalContactOffset },
	offset: Vector3,
	radiusScale: number,
	weight: number,
	splashWeight: number,
	wakeWeight: number
)
	for _, existing in ipairs(offsets) do
		if (existing.Offset - offset).Magnitude <= 0.75 then
			existing.Weight = math.max(existing.Weight, weight)
			existing.RadiusScale = math.max(existing.RadiusScale, radiusScale)
			existing.SplashWeight = math.max(existing.SplashWeight, splashWeight)
			existing.WakeWeight = math.max(existing.WakeWeight, wakeWeight)
			return
		end
	end

	table.insert(offsets, {
		Offset = offset,
		RadiusScale = radiusScale,
		Weight = weight,
		SplashWeight = splashWeight,
		WakeWeight = wakeWeight,
	})
end

local function getPhysicalContactOffsets(
	part: BasePart,
	velocity: Vector3,
	radius: number,
	includePerimeter: boolean
): { PhysicalContactOffset }
	local offsets: { PhysicalContactOffset } = {}
	local size = part.Size
	local halfX = size.X * 0.5
	local halfZ = size.Z * 0.5
	local footprint = math.max(size.X, size.Z)
	local isLarge = footprint >= math.max(radius * 1.3, 9)
	local right = flattenDirection(part.CFrame.RightVector, Vector3.new(1, 0, 0))
	local forward = flattenDirection(part.CFrame.LookVector, Vector3.new(0, 0, -1))
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local movingFast = horizontalVelocity.Magnitude >= 1.25
	local frontNormal = if movingFast then horizontalVelocity.Unit else forward
	local tangent = Vector3.new(-frontNormal.Z, 0, frontNormal.X)

	if tangent.Magnitude <= 0.001 then
		tangent = right
	else
		tangent = tangent.Unit
	end

	if isLarge then
		addPhysicalContactOffset(offsets, Vector3.zero, 0.62, 0.46, 0, 0.32)
	else
		addPhysicalContactOffset(offsets, Vector3.zero, 1, 1, 0.32, 0.48)
	end

	if movingFast or isLarge then
		local frontDistance = math.abs(frontNormal:Dot(right)) * halfX + math.abs(frontNormal:Dot(forward)) * halfZ
		local tangentExtent = math.abs(tangent:Dot(right)) * halfX + math.abs(tangent:Dot(forward)) * halfZ
		local frontCount = if tangentExtent >= 18 then 3 elseif tangentExtent >= 7 then 2 else 1

		if frontDistance > 1 then
			if frontCount == 1 then
				addPhysicalContactOffset(
					offsets,
					frontNormal * frontDistance * 0.88,
					0.48,
					if movingFast then 0.9 else 0.55,
					1,
					0.42
				)
			elseif frontCount == 2 then
				addPhysicalContactOffset(
					offsets,
					frontNormal * frontDistance * 0.88 + tangent * tangentExtent * 0.38,
					0.42,
					0.72,
					0.95,
					0.5
				)
				addPhysicalContactOffset(
					offsets,
					frontNormal * frontDistance * 0.88 - tangent * tangentExtent * 0.38,
					0.42,
					0.72,
					0.95,
					0.5
				)
			else
				addPhysicalContactOffset(offsets, frontNormal * frontDistance * 0.9, 0.4, 0.7, 1, 0.48)
				addPhysicalContactOffset(
					offsets,
					frontNormal * frontDistance * 0.88 + tangent * tangentExtent * 0.58,
					0.38,
					0.58,
					0.86,
					0.56
				)
				addPhysicalContactOffset(
					offsets,
					frontNormal * frontDistance * 0.88 - tangent * tangentExtent * 0.58,
					0.38,
					0.58,
					0.86,
					0.56
				)
			end
		end

		if movingFast and frontDistance > 1 then
			local wakeDistance = frontDistance * 0.74
			local wakeCount = if tangentExtent >= 16 then 3 elseif tangentExtent >= 6 then 2 else 1

			if wakeCount == 1 then
				addPhysicalContactOffset(offsets, -frontNormal * wakeDistance, 0.58, 0.18, 0, 1)
			elseif wakeCount == 2 then
				addPhysicalContactOffset(
					offsets,
					-frontNormal * wakeDistance + tangent * tangentExtent * 0.34,
					0.52,
					0.16,
					0,
					0.95
				)
				addPhysicalContactOffset(
					offsets,
					-frontNormal * wakeDistance - tangent * tangentExtent * 0.34,
					0.52,
					0.16,
					0,
					0.95
				)
			else
				addPhysicalContactOffset(offsets, -frontNormal * wakeDistance, 0.55, 0.16, 0, 1)
				addPhysicalContactOffset(
					offsets,
					-frontNormal * wakeDistance + tangent * tangentExtent * 0.55,
					0.46,
					0.14,
					0,
					0.9
				)
				addPhysicalContactOffset(
					offsets,
					-frontNormal * wakeDistance - tangent * tangentExtent * 0.55,
					0.46,
					0.14,
					0,
					0.9
				)
			end
		end
	end

	if includePerimeter and isLarge then
		addPhysicalContactOffset(offsets, right * halfX * 0.82, 0.4, 0.52, 0.22, 0.55)
		addPhysicalContactOffset(offsets, -right * halfX * 0.82, 0.4, 0.52, 0.22, 0.55)
		addPhysicalContactOffset(offsets, forward * halfZ * 0.82, 0.4, 0.52, 0.22, 0.55)
		addPhysicalContactOffset(offsets, -forward * halfZ * 0.82, 0.4, 0.52, 0.22, 0.55)

		if footprint >= 34 then
			addPhysicalContactOffset(offsets, right * halfX * 0.7 + forward * halfZ * 0.7, 0.34, 0.42, 0.16, 0.48)
			addPhysicalContactOffset(offsets, right * halfX * 0.7 - forward * halfZ * 0.7, 0.34, 0.42, 0.16, 0.48)
			addPhysicalContactOffset(offsets, -right * halfX * 0.7 + forward * halfZ * 0.7, 0.34, 0.42, 0.16, 0.48)
			addPhysicalContactOffset(offsets, -right * halfX * 0.7 - forward * halfZ * 0.7, 0.34, 0.42, 0.16, 0.48)
		end
	end

	return offsets
end

local function isBuoyancyCandidate(part: BasePart, playerInteractionEnabled: boolean): boolean
	if part.Anchored or part:GetAttribute("OceanIgnoreBuoyancy") == true then
		return false
	end

	local model = part:FindFirstAncestorOfClass("Model")
	local humanoid = if model ~= nil then model:FindFirstChildOfClass("Humanoid") else nil

	if humanoid ~= nil then
		return false
	end

	return isHumanoidRootOnly(part, playerInteractionEnabled)
end

local BUOYANCY_OFFSET_CACHE: { [string]: { Vector3 } } = {}

local function getBuoyancyOffsetCacheKey(size: Vector3): string
	return `{math.floor(size.X * 4 + 0.5)}:{math.floor(size.Y * 4 + 0.5)}:{math.floor(size.Z * 4 + 0.5)}`
end

local function getBuoyancyOffsets(part: BasePart): { Vector3 }
	local size = part.Size
	local cacheKey = getBuoyancyOffsetCacheKey(size)
	local cached = BUOYANCY_OFFSET_CACHE[cacheKey]

	if cached ~= nil then
		return cached
	end

	local horizontal = math.max(size.X, size.Z)
	local y = -size.Y * 0.45
	local offsets: { Vector3 }

	if horizontal < 8 then
		offsets = { Vector3.new(0, y, 0) }
		BUOYANCY_OFFSET_CACHE[cacheKey] = offsets
		return offsets
	end

	if horizontal < 22 then
		local x = size.X * 0.32
		local z = size.Z * 0.32

		offsets = {
			Vector3.new(-x, y, -z),
			Vector3.new(x, y, -z),
			Vector3.new(-x, y, z),
			Vector3.new(x, y, z),
		}
		BUOYANCY_OFFSET_CACHE[cacheKey] = offsets
		return offsets
	end

	local x = size.X * 0.38
	local z = size.Z * 0.38

	offsets = {
		Vector3.new(-x, y, -z),
		Vector3.new(0, y, -z),
		Vector3.new(x, y, -z),
		Vector3.new(-x, y, 0),
		Vector3.new(x, y, 0),
		Vector3.new(-x, y, z),
		Vector3.new(0, y, z),
		Vector3.new(x, y, z),
	}
	BUOYANCY_OFFSET_CACHE[cacheKey] = offsets
	return offsets
end

local function getContactRadius(part: BasePart, baseRadius: number, offset: PhysicalContactOffset): number
	local localFootprint = math.max(math.min(part.Size.X, part.Size.Z) * 0.55, 3)

	return math.clamp(math.min(baseRadius * offset.RadiusScale, localFootprint), 1.5, baseRadius)
end

return {
	isHumanoidRootOnly = isHumanoidRootOnly,
	smoothstep = smoothstep,
	getInteractionRadius = getInteractionRadius,
	getPartBottom = getPartBottom,
	getPhysicalAreaScale = getPhysicalAreaScale,
	getPhysicalReach = getPhysicalReach,
	getWaterProxyCenter = getWaterProxyCenter,
	flattenDirection = flattenDirection,
	getPhysicalContactOffsets = getPhysicalContactOffsets,
	isBuoyancyCandidate = isBuoyancyCandidate,
	getBuoyancyOffsets = getBuoyancyOffsets,
	getContactRadius = getContactRadius,
}
