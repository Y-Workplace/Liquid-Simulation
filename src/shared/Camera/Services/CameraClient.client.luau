--[[
	@class CameraService
	Handles camera behavior in Free and Orbital modes for Studio-like environment.
	Supports perspective toggling, mouse control, keyboard shortcuts, and focus on objects.
	Integrates with EventTree for reactive state management.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Required Modules
local EventTree = require(ReplicatedStorage.Packages.EventTree)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local LoggerSystem = require(ReplicatedStorage.Packages.LoggerSystem)
local ShortcutKeys = require(ReplicatedStorage.Packages.ShortcutKeys)
local EventCameraType = require(ReplicatedStorage.Shared.Camera.Types.Camera)

local eventCamera = EventTree.CameraService :: EventCameraType.CameraTree
local SwitchRender = EventTree.GridManager.SwitchRender.Callable
local GridRender = EventTree.GridManager.GetRender.Provider

-- Log system
local Logger = LoggerSystem.new("Camera")

-- Create shortcuts to avoid intensive lookups
local workspace = workspace -- Resolve LSP bug
local CFrame_new = CFrame.new
local CFrame_Angles = CFrame.Angles
local CFrame_lookAt = CFrame.lookAt
local Vector3_new = Vector3.new
local math_rad = math.rad
local math_clamp = math.clamp
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_deg = math.deg
local math_atan2 = math.atan2
local math_asin = math.asin
local math_tan = math.tan
local math_max = math.max

local dirMap = {
	X = Vector3_new(1, 0, 0),
	["-X"] = Vector3_new(-1, 0, 0),
	Y = Vector3_new(0, 1, 0),
	["-Y"] = Vector3_new(0, -1, 0),
	Z = Vector3_new(0, 0, 1),
	["-Z"] = Vector3_new(0, 0, -1),
}

-- Module Declaration
local CameraService = {}

--[[
	@private
	Snaps an angle to step grid on first use, then applies true incremental steps.
	Matches Blender incremental rotation behavior.

	@param angle number -- Current angle in degrees
	@param delta number -- Increment request (+step or -step)
	@param step number -- Step size (e.g. 15)
	@return number -- New angle
]]
local function SnapAngleDirectional(angle: number, delta: number, step: number): number
	step = math_abs(step)

	if math_abs(delta) < 1e-6 then
		return angle
	end

	-- Are we already snapped to grid?
	local r = angle % step
	if r < 0 then
		r += step
	end

	local snapped = r < 1e-4 or math_abs(r - step) < 1e-4

	if not snapped then
		-- First press: align to nearest grid in movement direction
		local k = angle / step

		if delta > 0 then
			return math_ceil(k) * step
		else
			return math_floor(k) * step
		end
	end

	-- Already aligned → apply true incremental step
	if delta > 0 then
		return angle + step
	else
		return angle - step
	end
end

--[[
	@method _ComputeTargetCFrame
	Computes the target camera CFrame based on direction presets or yaw/pitch offsets.
	Supports both Orbital and Free camera modes.
	Does not apply the transform directly — only calculates the result.

	@private
	@self CameraService
	@param direction string? -- Axis-aligned view direction ("X", "-X", "Y", "-Y", "Z", "-Z")
	@param yawOffset number? -- Additional yaw offset in degrees
	@param pitchOffset number? -- Additional pitch offset in degrees
	@return CFrame -- Computed target camera CFrame
]]
function CameraService._ComputeTargetCFrame(
	self: CameraService,
	direction: string?,
	yawOffset: number?,
	pitchOffset: number?
): CFrame
	local useDirection = direction ~= nil

	-- Base angles (snapshot)
	local targetYaw = self.xrot
	local targetPitch = self.yrot

	-- Incremental offsets
	local STEP = 15

	if not useDirection then
		if yawOffset then
			targetYaw = SnapAngleDirectional(targetYaw, -yawOffset, STEP)
		end

		if pitchOffset then
			targetPitch = SnapAngleDirectional(targetPitch, -pitchOffset, STEP)
		end
	end

	-- Direction-based snapping
	if useDirection then
		local baseDir = dirMap[direction]
		if not baseDir then
			Logger:Warn("[Camera] Invalid direction:", direction)
			return self.currentCamera.CFrame
		end

		local look = baseDir.Unit
		targetYaw = math_deg(math_atan2(-look.X, -look.Z)) + (yawOffset or 0)
		targetPitch = math_deg(math_asin(look.Y)) + (pitchOffset or 0)

		if self.mode == "Orbital" then
			local rotation = self:GetRotationCFrame()
			local distance = self.orthographic
					and self.fixedDistance * math_tan(math_rad(70 / 2)) / math_tan(math_rad(self.orthoFoV / 2))
				or self.fixedDistance
			local position = self.focusPoint - rotation.LookVector * distance
			self.targetYaw = targetYaw
			self.targetPitch = targetPitch
			return CFrame_lookAt(position, self.focusPoint, rotation.UpVector)
		end
	end

	-- Commit angles once
	self.targetYaw = targetYaw
	self.targetPitch = targetPitch

	local pos = self.currentCamera.CFrame.Position
	return CFrame_new(pos) * CFrame_Angles(0, math_rad(targetYaw), 0) * CFrame_Angles(math_rad(targetPitch), 0, 0)
end

function CameraService._ApplyTransition(self: CameraService, targetCFrame: CFrame, duration: number)
	if self._transitionConnection then
		self._transitionConnection:Disconnect()
		self._transitionConnection = nil
	end

	self._transitioning = true
	local startCFrame = self.currentCamera.CFrame
	local elapsed = 0

	self._transitionConnection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local alpha = math_clamp(elapsed / duration, 0, 1)
		local smoothAlpha = alpha * alpha * (3 - 2 * alpha)
		local lerped = startCFrame:Lerp(targetCFrame, smoothAlpha)
		self.currentCamera.CFrame = self:ApplyViewportOffset(lerped, self.focusPoint)

		if alpha >= 1 then
			if self._transitionConnection then
				self._transitionConnection:Disconnect()
			end
			self._transitioning = false
		end
	end)
end

--[[
  @private Applies smooth orbital angle transition

  @self CameraService
  @param startYaw: number
  @param startPitch: number
  @param targetYaw: number
	@param targetPitch: number
	@param duration: number
]]
function CameraService._ApplyOrbitalAngleTransition(
	self: CameraService,
	startYaw: number,
	startPitch: number,
	targetYaw: number,
	targetPitch: number,
	duration: number
)
	if self._transitionConnection then
		self._transitionConnection:Disconnect()
		self._transitionConnection = nil
	end

	self._transitioning = true
	local elapsed = 0

	self._transitionConnection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local alpha = math_clamp(elapsed / duration, 0, 1)
		local smooth = alpha * alpha * (3 - 2 * alpha)

		self.xrot = startYaw + (targetYaw - startYaw) * smooth
		self.yrot = startPitch + (targetPitch - startPitch) * smooth

		local rotation = self:GetRotationCFrame()
		local distance = self:GetEffectiveDistance()
		local position = self.focusPoint - rotation.LookVector * distance
		local base = CFrame_lookAt(position, self.focusPoint, rotation.UpVector)

		self.currentCamera.CFrame = self:ApplyViewportOffset(base, self.focusPoint)

		if alpha >= 1 then
			if self._transitionConnection then
				self._transitionConnection:Disconnect()
				self._transitionConnection = nil
			end
			self._transitioning = false

			self.xrot = self.targetYaw
			self.yrot = self.targetPitch
			self:OnCameraUpdate()
		end
	end)
end

function CameraService._GetForwardPoint(self: CameraService, distance: number): Vector3
	local camCF = self.currentCamera.CFrame
	return camCF.Position + camCF.LookVector * distance
end

--[[
	@private
	Smoothly moves the focus point from one position to another.
	The camera naturally follows because orbital recomputes every frame.

	@self CameraService
	@param from Vector3
	@param to Vector3
	@param duration number
]]
function CameraService._AnimateFocusPoint(self: CameraService, from: Vector3, to: Vector3, duration: number)
	if self._focusTransition then
		self._focusTransition:Disconnect()
		self._focusTransition = nil
	end

	local elapsed = 0
	self._transitioning = true

	self._focusTransition = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local alpha = math_clamp(elapsed / duration, 0, 1)
		local smooth = alpha * alpha * (3 - 2 * alpha)

		self.focusPoint = from:Lerp(to, smooth)
		self:OnCameraUpdate()

		if alpha >= 1 then
			if self._focusTransition then
				self._focusTransition:Disconnect()
				self._focusTransition = nil
			end
			self.focusPoint = to
			self:OnCameraUpdate()
			self._transitioning = false
		end
	end)
end

--[[
	@private
	Forces orbital camera to recompute position immediately
	after projection or distance changes.
]]
function CameraService._RefreshOrbitalPosition(self: CameraService)
	if self.mode ~= "Orbital" then
		return
	end

	local rotation = self:GetRotationCFrame()
	local distance = self:GetEffectiveDistance()
	local position = self.focusPoint - rotation.LookVector * distance
	local base = CFrame_lookAt(position, self.focusPoint, rotation.UpVector)

	self.currentCamera.CFrame = self:ApplyViewportOffset(base, self.focusPoint)
end

--[[
	@private
	Binds the CameraService.Init function to the EventTree callable.
]]
local function BindInit()
	type BindInit = { Init: (self: any) -> nil }
	local self: BindInit = CameraService :: BindInit
	eventCamera.Init.Callable:Register(function()
		self:Init()
	end)
end

--[[
  @private Pans the camera in Free mode based on yaw and pitch offsets

  @self CameraService
  @param yaw: number? -- Yaw offset
  @param pitch: number? -- Pitch offset
]]
function CameraService._PanFree(self: CameraService, yaw: number?, pitch: number?)
	local cam = self.currentCamera
	local cf = cam.CFrame

	local right = cf.RightVector
	local up = cf.UpVector

	local panSpeed = 2

	local dx = (yaw or 0) / 15
	local dy = (pitch or 0) / 15

	local offset = (right * -dx * panSpeed) + (up * dy * panSpeed)

	cam.CFrame = cf + offset
end

--[[
  @private
  Updates cached values for viewport-based calculations.

  @self CameraService
]]
function CameraService._UpdateViewportCache(self: CameraService)
	local cam = self.currentCamera
	local fovY = math_rad(cam.FieldOfView)

	self._cachedOffset = Vector2.new()
	self._cachedFrustumHeightFactor = 2 * math_tan(fovY / 2)
	self._cachedAspectRatio = cam.ViewportSize.X / cam.ViewportSize.Y

	local size = Vector2.one
	self._cachedInvSizeX = 1 / math_max(size.X, 1)
	self._cachedInvSizeY = 1 / math_max(size.Y, 1)

	self._cachedSensitivity = self.sensitivity
end

--[[
	@method Init
	Initializes camera system, creating camera instance and internal state.
	@self CameraService
]]
function CameraService.Init(self: CameraService)
	Logger:Info("[Camera] [Init] Initializing")

	self._janitor = Janitor.new()
	self.cameraRun = nil
	self.canBegan = nil
	self.canEnded = nil
	self.orthographic = false
	self.sensitivity = 0.4
	self.orthoFoV = 5
	self.removeOrthographicOnNextMove = false
	self.pitchLocked = false
	self.xrot = 0
	self.yrot = 0
	self.targetYaw = 0
	self.targetPitch = 0
	self._transitioning = false
	self.focusPoint = Vector3_new(0, 0, 0)
	self.fixedDistance = 20
	self.mode = "Free"
	self.duration = 0.2

	-- Camera
	self.currentCamera = Instance.new("Camera")
	self.currentCamera.Name = "StudioCam"
	self.currentCamera.CameraType = Enum.CameraType.Scriptable
	self.currentCamera.Parent = workspace.Movement

	self:BindEvent()
end

--[[
	@method BindEvent
	Binds providers, callables, and signals to EventTree.
	@self CameraService
]]
function CameraService.BindEvent(self: CameraService)
	Logger:Info("[CameraService] [BindEvent] Binding Events")

	-- Reactive state for selected object
	EventTree.Explorer.GetSelectedObject.Provider:Await(function(SelectedObject: { [number]: boolean? })
		self.SelectedObject = SelectedObject
	end)

	-- Camera Providers
	eventCamera.GetCamera.Provider:Register(function()
		return self.currentCamera
	end)

	eventCamera.GetFocusPoint.Provider:Register(function()
		return self:GetFocusPoint()
	end)

	eventCamera.GetOrthographicMode.Provider:Register(function()
		return self.orthographic
	end)

	eventCamera.GetMode.Provider:Register(function()
		return self.mode
	end)

	eventCamera.GetFixedDistance.Provider:Register(function()
		return self.fixedDistance
	end)

	eventCamera.GetCameraRotationAngles.Provider:Register(function()
		return self.xrot, self.yrot
	end)

	-- Callables (actions)
	eventCamera.Start.Callable:Register(function()
		self:Start()
	end)

	eventCamera.TogglePerspective.Callable:Register(function(state: boolean?, isRemovedOnTheNextMove: boolean?)
		self:TogglePerspective(state, isRemovedOnTheNextMove)
	end)

	eventCamera.ViewOrbitDirection.Callable:Register(
		function(direction: string?, yawOffset: number?, pitchOffset: number?)
			self:ViewOrbitDirection(direction, yawOffset, pitchOffset)
		end
	)

	eventCamera.ChangeFocusPointValue.Callable:Register(function(value: Vector3)
		self.focusPoint = value
	end)

	eventCamera.ChangeFixedDistanceValue.Callable:Register(function(value: number)
		self.fixedDistance = value
	end)

	eventCamera.ActiveFreeMode.Callable:Register(function()
		self:SetFreeMode()
	end)

	eventCamera.RequestRefresh.Callable:Register(function()
		self:OnCameraUpdate()
	end)
end

--[[
	@method Start
	Activates camera system: binds inputs, starts update loop, sets current camera.
	@self CameraService
]]
function CameraService.Start(self: CameraService)
	if self.canBegan or self.canEnded then
		Logger:Warn("[Camera] [Start] Bind Duplicating")
		return
	end
	self:SetShortcutKeys()
	self:BindConnections()
	workspace.CurrentCamera = self.currentCamera
	self:_UpdateViewportCache()
	self:OnCameraUpdate()
end

--[[
	@method Stop
	Stops camera system, removes connections and shortcuts.
	@self CameraService
]]
function CameraService.Stop(self: CameraService)
	Logger:Info("[Camera] [Unload] Unloading Connections")
	self:UnBindConnections()
end

--[[
	@method BindConnections
	Binds mouse input for camera rotation while right mouse button is held.
	@self CameraService
]]
function CameraService.BindConnections(self: CameraService)
	Logger:Info("[Camera] [BindConnections] Binding Connections")
	self.canBegan = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if input.UserInputType == Enum.UserInputType.MouseButton2 and not gameProcessedEvent then
			if self._transitioning then
				return
			end
			if self.removeOrthographicOnNextMove then
				self.removeOrthographicOnNextMove = false
				self:TogglePerspective(false)
			end

			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			if not self.cameraRun then
				self.cameraRun = "CameraService_OnCameraUpdate"
				RunService:BindToRenderStep(self.cameraRun, Enum.RenderPriority.Camera.Value, function()
					self:OnCameraUpdate()
				end)
			end
		end
	end)
	self.canEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			if self.cameraRun then
				RunService:UnbindFromRenderStep(self.cameraRun)
				self.cameraRun = nil
			end
		end
	end)
	self._janitor:Add(
		self.currentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
			self:_UpdateViewportCache()
		end),
		"Disconnect"
	)
	self._janitor:Add(
		self.currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_UpdateViewportCache()
		end),
		"Disconnect"
	)
end

--[[
	@method UnBindConnections
	Disconnects mouse input and stops camera render update.
	@self CameraService
]]
function CameraService.UnBindConnections(self: CameraService)
	Logger:Info("[Camera] [UnBindConnections] UnBinding Connections")
	if self.canBegan then
		self.canBegan:Disconnect()
		self.canBegan = nil
	end
	if self.canEnded then
		self.canEnded:Disconnect()
		self.canEnded = nil
	end
	if self.cameraRun then
		RunService:UnbindFromRenderStep(self.cameraRun)
		self.cameraRun = nil
	end
	self._janitor:Cleanup()
end

--[[
  @private
  Applies viewport offset to camera look direction so the visual center
  matches the editor viewport frame.

  @self: CameraService
  @param baseCFrame: CFrame
  @param targetPoint: Vector3
]]
function CameraService.ApplyViewportOffset(self: CameraService, baseCFrame: CFrame, targetPoint: Vector3): CFrame
	local offset = self._cachedOffset

	local distance = (baseCFrame.Position - targetPoint).Magnitude

	local frustumHeight = self._cachedFrustumHeightFactor * distance
	local frustumWidth = frustumHeight * self._cachedAspectRatio

	return baseCFrame
		+ (baseCFrame.RightVector * -offset.X * frustumWidth)
		+ (baseCFrame.UpVector * offset.Y * frustumHeight)
end

--[[
	@method OnCameraUpdate
	Main per-frame update method for camera rotation and position.
	@self CameraService
	@param Ignore boolean? If true, skips orthographic check.
]]
function CameraService.OnCameraUpdate(self: CameraService)
	local delta = UserInputService:GetMouseDelta()

	local nx = delta.X * self._cachedInvSizeX
	local ny = delta.Y * self._cachedInvSizeY

	local xrot = self.xrot
  xrot -= nx * self._cachedSensitivity

	local yrot = self.yrot
  yrot -= ny * self._cachedSensitivity

	if self.pitchLocked then
		local minPitch = -89
		local maxPitch = 89
		yrot = math_clamp(yrot, minPitch, maxPitch)
	end
	if self.mode == "Orbital" then
		local rotation = CFrame_Angles(0, math_rad(xrot), 0) * CFrame_Angles(math_rad(yrot), 0, 0)

		local direction = rotation.LookVector
		local distance = self:GetEffectiveDistance()

		local cameraPosition = self.focusPoint - direction * distance
		local up = rotation.UpVector

		local base = CFrame_lookAt(cameraPosition, self.focusPoint, up)
		self.currentCamera.CFrame = self:ApplyViewportOffset(base, self.focusPoint)
	else
		local pos = self.currentCamera.CFrame.Position

		local yawRotation = CFrame_Angles(0, math_rad(xrot), 0)

		local pitchRotation = CFrame_Angles(math_rad(yrot), 0, 0)

		local base = CFrame_new(pos) * yawRotation * pitchRotation
		self.currentCamera.CFrame = base
	end
  self.xrot = xrot
  self.yrot = yrot
end

--[[
	@method GetEffectiveDistance
	Returns camera distance factoring orthographic mode.
	@self CameraService
	@return number Effective distance for camera
]]
function CameraService.GetEffectiveDistance(self: CameraService): number
	if self.orthographic then
		return self.fixedDistance * math_tan(math_rad(70 / 2)) / math_tan(math_rad(self.orthoFoV / 2))
	end
	return self.fixedDistance
end

--[[
	@method GetRotationCFrame
	Returns rotation CFrame constructed from xrot and yrot.
	@self CameraService
	@return CFrame
]]
function CameraService.GetRotationCFrame(self: CameraService): CFrame
	return CFrame_Angles(0, math_rad(self.xrot), 0) * CFrame_Angles(math_rad(self.yrot), 0, 0)
end

--[[
	@method GetFocusPoint
	Returns the current camera focus point based on mode.
	@self CameraService
	@return Vector3
]]
function CameraService.GetFocusPoint(self: CameraService): Vector3
	if self.mode == "Orbital" then
		return self.focusPoint
	end

	return self.currentCamera.CFrame.Position
end

--[[
	@method TogglePerspective
	Switches camera between orthographic and perspective view.
	@self CameraService
	@param state boolean? Desired orthographic state
	@param isRemovedOnTheNextMove boolean? Remove orthographic after next move
]]
function CameraService.TogglePerspective(self: CameraService, state: boolean?, isRemovedOnTheNextMove: boolean?)
	if not self.orthographic and state and self.mode == "Orbital" then
		Logger:Info("[Camera] [TogglePerspective] Orthographic view activated")
		self.orthographic = true
		self.currentCamera.FieldOfView = 5

		-- Change button appearance to orthographic
		EventTree.ToolsDown.ToggleProjection.Callable:Call(true)
	elseif (self.orthographic and not state) or self.mode == "Free" then
		Logger:Info("[Camera] [TogglePerspective] Perspective view activated")
		self.orthographic = false
		self.currentCamera.FieldOfView = 70

		-- Change button appearance to perspective
		EventTree.ToolsDown.ToggleProjection.Callable:Call(false)
	end

	self:_UpdateViewportCache()
	self:_RefreshOrbitalPosition()

	if isRemovedOnTheNextMove then
		self.removeOrthographicOnNextMove = isRemovedOnTheNextMove
	end
end

-- Synchronizes camera to orbital mode
function CameraService.SyncFreeToOrbital(self: CameraService)
	Logger:Info("[Camera] [SyncFreeToOrbital] Synchronizing camera to orbital mode")
	local cam = self.currentCamera
	local camPos = cam.CFrame.Position
	local focus = self.focusPoint
	local direction = (focus - camPos).Unit
	local distance = (focus - camPos).Magnitude
	local flatDir = Vector3_new(direction.X, 0, direction.Z)
	local yaw = math_atan2(-flatDir.X, -flatDir.Z)
	local pitch = math_asin(direction.Y)
	local yawDeg = math_deg(yaw)
	local pitchDeg = math_deg(pitch)

	self.xrot = yawDeg
	self.yrot = pitchDeg
	self.targetYaw = yawDeg
	self.targetPitch = pitchDeg

	self.fixedDistance = distance
end

--[[
	@method ViewOrbitDirection
	Smoothly rotates the camera to a predefined direction or applies yaw/pitch offsets.
	Automatically adapts duration based on direction snapping or incremental rotation.

	@self CameraService
	@param direction string? -- Optional axis direction ("X", "-X", "Y", "-Y", "Z", "-Z")
	@param yawOffset number? -- Optional yaw offset in degrees
	@param pitchOffset number? -- Optional pitch offset in degrees
]]
function CameraService.ViewOrbitDirection(
	self: CameraService,
	direction: string?,
	yawOffset: number?,
	pitchOffset: number?
)
	local startYaw = self.xrot
	local startPitch = self.yrot

	local targetCFrame = self:_ComputeTargetCFrame(direction, yawOffset, pitchOffset)

	local targetYaw = self.targetYaw
	local targetPitch = self.targetPitch

	if self.mode == "Orbital" then
		local durationMultiplier = direction and 2 or 1
		self:_ApplyOrbitalAngleTransition(
			startYaw,
			startPitch,
			targetYaw,
			targetPitch,
			self.duration * durationMultiplier
		)
	else
		local durationMultiplier = direction and 2 or 1
		self:_ApplyTransition(targetCFrame, self.duration * durationMultiplier)
	end
end

-- Configures keyboard shortcuts for camera control
function CameraService.SetShortcutKeys(self: CameraService)
	Logger:Info("[Camera] [SetShortcutKeys] New Shortcuts")

	local shortcuts = {
		-- Toggle perspectiva + ViewOrbitDirection
		{ keys = { "KeypadOne" }, ignore = { "LeftControl" }, dir = "Z", grid = "XY" },
		{ keys = { "LeftControl", "KeypadOne" }, dir = "-Z", grid = "XY" },
		{ keys = { "LeftControl", "KeypadThree" }, dir = "X", grid = "YZ" },
		{ keys = { "KeypadThree" }, ignore = { "LeftControl" }, dir = "-X", grid = "YZ" },
		{ keys = { "KeypadSeven" }, ignore = { "LeftControl" }, dir = "-Y", grid = "XZ" },
		{ keys = { "LeftControl", "KeypadSeven" }, dir = "Y", grid = "XZ" },

		-- Orbit offsets (repeating)
		{ keys = { "KeypadEight" }, pitch = 15, grid = "XZ", repeating = true },
		{ keys = { "KeypadTwo" }, pitch = -15, grid = "XZ", repeating = true },
		{ keys = { "KeypadFour" }, yaw = 15, grid = "XZ", repeating = true },
		{ keys = { "KeypadSix" }, yaw = -15, grid = "XZ", repeating = true },

		-- Toggle orthographic
		{ keys = { "KeypadFive" }, toggleOrthographic = true },

		-- Flip view
		{ keys = { "KeypadNine" }, flipView = true },

		{
			keys = { "J" },
			action = function()
				self:SetFreeMode()
			end,
		},
	}

	for _, shortcut in ipairs(shortcuts) do
		self._janitor:Add(
			ShortcutKeys:Connect({
				keys = shortcut.keys,
				ignore = shortcut.ignore,
				repeating = shortcut.repeating,
				rate = shortcut.repeating and self.duration or nil,
				action = function()
					if shortcut.dir then
						self:TogglePerspective(true, true)
						self:ViewOrbitDirection(shortcut.dir)
						if GridRender:Get() ~= shortcut.grid then
							SwitchRender:Call(shortcut.grid)
						end
					elseif shortcut.yaw or shortcut.pitch then
						if self.mode == "Free" then
							self:_PanFree(shortcut.yaw, shortcut.pitch)
						else
							self:ViewOrbitDirection(nil, shortcut.yaw, shortcut.pitch)
						end
						if GridRender:Get() ~= shortcut.grid then
							SwitchRender:Call(shortcut.grid)
						end
					elseif shortcut.toggleOrthographic then
						self:TogglePerspective(not self.orthographic)
					elseif shortcut.flipView then
						local a = (self.yrot % 360 + 360) % 360
						if math_abs(a - 90) < 1 or math_abs(a - 270) < 1 then
							self.yrot += 180
						else
							self.xrot += 180
						end
						self:ViewOrbitDirection(nil)
					elseif shortcut.action then
						shortcut.action()
					end
				end,
			}),
			"Disconnect"
		)
	end
end

--[[
	@method SetFocusPoint
	Sets camera focus point and switches to orbital mode.
	@self CameraService
	@param point Vector3 Position to focus
]]
function CameraService.SetFocusPoint(self: CameraService, point: Vector3)
	Logger:Info("[Camera] [SetFocusPoint] Camera switched to Orbital mode")
	Logger:Info("[Camera] [SetFocusPoint] FocusPoint has been changed to the position:", tostring(point))

	if point == self.focusPoint and self.mode == "Orbital" then
		return
	end

	local tempFocus = self:_GetForwardPoint(self.fixedDistance)
	self.focusPoint = tempFocus
	self.mode = "Orbital"
	self:SyncFreeToOrbital()
	local focusTravelDuration = 0.35
	self:_AnimateFocusPoint(tempFocus, point, focusTravelDuration)

	-- Change button appearance to orbital mode
	EventTree.ToolsDown.ToggleCam.Callable:Call(true)
end

--[[
	@method SetFreeMode
	Switches camera to free mode.
	@self CameraService
]]
function CameraService.SetFreeMode(self: CameraService)
	Logger:Info("[Camera] [SetFocusPoint] Camera switched to Free mode")

	if self.orthographic then
		self:TogglePerspective(false)
	end

	self.mode = "Free"

	-- Change button appearance to perspective mode
	EventTree.ToolsDown.ToggleCam.Callable:Call(false)
end

BindInit()

-- Type Definitions
type CameraMode = "Free" | "Orbital"
export type CameraService = typeof(CameraService) & {
	_focusTransition: RBXScriptConnection?,
	cameraRun: string?,
	canBegan: RBXScriptConnection?,
	canEnded: RBXScriptConnection?,
	currentCamera: Camera,
	orthographic: boolean,
	sensitivity: number,
	orthoFoV: number,
	removeOrthographicOnNextMove: boolean,
	pitchLocked: boolean,
	xrot: number,
	yrot: number,
	targetYaw: number,
	targetPitch: number,
	_transitioning: boolean,
	focusPoint: Vector3,
	fixedDistance: number,
	mode: CameraMode,
	duration: number,
	SelectedObject: { [number]: boolean? },
	_transitionConnection: RBXScriptConnection?,
	_cachedFrustumHeightFactor: number,
	_cachedAspectRatio: number,
	_cachedOffset: Vector2,
	_janitor: Janitor.Janitor,
	_cachedInvSizeX: number,
	_cachedInvSizeY: number,
	_cachedSensitivity: number,
}
