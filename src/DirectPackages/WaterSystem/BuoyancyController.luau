--!strict

local Defaults = require(script.Parent.Defaults)
local AttributeUtils = require(script.Parent.AttributeUtils)
local WaterSpatial = require(script.Parent.WaterSpatial)
local InteractionUtils = require(script.Parent.WaterInteractionUtils)

local DEFAULT_OPTIONS = Defaults.DEFAULT_OPTIONS :: any
local readFolderBoolean = AttributeUtils.readFolderBoolean
local readFolderNumber = AttributeUtils.readFolderNumber
local distanceToPart = WaterSpatial.distanceToPart
local smoothstep = InteractionUtils.smoothstep
local isBuoyancyCandidate = InteractionUtils.isBuoyancyCandidate
local getBuoyancyOffsets = InteractionUtils.getBuoyancyOffsets

local BuoyancyController = {}

function BuoyancyController.step(self: any, deltaTime: number)
	local sourceFolder = self._SourceFolder

	if not readFolderBoolean(sourceFolder, "OceanBuoyancyEnabled", self._Options.BuoyancyEnabled ~= false) then
		self._BuoyancyAccumulator = 0
		return
	end

	local scanInterval = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanBuoyancyScanInterval",
			self._Options.BuoyancyScanInterval or DEFAULT_OPTIONS.BuoyancyScanInterval
		),
		0.03
	)

	self._BuoyancyAccumulator += deltaTime

	if self._BuoyancyAccumulator < scanInterval then
		return
	end

	local stepDelta = self._BuoyancyAccumulator
	self._BuoyancyAccumulator = 0
	local stepTime = (self._BuoyancyTime or self._Time) + stepDelta
	self._BuoyancyTime = stepTime
	local maxTracked = math.clamp(
		math.round(
			readFolderNumber(
				sourceFolder,
				"OceanBuoyancyMaxParts",
				self._Options.BuoyancyMaxParts or DEFAULT_OPTIONS.BuoyancyMaxParts
			)
		),
		1,
		512
	)
	local overlapParams = OverlapParams.new()
	local excludes = {}

	if sourceFolder ~= nil then
		table.insert(excludes, sourceFolder)
	end

	if self._Container ~= nil then
		table.insert(excludes, self._Container)
	end

	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = excludes
	overlapParams.RespectCanCollide = false

	local visited: { [BasePart]: boolean } = {}
	local tracked = 0
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera ~= nil then camera.CFrame.Position else nil

	for sourcePart, tile in pairs(self._Tiles) do
		if tracked >= maxTracked then
			break
		end

		local tileConfig = self:_GetConfigForSource(sourcePart) or self._Config

		if tileConfig == nil then
			continue
		end

		local oceanFolder = self:_GetOceanFolderForSource(sourcePart) or sourceFolder

		if not readFolderBoolean(oceanFolder, "OceanBuoyancyEnabled", self._Options.BuoyancyEnabled ~= false) then
			continue
		end

		if cameraPosition ~= nil and distanceToPart(sourcePart, cameraPosition) > tileConfig.PhysicsDistance then
			continue
		end

		local strength = math.max(
			readFolderNumber(
				oceanFolder,
				"OceanBuoyancyStrength",
				self._Options.BuoyancyStrength or DEFAULT_OPTIONS.BuoyancyStrength
			),
			0
		)
		local damping = math.max(
			readFolderNumber(
				oceanFolder,
				"OceanBuoyancyDamping",
				self._Options.BuoyancyDamping or DEFAULT_OPTIONS.BuoyancyDamping
			),
			0
		)
		local linearDrag = math.max(
			readFolderNumber(
				oceanFolder,
				"OceanBuoyancyLinearDrag",
				self._Options.BuoyancyLinearDrag or DEFAULT_OPTIONS.BuoyancyLinearDrag
			),
			0
		)
		local angularDrag = math.max(
			readFolderNumber(
				oceanFolder,
				"OceanBuoyancyAngularDrag",
				self._Options.BuoyancyAngularDrag or DEFAULT_OPTIONS.BuoyancyAngularDrag
			),
			0
		)
		local impactSpeed = math.max(
			readFolderNumber(
				oceanFolder,
				"OceanPhysicalImpactSpeed",
				self._Options.PhysicalImpactSpeed or DEFAULT_OPTIONS.PhysicalImpactSpeed
			),
			1
		)
		local playerInteractionEnabled = readFolderBoolean(
			oceanFolder,
			"OceanPlayerInteractionEnabled",
			self._Options.PlayerInteractionEnabled ~= false
		)

		local queryCFrame = sourcePart.CFrame
		local querySize = Vector3.new(
			math.min(sourcePart.Size.X, math.max(tileConfig.PhysicsDistance * 2, 16)),
			math.max(sourcePart.Size.Y + 160, 160),
			math.min(sourcePart.Size.Z, math.max(tileConfig.PhysicsDistance * 2, 16))
		)

		if cameraPosition ~= nil then
			local cameraLocal = sourcePart.CFrame:PointToObjectSpace(cameraPosition)
			local halfSize = sourcePart.Size * 0.5
			local queryLocal = Vector3.new(
				math.clamp(cameraLocal.X, -halfSize.X, halfSize.X),
				0,
				math.clamp(cameraLocal.Z, -halfSize.Z, halfSize.Z)
			)

			queryCFrame = sourcePart.CFrame * CFrame.new(queryLocal)
		end

		local parts = workspace:GetPartBoundsInBox(queryCFrame, querySize, overlapParams)

		for _, part in ipairs(parts) do
			if tracked >= maxTracked then
				break
			end

			if visited[part] or not isBuoyancyCandidate(part, playerInteractionEnabled) then
				continue
			end

			visited[part] = true

			local offsets = getBuoyancyOffsets(part)
			local mass = math.max(part.AssemblyMass, 0.1)
			local submergedWeight = 0
			local sampleCount = #offsets
			local buoyancyDepth = math.clamp(part.Size.Y * 0.85, 0.75, 14)
			local gravity = workspace.Gravity
			local riseResponse = math.clamp(damping * 1.25 + strength * 0.08, 5, 22)
			local liftScale = math.clamp(0.92 + strength * 0.035, 1.05, 1.85)

			for _, offset in ipairs(offsets) do
				local samplePosition = part.CFrame:PointToWorldSpace(offset)

				if not tile:IsPointInWaterVolume(samplePosition, stepTime, 0.05, 0) then
					continue
				end

				local waterHeight = tile:GetHeightAt(samplePosition, stepTime, 1)

				if waterHeight == nil then
					continue
				end

				local depth = waterHeight - samplePosition.Y

				if depth <= 0 then
					continue
				end

				local pointVelocity = part:GetVelocityAtPosition(samplePosition)
				local waterVelocity = tile:GetVelocityAt(samplePosition, stepTime)
				local relativeY = pointVelocity.Y - waterVelocity.Y
				local depthAlpha = smoothstep(0, buoyancyDepth, depth)
				local targetRiseSpeed = math.clamp(depth * (1.15 + strength * 0.025), 0, 9.5)
					* smoothstep(0, 0.3, depthAlpha)
				local supportAcceleration = gravity * math.clamp(depthAlpha * liftScale, 0, liftScale)
				local accelerationY = (targetRiseSpeed - relativeY) * riseResponse + supportAcceleration
				local impactAlpha = smoothstep(impactSpeed, impactSpeed * 3.5, -relativeY)

				if impactAlpha > 0 then
					local impactCap = gravity * math.clamp(0.85 + depthAlpha * liftScale * 0.75, 1, liftScale + 0.35)
					local easedImpactCap = impactCap + (accelerationY - impactCap) * (1 - impactAlpha * 0.35)

					accelerationY = math.min(accelerationY, easedImpactCap)
				end

				if relativeY > targetRiseSpeed + 0.15 then
					accelerationY = math.min(accelerationY, -math.min(relativeY - targetRiseSpeed, 12) * damping)
				end

				local surfaceCap = gravity * math.clamp(0.25 + depthAlpha * liftScale, 0.65, liftScale + 0.45)
				local forceY = math.clamp(accelerationY, -gravity * 0.85, surfaceCap)

				if math.abs(forceY) > 0.001 then
					pcall(function()
						part:ApplyImpulseAtPosition(
							Vector3.yAxis * (forceY * mass * stepDelta / math.max(sampleCount, 1)),
							samplePosition
						)
					end)
				end

				submergedWeight += depthAlpha
			end

			local submersion = math.clamp(submergedWeight / math.max(sampleCount, 1), 0, 1)

			if submersion > 0 then
				pcall(function()
					local velocity = part.AssemblyLinearVelocity
					local verticalDragScale = if velocity.Y > 0 then 0.95 else 0.32
					local dragScale = math.min(linearDrag * submersion * stepDelta, 0.85)
					local dragImpulse = Vector3.new(
						-velocity.X,
						-velocity.Y * verticalDragScale,
						-velocity.Z
					) * (dragScale * mass)

					part:ApplyImpulse(dragImpulse)
					local currentAngular = part.AssemblyAngularVelocity
					local angularDecay = math.clamp(angularDrag * submersion * stepDelta * 2.8, 0, 0.92)
					local angularMagnitude = currentAngular.Magnitude
					local cappedAngular = if angularMagnitude > 10 then currentAngular.Unit * 10 else currentAngular

					part.AssemblyAngularVelocity = cappedAngular * (1 - angularDecay)
				end)

				tracked += 1
			end
		end
	end
end

return BuoyancyController
