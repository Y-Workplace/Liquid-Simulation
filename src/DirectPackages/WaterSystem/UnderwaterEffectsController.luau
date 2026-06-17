--!strict

local Lighting = game:GetService("Lighting")

local Defaults = require(script.Parent.Defaults)
local AttributeUtils = require(script.Parent.AttributeUtils)

local DEFAULT_OPTIONS = Defaults.DEFAULT_OPTIONS :: any
local readFolderBoolean = AttributeUtils.readFolderBoolean
local readFolderNumber = AttributeUtils.readFolderNumber

local UnderwaterEffectsController = {}

function UnderwaterEffectsController.ensureCameraDropFolder(self: any, camera: Camera): Folder
	local folder = self._CameraDropFolder

	if folder == nil or folder.Parent ~= camera then
		if folder ~= nil then
			folder:Destroy()
		end

		folder = Instance.new("Folder")
		folder.Name = "WaterCameraDrops"
		folder.Parent = camera
		self._CameraDropFolder = folder
	end

	return folder
end

function UnderwaterEffectsController.spawnCameraDrops(self: any, camera: Camera)
	local sourceFolder = self._SourceFolder

	if not readFolderBoolean(sourceFolder, "OceanCameraDropsEnabled", self._Options.CameraDropsEnabled ~= false) then
		return
	end

	local folder = UnderwaterEffectsController.ensureCameraDropFolder(self, camera)
	local count = math.clamp(
		math.round(
			readFolderNumber(
				sourceFolder,
				"OceanCameraDropCount",
				self._Options.CameraDropCount or DEFAULT_OPTIONS.CameraDropCount
			)
		),
		1,
		32
	)
	local duration = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanCameraDropDuration",
			self._Options.CameraDropDuration or DEFAULT_OPTIONS.CameraDropDuration
		),
		0.1
	)

	for index = 1, count do
		local drop = Instance.new("Part")
		local angle = (index / count) * math.pi * 2 + math.random() * 0.75
		local radius = 0.34 + math.random() * 0.88
		local offset =
			Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * 0.72, -0.62 - math.random() * 0.24)

		drop.Name = "Drop"
		drop.Shape = Enum.PartType.Ball
		drop.Material = Enum.Material.Glass
		drop.Size = Vector3.one * (0.065 + math.random() * 0.075)
		drop.Transparency = 0.34
		drop.Anchored = true
		drop.CanCollide = false
		drop.CanQuery = false
		drop.CanTouch = false
		drop.CastShadow = false
		drop:SetAttribute("CreatedAt", self._UnderwaterTime or self._Time)
		drop:SetAttribute("Duration", duration)
		drop:SetAttribute("OffsetX", offset.X)
		drop:SetAttribute("OffsetY", offset.Y)
		drop:SetAttribute("OffsetZ", offset.Z)
		drop.CFrame = camera.CFrame * CFrame.new(offset)
		drop.Parent = folder
	end
end

function UnderwaterEffectsController.updateCameraDrops(self: any, camera: Camera)
	local folder = self._CameraDropFolder

	if folder == nil then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		if not child:IsA("BasePart") then
			continue
		end

		local createdAt = child:GetAttribute("CreatedAt")
		local duration = child:GetAttribute("Duration")
		local offsetX = child:GetAttribute("OffsetX")
		local offsetY = child:GetAttribute("OffsetY")
		local offsetZ = child:GetAttribute("OffsetZ")

		if
			type(createdAt) ~= "number"
			or type(duration) ~= "number"
			or type(offsetX) ~= "number"
			or type(offsetY) ~= "number"
			or type(offsetZ) ~= "number"
		then
			child:Destroy()
			continue
		end

		local alpha = math.clamp(((self._UnderwaterTime or self._Time) - createdAt) / math.max(duration, 0.001), 0, 1)

		if alpha >= 1 then
			child:Destroy()
			continue
		end

		child.Transparency = 0.34 + alpha * 0.66
		child.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY - alpha * 0.26, offsetZ)
	end
end

function UnderwaterEffectsController.step(self: any, deltaTime: number)
	local camera = workspace.CurrentCamera

	if camera == nil then
		return
	end

	self._UnderwaterTime = (self._UnderwaterTime or self._Time) + deltaTime
	UnderwaterEffectsController.updateCameraDrops(self, camera)

	local sourceFolder = self._SourceFolder
	local enabled = readFolderBoolean(
		sourceFolder,
		"OceanUnderwaterEffectsEnabled",
		self._Options.UnderwaterEffectsEnabled ~= false
	)
	local cameraPosition = camera.CFrame.Position
	local waterHeight = self:GetHeight(cameraPosition, 1)
	local cameraInVolume = self:IsPointInWaterVolume(cameraPosition, 0.05, 0)

	if waterHeight == nil or not cameraInVolume then
		if self._WasUnderwater then
			UnderwaterEffectsController.spawnCameraDrops(self, camera)
			self._UnderwaterDepth = 0
			self._WasUnderwater = false
			local existingCorrection = Lighting:FindFirstChild("WaterUnderwaterColor")
			if existingCorrection ~= nil and existingCorrection:IsA("ColorCorrectionEffect") then
				existingCorrection.Enabled = false
			end
			local existingBlur = Lighting:FindFirstChild("WaterUnderwaterBlur")
			if existingBlur ~= nil and existingBlur:IsA("BlurEffect") then
				existingBlur.Enabled = false
			end
			local existingDepthOfField = Lighting:FindFirstChild("WaterUnderwaterDepthOfField")
			if existingDepthOfField ~= nil and existingDepthOfField:IsA("DepthOfFieldEffect") then
				if self._OriginalDepthOfFieldEnabled ~= nil then
					existingDepthOfField.Enabled = self._OriginalDepthOfFieldEnabled
					existingDepthOfField.FocusDistance = self._OriginalDepthOfFieldFocusDistance
					existingDepthOfField.InFocusRadius = self._OriginalDepthOfFieldInFocusRadius
					existingDepthOfField.NearIntensity = self._OriginalDepthOfFieldNearIntensity
					existingDepthOfField.FarIntensity = 0
				else
					existingDepthOfField.Enabled = false
					existingDepthOfField.FarIntensity = 0
				end
				self._OriginalDepthOfFieldEnabled = nil
			end
			if self._OriginalFogColor ~= nil then
				Lighting.FogColor = self._OriginalFogColor
				Lighting.FogStart = self._OriginalFogStart
				Lighting.FogEnd = self._OriginalFogEnd
				self._OriginalFogColor = nil
			end
		end
		return
	end

	local depth = waterHeight - cameraPosition.Y
	local isUnderwater = enabled and depth > 0

	if self._WasUnderwater and not isUnderwater then
		UnderwaterEffectsController.spawnCameraDrops(self, camera)
	end

	self._WasUnderwater = isUnderwater

	local effectDepthStart = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanUnderwaterDepthStart",
			self._Options.UnderwaterDepthStart or DEFAULT_OPTIONS.UnderwaterDepthStart
		),
		0
	)
	local effectDepthFull = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanUnderwaterDepthFull",
			self._Options.UnderwaterDepthFull or DEFAULT_OPTIONS.UnderwaterDepthFull
		),
		effectDepthStart + 0.001
	)
	local target = if isUnderwater
		then math.clamp((depth - effectDepthStart) / math.max(effectDepthFull - effectDepthStart, 0.001), 0, 1)
		else 0
	local alpha = 1 - math.exp(-10 * deltaTime)

	self._UnderwaterDepth += (target - self._UnderwaterDepth) * alpha

	if self._UnderwaterDepth <= 0.001 and not isUnderwater then
		self._UnderwaterDepth = 0

		local existingCorrection = Lighting:FindFirstChild("WaterUnderwaterColor")

		if existingCorrection ~= nil and existingCorrection:IsA("ColorCorrectionEffect") then
			existingCorrection.Enabled = false
		end

		local existingBlur = Lighting:FindFirstChild("WaterUnderwaterBlur")

		if existingBlur ~= nil and existingBlur:IsA("BlurEffect") then
			existingBlur.Enabled = false
		end

		local existingDepthOfField = Lighting:FindFirstChild("WaterUnderwaterDepthOfField")

		if existingDepthOfField ~= nil and existingDepthOfField:IsA("DepthOfFieldEffect") then
			if self._OriginalDepthOfFieldEnabled ~= nil then
				existingDepthOfField.Enabled = self._OriginalDepthOfFieldEnabled
				existingDepthOfField.FocusDistance = self._OriginalDepthOfFieldFocusDistance
				existingDepthOfField.InFocusRadius = self._OriginalDepthOfFieldInFocusRadius
				existingDepthOfField.NearIntensity = self._OriginalDepthOfFieldNearIntensity
				existingDepthOfField.FarIntensity = 0
			else
				existingDepthOfField.Enabled = false
				existingDepthOfField.FarIntensity = 0
			end

			self._OriginalDepthOfFieldEnabled = nil
		end

		if self._OriginalFogColor ~= nil then
			Lighting.FogColor = self._OriginalFogColor
			Lighting.FogStart = self._OriginalFogStart
			Lighting.FogEnd = self._OriginalFogEnd
			self._OriginalFogColor = nil
		end

		return
	end

	local correction = Lighting:FindFirstChild("WaterUnderwaterColor")

	if correction == nil then
		correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "WaterUnderwaterColor"
		correction.Parent = Lighting
	end

	if correction:IsA("ColorCorrectionEffect") then
		correction.Enabled = self._UnderwaterDepth > 0.001
		correction.TintColor = Color3.fromRGB(185, 230, 255):Lerp(Color3.fromRGB(30, 96, 135), self._UnderwaterDepth)
		correction.Brightness = -0.04 - self._UnderwaterDepth * 0.16
		correction.Contrast = self._UnderwaterDepth * 0.08
		correction.Saturation = -self._UnderwaterDepth * 0.35
	end

	local blur = Lighting:FindFirstChild("WaterUnderwaterBlur")

	if blur == nil then
		blur = Instance.new("BlurEffect")
		blur.Name = "WaterUnderwaterBlur"
		blur.Parent = Lighting
	end

	if blur:IsA("BlurEffect") then
		blur.Enabled = self._UnderwaterDepth > 0.001
		blur.Size = self._UnderwaterDepth * 7
	end

	local depthOfFieldEnabled = readFolderBoolean(
		sourceFolder,
		"OceanUnderwaterDepthOfFieldEnabled",
		self._Options.UnderwaterDepthOfFieldEnabled ~= false
	)

	if depthOfFieldEnabled then
		local depthOfField = Lighting:FindFirstChild("WaterUnderwaterDepthOfField")

		if depthOfField == nil then
			depthOfField = Instance.new("DepthOfFieldEffect")
			depthOfField.Name = "WaterUnderwaterDepthOfField"
			depthOfField.Parent = Lighting
		end

		if depthOfField:IsA("DepthOfFieldEffect") then
			if self._OriginalDepthOfFieldEnabled == nil then
				self._OriginalDepthOfFieldEnabled = depthOfField.Enabled
				self._OriginalDepthOfFieldFocusDistance = depthOfField.FocusDistance
				self._OriginalDepthOfFieldInFocusRadius = depthOfField.InFocusRadius
				self._OriginalDepthOfFieldNearIntensity = depthOfField.NearIntensity
				self._OriginalDepthOfFieldFarIntensity = depthOfField.FarIntensity
			end

			depthOfField.Enabled = self._UnderwaterDepth > 0.001
			depthOfField.FocusDistance = readFolderNumber(
				sourceFolder,
				"OceanUnderwaterDepthOfFieldFocusDistance",
				self._Options.UnderwaterDepthOfFieldFocusDistance
					or DEFAULT_OPTIONS.UnderwaterDepthOfFieldFocusDistance
			)
			depthOfField.InFocusRadius = readFolderNumber(
				sourceFolder,
				"OceanUnderwaterDepthOfFieldInFocusRadius",
				self._Options.UnderwaterDepthOfFieldInFocusRadius
					or DEFAULT_OPTIONS.UnderwaterDepthOfFieldInFocusRadius
			)
			depthOfField.NearIntensity = self._UnderwaterDepth
				* readFolderNumber(
					sourceFolder,
					"OceanUnderwaterDepthOfFieldNearIntensity",
					self._Options.UnderwaterDepthOfFieldNearIntensity
						or DEFAULT_OPTIONS.UnderwaterDepthOfFieldNearIntensity
				)
			depthOfField.FarIntensity = self._UnderwaterDepth
				* readFolderNumber(
					sourceFolder,
					"OceanUnderwaterDepthOfFieldFarIntensity",
					self._Options.UnderwaterDepthOfFieldFarIntensity
						or DEFAULT_OPTIONS.UnderwaterDepthOfFieldFarIntensity
				)
		end
	else
		local depthOfField = Lighting:FindFirstChild("WaterUnderwaterDepthOfField")

		if depthOfField ~= nil and depthOfField:IsA("DepthOfFieldEffect") then
			if self._OriginalDepthOfFieldEnabled ~= nil then
				depthOfField.Enabled = self._OriginalDepthOfFieldEnabled
				depthOfField.FocusDistance = self._OriginalDepthOfFieldFocusDistance
				depthOfField.InFocusRadius = self._OriginalDepthOfFieldInFocusRadius
				depthOfField.NearIntensity = self._OriginalDepthOfFieldNearIntensity
				depthOfField.FarIntensity = 0
			else
				depthOfField.Enabled = false
				depthOfField.FarIntensity = 0
			end

			self._OriginalDepthOfFieldEnabled = nil
		end
	end

	if self._OriginalFogColor == nil then
		self._OriginalFogColor = Lighting.FogColor
		self._OriginalFogStart = Lighting.FogStart
		self._OriginalFogEnd = Lighting.FogEnd
	end

	local originalFogColor = self._OriginalFogColor or Lighting.FogColor

	Lighting.FogColor = originalFogColor:Lerp(Color3.fromRGB(28, 87, 124), self._UnderwaterDepth)
	Lighting.FogStart = self._OriginalFogStart + (0 - self._OriginalFogStart) * self._UnderwaterDepth
	Lighting.FogEnd = self._OriginalFogEnd
		+ (math.max(36, self._OriginalFogStart + 12) - self._OriginalFogEnd) * self._UnderwaterDepth
end
function UnderwaterEffectsController.cleanup(self: any)
	if self._CameraDropFolder then
		self._CameraDropFolder:Destroy()
		self._CameraDropFolder = nil
	end

	local correction = Lighting:FindFirstChild("WaterUnderwaterColor")

	if correction ~= nil then
		correction:Destroy()
	end

	local blur = Lighting:FindFirstChild("WaterUnderwaterBlur")

	if blur ~= nil then
		blur:Destroy()
	end

	if self._OriginalFogColor ~= nil then
		Lighting.FogColor = self._OriginalFogColor
		Lighting.FogStart = self._OriginalFogStart
		Lighting.FogEnd = self._OriginalFogEnd
		self._OriginalFogColor = nil
	end

	local depthOfField = Lighting:FindFirstChild("WaterUnderwaterDepthOfField")

	if depthOfField ~= nil and depthOfField:IsA("DepthOfFieldEffect") then
		if self._OriginalDepthOfFieldEnabled ~= nil then
			depthOfField.Enabled = self._OriginalDepthOfFieldEnabled
			depthOfField.FocusDistance = self._OriginalDepthOfFieldFocusDistance
			depthOfField.InFocusRadius = self._OriginalDepthOfFieldInFocusRadius
			depthOfField.NearIntensity = self._OriginalDepthOfFieldNearIntensity
			depthOfField.FarIntensity = 0
		else
			depthOfField:Destroy()
		end
	end

	self._OriginalDepthOfFieldEnabled = nil
	self._UnderwaterDepth = 0
	self._WasUnderwater = false
end

return UnderwaterEffectsController
