--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Types)
local Defaults = require(script.Parent.Defaults)
local AttributeUtils = require(script.Parent.AttributeUtils)

type PlayerSwimAnimationState = Types.PlayerSwimAnimationState

local DEFAULT_OPTIONS = Defaults.DEFAULT_OPTIONS :: any
local readFolderBoolean = AttributeUtils.readFolderBoolean
local readFolderNumber = AttributeUtils.readFolderNumber

local PlayerSurfaceController = {}

local function findPlayerCharacter(): Model?
	local playermodel = workspace:FindFirstChild("playermodel")

	if playermodel ~= nil and playermodel:IsA("Model") and playermodel:FindFirstChildOfClass("Humanoid") ~= nil then
		return playermodel
	end

	local player = Players.LocalPlayer

	if player ~= nil and player.Character ~= nil then
		return player.Character
	end

	return nil
end

local function findAnimationInFolder(character: Model, folderName: string, preferredNames: { string }): Animation?
	local animate = character:FindFirstChild("Animate")

	if animate == nil then
		return nil
	end

	local folder = animate:FindFirstChild(folderName)

	if folder == nil then
		return nil
	end

	for _, animationName in ipairs(preferredNames) do
		local animation = folder:FindFirstChild(animationName)

		if animation ~= nil and animation:IsA("Animation") then
			return animation
		end
	end

	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("Animation") then
			return descendant
		end
	end

	return nil
end

local function stopAnimationTrack(track: AnimationTrack?)
	if track == nil then
		return
	end

	pcall(function()
		if track.IsPlaying then
			track:Stop(0.18)
		end
	end)
end

local function playAnimationTrack(track: AnimationTrack?, speed: number)
	if track == nil then
		return
	end

	pcall(function()
		if not track.IsPlaying then
			track:Play(0.18)
		end

		track:AdjustSpeed(speed)
	end)
end

local function clearPlayerSwimForces(root: BasePart?)
	if root == nil then
		return
	end

	local velocity = root:FindFirstChild("WaterSwimVelocity")

	if velocity ~= nil then
		velocity:Destroy()
	end

	local gyro = root:FindFirstChild("WaterSwimGyro")

	if gyro ~= nil then
		gyro:Destroy()
	end
end

local function ensurePlayerSwimForces(root: BasePart): (BodyVelocity, BodyGyro)
	local velocity = root:FindFirstChild("WaterSwimVelocity")

	if velocity == nil or not velocity:IsA("BodyVelocity") then
		if velocity ~= nil then
			velocity:Destroy()
		end

		velocity = Instance.new("BodyVelocity")
		velocity.Name = "WaterSwimVelocity"
		velocity.P = 6000
		velocity.Parent = root
	end

	local gyro = root:FindFirstChild("WaterSwimGyro")

	if gyro == nil or not gyro:IsA("BodyGyro") then
		if gyro ~= nil then
			gyro:Destroy()
		end

		gyro = Instance.new("BodyGyro")
		gyro.Name = "WaterSwimGyro"
		gyro.P = 5000
		gyro.D = 160
		gyro.Parent = root
	end

	velocity.MaxForce = Vector3.new(1e8, 1e8, 1e8)
	gyro.MaxTorque = Vector3.new(1e8, 1e8, 1e8)

	return velocity, gyro
end

function PlayerSurfaceController.stopPlayerSwimAnimation(self: any)
	local state = self._PlayerSwimAnimationState

	if state == nil then
		return
	end

	stopAnimationTrack(state.SwimTrack)
	stopAnimationTrack(state.IdleTrack)
	self._PlayerSwimAnimationState = nil
end

function PlayerSurfaceController.setPlayerJumpBlocked(self: any, humanoid: Humanoid?, blocked: boolean)
	if humanoid == nil then
		self._PlayerJumpingWasEnabled = nil
		return
	end

	if blocked then
		if self._PlayerJumpingWasEnabled == nil then
			local ok, enabled = pcall(function()
				return humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
			end)

			self._PlayerJumpingWasEnabled = if ok then enabled else true
		end

		humanoid.Jump = false
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end)

		local state = humanoid:GetState()

		if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
			end)
		end
	else
		local previous = self._PlayerJumpingWasEnabled

		if previous ~= nil then
			pcall(function()
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, previous)
			end)
		end

		self._PlayerJumpingWasEnabled = nil
	end
end

function PlayerSurfaceController.clearPlayerSwimControl(self: any, humanoid: Humanoid?, root: BasePart?)
	PlayerSurfaceController.setPlayerJumpBlocked(self, humanoid, false)

	if humanoid ~= nil and self._PlayerWasSwimming then
		humanoid.PlatformStand = false
	end

	clearPlayerSwimForces(root)

	local previousRoot = self._PlayerSwimRoot

	if previousRoot ~= nil and previousRoot ~= root then
		clearPlayerSwimForces(previousRoot)
	end

	self._PlayerSwimRoot = nil
end

function PlayerSurfaceController.getPlayerSwimAnimationState(self: any, character: Model, humanoid: Humanoid): PlayerSwimAnimationState
	local animator = humanoid:FindFirstChildOfClass("Animator")

	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local state = self._PlayerSwimAnimationState

	if state ~= nil and state.Character == character and state.Animator == animator then
		return state
	end

	PlayerSurfaceController.stopPlayerSwimAnimation(self)

	local swimAnimation = findAnimationInFolder(character, "swim", { "Swim", "swim" })
	local idleAnimation = findAnimationInFolder(character, "swimidle", { "SwimIndle", "SwimIdle", "swimidle" })
	local swimTrack: AnimationTrack? = nil
	local idleTrack: AnimationTrack? = nil

	if swimAnimation ~= nil then
		local ok, track = pcall(function()
			return animator:LoadAnimation(swimAnimation)
		end)

		if ok and track ~= nil then
			swimTrack = track
			swimTrack.Priority = Enum.AnimationPriority.Movement
			swimTrack.Looped = true
		end
	end

	if idleAnimation ~= nil then
		local ok, track = pcall(function()
			return animator:LoadAnimation(idleAnimation)
		end)

		if ok and track ~= nil then
			idleTrack = track
			idleTrack.Priority = Enum.AnimationPriority.Idle
			idleTrack.Looped = true
		end
	end

	state = {
		Character = character,
		Animator = animator,
		SwimTrack = swimTrack,
		IdleTrack = idleTrack,
	}
	self._PlayerSwimAnimationState = state

	return state
end

function PlayerSurfaceController.setPlayerSwimAnimation(
	self: any,
	character: Model,
	humanoid: Humanoid,
	moving: boolean,
	speedScale: number
)
	local sourceFolder = self._SourceFolder

	if
		not readFolderBoolean(
			sourceFolder,
			"OceanPlayerSwimAnimationEnabled",
			self._Options.PlayerSwimAnimationEnabled ~= false
		)
	then
		PlayerSurfaceController.stopPlayerSwimAnimation(self)
		return
	end

	local state = PlayerSurfaceController.getPlayerSwimAnimationState(self, character, humanoid)

	if moving then
		playAnimationTrack(state.SwimTrack, math.clamp(0.55 + speedScale * 0.5, 0.45, 1.35))
		stopAnimationTrack(state.IdleTrack)
	else
		playAnimationTrack(state.IdleTrack, 1)
		stopAnimationTrack(state.SwimTrack)
	end
end

function PlayerSurfaceController.step(self: any, deltaTime: number)
	local sourceFolder = self._SourceFolder

	if
		not readFolderBoolean(
			sourceFolder,
			"OceanPlayerSurfaceFloatEnabled",
			self._Options.PlayerSurfaceFloatEnabled ~= false
		)
	then
		local character = findPlayerCharacter()
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		PlayerSurfaceController.clearPlayerSwimControl(self, humanoid, if root ~= nil and root:IsA("BasePart") then root else nil)
		PlayerSurfaceController.stopPlayerSwimAnimation(self)
		self._PlayerWasSwimming = false
		return
	end

	local character = findPlayerCharacter()
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil

	if character == nil or humanoid == nil or root == nil or not root:IsA("BasePart") then
		PlayerSurfaceController.clearPlayerSwimControl(self, nil, nil)
		PlayerSurfaceController.stopPlayerSwimAnimation(self)
		self._PlayerWasSwimming = false
		return
	end

	local waterHeight = self:GetHeight(root.Position, 1)

	if waterHeight == nil then
		PlayerSurfaceController.clearPlayerSwimControl(self, humanoid, root)

		if self._PlayerWasSwimming and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		PlayerSurfaceController.stopPlayerSwimAnimation(self)
		self._PlayerWasSwimming = false
		return
	end

	local head = character:FindFirstChild("Head")
	local headY = if head ~= nil and head:IsA("BasePart") then head.Position.Y else root.Position.Y + humanoid.HipHeight
	local rootHalfHeight = root.Size.Y * 0.5
	local influenceDepth = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanPlayerSurfaceInfluenceDepth",
			self._Options.PlayerSurfaceInfluenceDepth or DEFAULT_OPTIONS.PlayerSurfaceInfluenceDepth
		),
		0
	)
	local swimDepth = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanPlayerSwimDepth",
			self._Options.PlayerSwimDepth or DEFAULT_OPTIONS.PlayerSwimDepth
		),
		0
	)
	local surfaceOffset = readFolderNumber(
		sourceFolder,
		"OceanPlayerSurfaceOffset",
		self._Options.PlayerSurfaceOffset or DEFAULT_OPTIONS.PlayerSurfaceOffset
	)
	local smoothness = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanPlayerSurfaceSmoothness",
			self._Options.PlayerSurfaceSmoothness or DEFAULT_OPTIONS.PlayerSurfaceSmoothness
		),
		0.1
	)
	local maxVerticalSpeed = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanPlayerSurfaceMaxVerticalSpeed",
			self._Options.PlayerSurfaceMaxVerticalSpeed or DEFAULT_OPTIONS.PlayerSurfaceMaxVerticalSpeed
		),
		1
	)
	local movementThreshold = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanPlayerSwimMovementThreshold",
			self._Options.PlayerSwimMovementThreshold or DEFAULT_OPTIONS.PlayerSwimMovementThreshold
		),
		0
	)
	local rootBottomPosition = root.Position - Vector3.yAxis * rootHalfHeight
	local playerVolumeBottomPadding = math.max(influenceDepth + swimDepth, rootHalfHeight + 0.5)
	local playerInWaterVolume = self:IsPointInWaterVolume(root.Position, 0.35, playerVolumeBottomPadding)
		or self:IsPointInWaterVolume(rootBottomPosition, 0.35, playerVolumeBottomPadding)
		or (head ~= nil and head:IsA("BasePart") and self:IsPointInWaterVolume(head.Position, 0.05, playerVolumeBottomPadding))

	if not playerInWaterVolume then
		PlayerSurfaceController.clearPlayerSwimControl(self, humanoid, root)

		if self._PlayerWasSwimming and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		PlayerSurfaceController.stopPlayerSwimAnimation(self)
		self._PlayerWasSwimming = false
		return
	end

	local rootBottom = root.Position.Y - rootHalfHeight
	local rootDepth = waterHeight - root.Position.Y
	local headDepth = waterHeight - headY
	local targetY = waterHeight + surfaceOffset
	local surfaceError = targetY - root.Position.Y
	local waterTouchesRoot = waterHeight >= rootBottom - 0.15
	local maxSubmergeDepth = influenceDepth + swimDepth
	local inWaveBand = waterTouchesRoot
		or math.abs(surfaceError) <= influenceDepth
		or (rootDepth > 0 and rootDepth <= maxSubmergeDepth)

	if not inWaveBand and headDepth <= 0 then
		PlayerSurfaceController.clearPlayerSwimControl(self, humanoid, root)

		if self._PlayerWasSwimming and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		PlayerSurfaceController.stopPlayerSwimAnimation(self)
		self._PlayerWasSwimming = false
		return
	end

	if humanoid.Health <= 0 or humanoid.Sit then
		PlayerSurfaceController.clearPlayerSwimControl(self, humanoid, root)

		PlayerSurfaceController.stopPlayerSwimAnimation(self)
		self._PlayerWasSwimming = false
		return
	end

	local jumpAscendRequested = humanoid.Jump or UserInputService:IsKeyDown(Enum.KeyCode.Space)
	PlayerSurfaceController.setPlayerJumpBlocked(self, humanoid, true)

	if not humanoid.PlatformStand then
		humanoid.PlatformStand = true
	end

	local existingSwimVelocity = root:FindFirstChild("WaterSwimVelocity")
	local velocity = if existingSwimVelocity ~= nil and existingSwimVelocity:IsA("BodyVelocity")
		then existingSwimVelocity.Velocity
		else root.AssemblyLinearVelocity
	local waterVelocity = self:GetVelocity(root.Position) or Vector3.zero
	local buoyancyWindow = math.max(influenceDepth + swimDepth, 0.5)
	local deepAlpha = if rootDepth > swimDepth
		then math.clamp(1 - (rootDepth - swimDepth) / math.max(swimDepth * 2.5, 0.001), 0.18, 1)
		else 1
	local buoyancyAlpha = math.clamp(1 - math.abs(surfaceError) / buoyancyWindow, 0, 1) * deepAlpha

	local camera = workspace.CurrentCamera
	local cameraCFrame = if camera ~= nil then camera.CFrame else root.CFrame
	local cameraLook = cameraCFrame.LookVector
	local cameraForward = Vector3.new(cameraLook.X, 0, cameraLook.Z)
	local moveDir = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)

	if cameraForward.Magnitude > 0.001 then
		cameraForward = cameraForward.Unit
	end

	if moveDir.Magnitude > 1 then
		moveDir = moveDir.Unit
	end

	local moveMagnitude = math.clamp(moveDir.Magnitude, 0, 1)

	local swimSpeed = humanoid.WalkSpeed * 0.86
	local targetXZ = Vector3.new(moveDir.X, 0, moveDir.Z) * swimSpeed
	local lerpFactor = math.min(deltaTime * 8, 1)
	local newX = velocity.X + (targetXZ.X - velocity.X) * lerpFactor
	local newZ = velocity.Z + (targetXZ.Z - velocity.Z) * lerpFactor

	-- === MOVIMENTO VERTICAL ===
	local newY: number
	local verticalInput = 0

	if jumpAscendRequested then
		verticalInput += 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
		verticalInput -= 1
	end

	if verticalInput ~= 0 then
		local targetYInput = verticalInput * maxVerticalSpeed
		newY = velocity.Y + (targetYInput - velocity.Y) * math.min(deltaTime * 10, 1)
	elseif moveMagnitude > movementThreshold then
		local targetYInput = math.clamp(cameraLook.Y, -1, 1) * maxVerticalSpeed * moveMagnitude
		newY = velocity.Y + (targetYInput - velocity.Y) * math.min(deltaTime * 7, 1)
	elseif buoyancyAlpha > 0.01 then
		-- Perto da superfície: sistema de boiar controla Y
		local desiredY = waterVelocity.Y
			+ surfaceError * smoothness
			- velocity.Y * 0.35
		local targetYClamped = math.clamp(desiredY, -maxVerticalSpeed, maxVerticalSpeed)
		newY = velocity.Y + (targetYClamped - velocity.Y) * math.min(buoyancyAlpha, 1)
	else
		-- Submerso fundo: gravidade suave da água + preserva inércia
		local underwaterDrag = math.exp(-3.2 * deltaTime)
		local gravityPull = (-workspace.Gravity * 0.045) * deltaTime
		newY = math.clamp(velocity.Y * underwaterDrag + gravityPull, -maxVerticalSpeed * 0.55, maxVerticalSpeed)
	end

	local swimVelocity, swimGyro = ensurePlayerSwimForces(root)
	self._PlayerSwimRoot = root
	swimVelocity.Velocity = Vector3.new(newX, newY, newZ)
	root.AssemblyAngularVelocity *= 0.08

	local swimming = moveMagnitude > movementThreshold or verticalInput ~= 0
	local swimDirection = if swimming
		then Vector3.new(
			if moveDir.Magnitude > 0.05 then moveDir.X else cameraForward.X,
			if verticalInput ~= 0 then verticalInput * 0.55 else cameraLook.Y * moveMagnitude,
			if moveDir.Magnitude > 0.05 then moveDir.Z else cameraForward.Z
		)
		else cameraForward
	local lookDirection = if swimDirection.Magnitude > 0.001 then swimDirection.Unit else cameraForward

	if lookDirection.Magnitude > 0.001 then
		if swimming then
			swimGyro.CFrame = CFrame.lookAt(root.Position, root.Position + lookDirection, Vector3.yAxis)
				* CFrame.Angles(-math.rad(78), 0, 0)
		else
			swimGyro.CFrame = CFrame.lookAt(root.Position, root.Position + lookDirection, Vector3.yAxis)
		end
	end

	local horizontalVelocity = Vector3.new(newX, 0, newZ)
	local moving = swimming or horizontalVelocity.Magnitude > movementThreshold * 16
	local speedScale = math.clamp(horizontalVelocity.Magnitude / 24, 0, 1.5)

	PlayerSurfaceController.setPlayerSwimAnimation(self, character, humanoid, moving, speedScale)
	self._PlayerWasSwimming = true
end

function PlayerSurfaceController.cleanup(self: any)
	local character = findPlayerCharacter()
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil

	PlayerSurfaceController.clearPlayerSwimControl(self, humanoid, if root ~= nil and root:IsA("BasePart") then root else nil)
	PlayerSurfaceController.stopPlayerSwimAnimation(self)
	self._PlayerWasSwimming = false
end

return PlayerSurfaceController
