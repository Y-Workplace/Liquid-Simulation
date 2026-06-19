--!strict

local Defaults = require(script.Parent.Defaults)
local AttributeUtils = require(script.Parent.AttributeUtils)
local WaterSpatial = require(script.Parent.WaterSpatial)
local InteractionUtils = require(script.Parent.WaterInteractionUtils)

local DEFAULT_OPTIONS = Defaults.DEFAULT_OPTIONS :: any
local readFolderBoolean = AttributeUtils.readFolderBoolean
local readFolderNumber = AttributeUtils.readFolderNumber
local distanceToPart = WaterSpatial.distanceToPart
local canAffectTileAt = WaterSpatial.canAffectTileAt
local isHumanoidRootOnly = InteractionUtils.isHumanoidRootOnly
local getInteractionRadius = InteractionUtils.getInteractionRadius
local getPartBottom = InteractionUtils.getPartBottom
local getPhysicalAreaScale = InteractionUtils.getPhysicalAreaScale
local getPhysicalReach = InteractionUtils.getPhysicalReach
local getWaterProxyCenter = InteractionUtils.getWaterProxyCenter
local flattenDirection = InteractionUtils.flattenDirection
local getPhysicalContactOffsets = InteractionUtils.getPhysicalContactOffsets
local getContactRadius = InteractionUtils.getContactRadius

local PhysicalInteractionController = {}

function PhysicalInteractionController.step(self: any, deltaTime: number)
	local config = self._Config
	local sourceFolder = self._SourceFolder

	if config == nil then
		return
	end

	local enabled = readFolderBoolean(
		sourceFolder,
		"OceanPhysicalInteractionEnabled",
		self._Options.PhysicalInteractionEnabled ~= false
	)

	if not enabled then
		table.clear(self._PhysicalStates)
		self._PhysicalAccumulator = 0
		return
	end

	local scanInterval = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanPhysicalScanInterval",
			self._Options.PhysicalScanInterval or DEFAULT_OPTIONS.PhysicalScanInterval
		),
		0.03
	)

	self._PhysicalAccumulator += deltaTime

	if self._PhysicalAccumulator < scanInterval then
		return
	end

	local stepDelta = self._PhysicalAccumulator
	self._PhysicalAccumulator = 0
	local stepTime = (self._PhysicalTime or self._Time) + stepDelta
	self._PhysicalTime = stepTime

	local maxTracked = math.clamp(
		math.round(
			readFolderNumber(
				sourceFolder,
				"OceanPhysicalMaxTrackedParts",
				self._Options.PhysicalMaxTrackedParts or DEFAULT_OPTIONS.PhysicalMaxTrackedParts
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
	local camera = self._Camera or workspace.CurrentCamera
	local cameraPosition = self._CameraPosition or (if camera ~= nil then camera.CFrame.Position else nil)

	for sourcePart, tile in pairs(self._Tiles) do
		if tracked >= maxTracked then
			break
		end

		local tileConfig = self:_GetConfigForSource(sourcePart) or config
		local oceanFolder = self:_GetOceanFolderForSource(sourcePart) or sourceFolder

		if not tileConfig.InteractiveWavesEnabled then
			continue
		end

		if
			not readFolderBoolean(
				oceanFolder,
				"OceanPhysicalInteractionEnabled",
				self._Options.PhysicalInteractionEnabled ~= false
			)
		then
			continue
		end

		if cameraPosition ~= nil and distanceToPart(sourcePart, cameraPosition) > tileConfig.PhysicsDistance then
			continue
		end

		local playerInteractionEnabled = readFolderBoolean(
			oceanFolder,
			"OceanPlayerInteractionEnabled",
			self._Options.PlayerInteractionEnabled ~= false
		)
		local minSpeed = math.max(
			readFolderNumber(
				oceanFolder,
				"OceanPhysicalMinSpeed",
				self._Options.PhysicalMinSpeed or DEFAULT_OPTIONS.PhysicalMinSpeed
			),
			0
		)
		local impactSpeed = math.max(
			readFolderNumber(
				oceanFolder,
				"OceanPhysicalImpactSpeed",
				self._Options.PhysicalImpactSpeed or DEFAULT_OPTIONS.PhysicalImpactSpeed
			),
			0.1
		)
		local radiusScale = math.max(
			readFolderNumber(
				oceanFolder,
				"OceanPhysicalRadiusScale",
				self._Options.PhysicalRadiusScale or DEFAULT_OPTIONS.PhysicalRadiusScale
			),
			0.05
		)

		local queryCFrame = sourcePart.CFrame
		local querySize = Vector3.new(
			math.min(sourcePart.Size.X, math.max(tileConfig.PhysicsDistance * 2, 16)),
			math.max(sourcePart.Size.Y + 96, 96),
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

			if visited[part] then
				continue
			end

			if part.Anchored or part:GetAttribute("OceanIgnorePhysicalInteraction") == true then
				continue
			end

			if not isHumanoidRootOnly(part, playerInteractionEnabled) then
				continue
			end

			local center = part.Position
			local radius = getInteractionRadius(part, radiusScale)
			local assemblyVelocity = part.AssemblyLinearVelocity
			local previous = self._PhysicalStates[part]
			local oldCenter = if previous ~= nil then previous.Center else center - assemblyVelocity * stepDelta
			local observedVelocity = if stepDelta > 0 then (center - oldCenter) / stepDelta else assemblyVelocity
			local velocity = if observedVelocity.Magnitude > assemblyVelocity.Magnitude
				then observedVelocity
				else assemblyVelocity
			local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
			local horizontalSpeed = horizontalVelocity.Magnitude
			local wakeDirection = flattenDirection(velocity, part.CFrame.LookVector)
			local contactOffsets = getPhysicalContactOffsets(part, velocity, radius, true)
			local overlapsTile = canAffectTileAt(sourcePart, tile, center, getPhysicalReach(part, radius))

			if not overlapsTile then
				for _, contact in ipairs(contactOffsets) do
					local sampleRadius = getContactRadius(part, radius, contact)

					if canAffectTileAt(sourcePart, tile, center + contact.Offset, sampleRadius) then
						overlapsTile = true
						break
					end
				end
			end

			if not overlapsTile then
				continue
			end

			local touchesWaterVolume = tile:IsPointInWaterVolume(center, stepTime, radius, 0)

			if not touchesWaterVolume then
				for _, contact in ipairs(contactOffsets) do
					if tile:IsPointInWaterVolume(center + contact.Offset, stepTime, getContactRadius(part, radius, contact), 0) then
						touchesWaterVolume = true
						break
					end
				end
			end

			if not touchesWaterVolume then
				continue
			end

			visited[part] = true

			local visualWaterHeight = tile:GetHeightAt(center, stepTime, 1)
			local baseWaterHeight = tile:GetBaseHeightAt(center)
			local bottom = getPartBottom(part)
			local verticalSize = math.max(part.Size.Y, radius * 1.5, 0.1)
			local speed = math.max(assemblyVelocity.Magnitude, observedVelocity.Magnitude)
			local lastSplashTime = if previous ~= nil then previous.LastSplashTime else -math.huge
			local lastWakeSplashTime = if previous ~= nil then previous.LastWakeSplashTime else -math.huge
			local proxyCenter = getWaterProxyCenter(center, baseWaterHeight, radius)
			local oldProxyCenter = if previous ~= nil
				then previous.ProxyCenter
				else getWaterProxyCenter(oldCenter, baseWaterHeight, radius)
			local oldBottom = if previous ~= nil then previous.Bottom else bottom
			local moved = (center - oldCenter).Magnitude
			local horizontalMoved = (Vector3.new(center.X, 0, center.Z) - Vector3.new(oldCenter.X, 0, oldCenter.Z)).Magnitude
			local nearSurface = bottom <= visualWaterHeight + radius and center.Y >= visualWaterHeight - verticalSize
			local areaScale = getPhysicalAreaScale(part, radius)

			if nearSurface and moved > 0.015 and speed >= minSpeed then
				local strengthScale = math.clamp(speed * 0.018 + areaScale * 0.12 + horizontalMoved * 0.025, 0.12, 6)
				local emitWakeSplash = horizontalSpeed >= math.max(impactSpeed * 0.28, 3)
					and stepTime - lastWakeSplashTime >= 0.08
				local emittedWakeSplash = false

				for _, contact in ipairs(contactOffsets) do
					local sampleRadius = getContactRadius(part, radius, contact)
					local samplePosition = center + contact.Offset

					if not canAffectTileAt(sourcePart, tile, samplePosition, sampleRadius) then
						continue
					end

					if not tile:IsPointInWaterVolume(samplePosition, stepTime, sampleRadius, 0) then
						continue
					end

					local sampleVisualWaterHeight = tile:GetHeightAt(samplePosition, stepTime, 1)
					local sampleBaseWaterHeight = tile:GetBaseHeightAt(samplePosition)
					local oldSamplePosition = oldCenter + contact.Offset
					local sampleProxyCenter = getWaterProxyCenter(samplePosition, sampleBaseWaterHeight, sampleRadius)
					local oldSampleProxyCenter = if contact.Offset.Magnitude <= 0.001
						then oldProxyCenter
						else getWaterProxyCenter(oldSamplePosition, sampleBaseWaterHeight, sampleRadius)

					tile:MoveSphere(
						oldSampleProxyCenter,
						sampleProxyCenter,
						sampleRadius,
						strengthScale * contact.Weight
					)

					if contact.WakeWeight > 0 then
						local foamAmount = math.clamp(
							(horizontalSpeed / math.max(impactSpeed, 0.1)) * 0.18 * areaScale * contact.WakeWeight
								+ contact.Weight * 0.035,
							0.025,
							0.9
						)
						local foamRadius = sampleRadius
							* math.clamp(1.25 + areaScale * 0.08 + contact.WakeWeight * 0.65, 1.35, 2.6)

						tile:AddFoam(
							Vector3.new(samplePosition.X, sampleVisualWaterHeight, samplePosition.Z),
							foamRadius,
							foamAmount
						)
					end

					if emitWakeSplash and contact.SplashWeight > 0 then
						local splashIntensity = math.clamp(
							(horizontalSpeed / math.max(impactSpeed, 0.1))
								* contact.SplashWeight
								* (0.18 + areaScale * 0.035),
							0.06,
							0.55
						)
						local splashRadius = sampleRadius * math.clamp(0.6 + areaScale * 0.035, 0.65, 1.2)

						tile:EmitSplash(
							Vector3.new(samplePosition.X, sampleVisualWaterHeight, samplePosition.Z),
							splashIntensity,
							splashRadius,
							wakeDirection
						)
						emittedWakeSplash = true
					end
				end

				if emittedWakeSplash then
					lastWakeSplashTime = stepTime
				end
			end

			if nearSurface then
				local contactFoamAmount = math.clamp(
					areaScale * 0.035 + math.clamp(horizontalSpeed / math.max(impactSpeed, 0.1), 0, 1.5) * 0.045,
					0.045,
					0.35
				)

				for _, contact in ipairs(contactOffsets) do
					local sampleRadius = getContactRadius(part, radius, contact)
					local samplePosition = center + contact.Offset

					if not canAffectTileAt(sourcePart, tile, samplePosition, sampleRadius) then
						continue
					end

					if not tile:IsPointInWaterVolume(samplePosition, stepTime, sampleRadius, 0) then
						continue
					end

					local contactWeight = math.clamp(
						contact.WakeWeight * 0.55 + contact.Weight * 0.28 + contact.SplashWeight * 0.12,
						0.16,
						1
					)
					local sampleVisualWaterHeight = tile:GetHeightAt(samplePosition, stepTime, 1)
					local foamRadius = sampleRadius * math.clamp(1 + areaScale * 0.05 + contactWeight * 0.45, 1.15, 2)

					tile:AddFoam(
						Vector3.new(samplePosition.X, sampleVisualWaterHeight, samplePosition.Z),
						foamRadius,
						contactFoamAmount * contactWeight
					)
				end
			end

			local downwardSpeed = math.max(-assemblyVelocity.Y, -observedVelocity.Y, 0)
			local crossedSurface = oldBottom > visualWaterHeight + 0.05 and bottom <= visualWaterHeight + radius * 0.1

			if
				nearSurface
				and (crossedSurface or downwardSpeed >= impactSpeed)
				and stepTime - lastSplashTime >= 0.18
			then
				local verticalScale = math.clamp(part.Size.Y / 8, 0.4, 6)
				local impactStrength = math.clamp(
					(downwardSpeed / impactSpeed) * 0.32 * areaScale + verticalScale * 0.08 + radius * 0.012,
					0.1,
					math.max(tileConfig.InteractiveMaxHeight * 0.8, 1)
				)
				local didEmitImpact = false

				for _, contact in ipairs(contactOffsets) do
					local sampleRadius = getContactRadius(part, radius, contact)
					local samplePosition = center + contact.Offset

					if not canAffectTileAt(sourcePart, tile, samplePosition, sampleRadius) then
						continue
					end

					if not tile:IsPointInWaterVolume(samplePosition, stepTime, sampleRadius, 0) then
						continue
					end

					local sampleVisualWaterHeight = tile:GetHeightAt(samplePosition, stepTime, 1)
					local impactPosition = Vector3.new(samplePosition.X, sampleVisualWaterHeight, samplePosition.Z)
					local impactRadius = sampleRadius * math.clamp(1.05 + areaScale * 0.04, 1.08, 1.5)
					local sampleStrength = math.clamp(
						impactStrength * contact.Weight,
						0.04,
						math.max(tileConfig.InteractiveMaxHeight * 0.65, 0.5)
					)

					tile:AddDrop(impactPosition, impactRadius, sampleStrength)
					didEmitImpact = true
				end

				if didEmitImpact then
					lastSplashTime = stepTime
				end
			end

			self._PhysicalStates[part] = {
				Center = center,
				ProxyCenter = proxyCenter,
				Bottom = bottom,
				Velocity = velocity,
				LastSplashTime = lastSplashTime,
				LastWakeSplashTime = lastWakeSplashTime,
			}
			tracked += 1
		end
	end

	for part in pairs(self._PhysicalStates) do
		if not visited[part] or part.Parent == nil then
			self._PhysicalStates[part] = nil
		end
	end
end

return PhysicalInteractionController
