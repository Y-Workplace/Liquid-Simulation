--!strict

local OceanTile = require(script.Parent.OceanTile)

local function isWaterPart(instance: Instance, sourceFolder: Instance?, container: Instance?): boolean
	if sourceFolder == nil then
		return false
	end

	if not instance:IsA("BasePart") then
		return false
	end

	if container ~= nil and instance:IsDescendantOf(container) then
		return false
	end

	return instance:IsDescendantOf(sourceFolder)
end

local function distanceToPart(sourcePart: BasePart, worldPosition: Vector3): number
	local localPosition = sourcePart.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = sourcePart.Size * 0.5
	local closestLocal = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	local closestWorld = sourcePart.CFrame:PointToWorldSpace(closestLocal)

	return (worldPosition - closestWorld).Magnitude
end

local function canAffectTileAt(
	sourcePart: BasePart,
	tile: OceanTile.OceanTile,
	worldPosition: Vector3,
	radius: number
): boolean
	return tile:ContainsWorldPosition(worldPosition) or distanceToPart(sourcePart, worldPosition) <= radius
end

return {
	isWaterPart = isWaterPart,
	distanceToPart = distanceToPart,
	canAffectTileAt = canAffectTileAt,
}
