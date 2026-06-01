-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Local References
local root = ReplicatedStorage.Shared.Movement

-- Required Modules
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Sift = require(ReplicatedStorage.Packages.Sift)
local EventTree = require(ReplicatedStorage.Packages.EventTree)
local ShortcutKeys = require(ReplicatedStorage.Packages.ShortcutKeys)
local KeyModule = require(root.Modules.Key)
local EventCameraType = require(ReplicatedStorage.Shared.Camera.Types.Camera)
local EventMovementType = require(ReplicatedStorage.Shared.Movement.Types.Movement)

local eventCamera = EventTree.CameraService :: EventCameraType.CameraTree
local eventMovement = EventTree.MovementService :: EventMovementType.MovementTree

-- Log system
local DEBUG = false
local Log, Warn
do
	if DEBUG then
		function Log(...)
			print(...)
		end
		function Warn(...)
			warn(...)
		end
	else
		function Log() end
		function Warn() end
	end
end

-- Module Declaration
local Movement = {}

local function BindInit()
	type BindInit = { Init: (self: any) -> nil }
	local self: BindInit = Movement :: BindInit
	eventMovement.Init.Callable:Register(function()
		self:Init()
	end)
end

-- Initializes submodules and binds input events
function Movement.Init(self: Movement)
	Log("[Movement] [Init] Initializing")

	-- Connections
	self._Janitor = Janitor.new()

	-- Key
	KeyModule:Init()
	self.move = nil

	-- Zoom
	self.zoomToMousePosition = true
	self.wheelPower = 3
	self.orthographyWheelPower = 2
	self.wheelInput = nil
	self.zoomBtn = false
	self.panZoomingForBtn = false

	self.panZooming = false
	self.lastMousePositionPanZoom = Vector2.new(0, 0)
	self.panZoomRun = nil
	self.panZoomBegan = nil
	self.panZoomEnded = nil

	-- Pan
	self.panSpeed = 0.1
	self.isPanning = false
	self.lastMousePosition = nil
	self.panRun = nil
	self.panBegan = nil
	self.panEnded = nil
	self.isPanningForBtn = false

	-- Shortcuts
	self.panDown = nil
	self.panLeft = nil
	self.panRight = nil
	self.panUp = nil

	self:BindEvent()
end

function Movement.BindEvent(self: Movement)
	Log("[Movement] [BindEvent] Binding Events")

	-- Reactive state for currentCamera
	eventCamera.GetCamera.Provider:Await(function(currentCamera: Camera)
		self.currentCamera = currentCamera
	end)

	-- Movement Providers
	eventMovement.GetZoomToMousePosition.Provider:Register(function()
		return self.zoomToMousePosition
	end)

	eventMovement.GetPanBtn.Provider:Register(function()
		return self.panBtn
	end)

	eventMovement.GetZoomBtn.Provider:Register(function()
		return self.zoomBtn
	end)

	-- Callables (actions)
	eventMovement.Start.Callable:Register(function()
		self:Start()
	end)

	eventMovement.SetZoomToMousePosition.Callable:Register(function(value: boolean)
		self.zoomToMousePosition = value
	end)

	eventMovement.SetPanBtn.Callable:Register(function(value: boolean)
		self.panBtn = value
	end)

	eventMovement.SetZoomBtn.Callable:Register(function(value: boolean)
		self.zoomBtn = value
	end)

	eventMovement.SetIsPanning.Callable:Register(function(value: boolean)
		self.isPanning = value
	end)

	eventMovement.SetIsPanningForBtn.Callable:Register(function(value: boolean)
		self.isPanningForBtn = value
	end)

	eventMovement.SetPanZooming.Callable:Register(function(value: boolean)
		self.panZooming = value
	end)

	eventMovement.SetPanZoomingForBtn.Callable:Register(function(value: boolean)
		self.panZoomingForBtn = value
	end)
end

-- Start input and camera systems
function Movement.Start(self: Movement)
	EventTree.GridManager.SwitchRender.Signal:Fire("XZ")

	-- Key
	Log("[Movement] [Start] Keyboard Keys")
	KeyModule:Start()

	Log("[Movement] [Start] New Shortcut")
	self.panDown = ShortcutKeys:Connect({
		keys = { "LeftControl", "KeypadTwo" },
		action = function()
			self:panCamera(Vector2.new(0, -15))
		end,
		repeating = true,
		rate = 0,
	})
	self.panLeft = ShortcutKeys:Connect({
		keys = { "LeftControl", "KeypadFour" },
		action = function()
			self:panCamera(Vector2.new(15, 0))
		end,
		repeating = true,
		rate = 0,
	})
	self.panRight = ShortcutKeys:Connect({
		keys = { "LeftControl", "KeypadSix" },
		action = function()
			self:panCamera(Vector2.new(-15, 0))
		end,
		repeating = true,
		rate = 0,
	})
	self.panUp = ShortcutKeys:Connect({
		keys = { "LeftControl", "KeypadEight" },
		action = function()
			self:panCamera(Vector2.new(0, 15))
		end,
		repeating = true,
		rate = 0,
	})

	self:BindConnections()
end

-- Stop and cleanup systems
function Movement.Stop(self: Movement)
	-- Key
	Log("[Movement] [Unload] Unloading Keyboard Keys")
	KeyModule:Stop()

	-- Pan
	Log("[Movement] [Unload] Unloading Pan")
	self.lastMousePosition = nil
	self.isPanning = false

	if self.panDown then
		self.panDown:Disconnect()
		self.panDown = nil
	end

	if self.panLeft then
		self.panLeft:Disconnect()
		self.panLeft = nil
	end

	if self.panRight then
		self.panRight:Disconnect()
		self.panRight = nil
	end

	if self.panUp then
		self.panUp:Disconnect()
		self.panUp = nil
	end

	self:UnBindConnections()
end

-- Bind Connections
function Movement.BindConnections(self: Movement)
	-- Zoom
	Log("[Movement] [BindConnections] Activating Zoom Bind")
	self._Janitor:Add(
		UserInputService.InputChanged:Connect(function(input)
			self:wheel(input)
		end),
		"Disconnect"
	)
	-- Pan
	Log("[Movement] [BindConnections] Activating Pan Began Bind")
	self._Janitor:Add(
		UserInputService.InputBegan:Connect(function(input)
			self:startPan(input)
		end),
		"Disconnect"
	)

	Log("[Movement] [BindConnections] Activating Pan Ended Bind")
	self._Janitor:Add(
		UserInputService.InputEnded:Connect(function(input)
			self:stopPan(input)
		end),
		"Disconnect"
	)

	-- Pan Zoom
	Log("[Movement] [BindConnections] Activating Pan Zoom Began Bind")
	self._Janitor:Add(
		UserInputService.InputBegan:Connect(function(input)
			self:StartPanZoom(input)
		end),
		"Disconnect"
	)

	Log("[Movement] [BindConnections] Activating Pan Zoom Ended Bind")
	self._Janitor:Add(
		UserInputService.InputEnded:Connect(function(input)
			self:StopPanZoom(input)
		end),
		"Disconnect"
	)

	-- Moviments
	Log("[Movement] [BindConnections] Activating Moviments")
	self._Janitor:Add(

		RunService.RenderStepped:Connect(function()
			self:startMoving()
		end),
		"Disconnect"
	)
end

-- Cleanup Connections
function Movement.UnBindConnections(self: Movement)
	-- Cleaning Janitor
	Log("[Movement] [UnBindConnections] All")
	self._Janitor:Cleanup()
end

-- Update zoom while holding PanZoom key
function Movement.UpdatePanZoom(self: Movement, mouseDeltaY: number, mousePosition: Vector2)
	if not self.panZooming or not self.lastMousePositionPanZoom then
		if self.panZoomRun then
			self.panZoomRun:Disconnect()
			self.panZoomRun = nil
		end
		return
	end

	local direction = -math.sign(mouseDeltaY)
	if direction == 0 then
		return
	end

	local fakeInput = {
		UserInputType = Enum.UserInputType.MouseWheel,
		Position = Vector3.new(0, 0, direction),
	}

	local mode = eventCamera.GetMode.Provider:Get()

	if mode == "Free" then
		if self.zoomToMousePosition then
			self:FreeZoomToMousePosition(fakeInput, mousePosition)
		else
			self:FreeZoomCentered(fakeInput)
		end
	else
		if self.zoomToMousePosition then
			self:OrbitalZoomToMousePosition(fakeInput, mousePosition)
		else
			self:OrbitalZoomCentered(fakeInput)
		end
	end
end

-- Start pan zoom mode (CTRL + MMB) or (Mouse + Btn)
function Movement.StartPanZoom(self: Movement, input: InputOrFakeInput)
	if
		(
			input.UserInputType == Enum.UserInputType.MouseButton3
			and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		) or (input.UserInputType == Enum.UserInputType.MouseButton1 and self.zoomBtn)
	then
		Log("[Movement] [StartPanZoom] Pan Zoom Starting")
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.zoomBtn then
			self.panZoomingForBtn = true
		end
		self.panZooming = true
		local mousePositionIn = UserInputService:GetMouseLocation()
		self.lastMousePositionPanZoom = mousePositionIn
		self.panZoomRun = RunService.RenderStepped:Connect(function()
			local mousePosition = UserInputService:GetMouseLocation()
			local deltaY: number = mousePosition.Y - self.lastMousePositionPanZoom.Y
			self.lastMousePositionPanZoom = mousePosition

			if math.abs(deltaY) > 0 then
				self:UpdatePanZoom(deltaY, mousePositionIn)
			end
		end)
	end
end

-- Stop pan zoom
function Movement.StopPanZoom(self: Movement, input: InputOrFakeInput)
	if
		(input.UserInputType == Enum.UserInputType.MouseButton3)
		or (input.UserInputType == Enum.UserInputType.MouseButton1 and self.panZooming)
	then
		Log("[Movement] [StopPanZoom] Pan Zoom Stopped")
		self.panZooming = false
		self.panZoomingForBtn = false
	end
end

-- Free mode zoom to cursor
function Movement.FreeZoomToMousePosition(self: Movement, input: InputOrFakeInput, isMousePosition: Vector2?)
	local direction = -math.sign(input.Position.Z)
	if direction == 0 then
		return
	end

	local OrthographyMode = eventCamera.GetOrthographicMode.Provider:Get()
	local mousePosition = isMousePosition or UserInputService:GetMouseLocation()
	local rayOrigin = self.currentCamera.CFrame.Position
	local rayDirection = self.currentCamera:ScreenPointToRay(mousePosition.X, mousePosition.Y).Direction.Unit
		* -(OrthographyMode and self.wheelPower * self.orthographyWheelPower or self.wheelPower)
		* direction
	local newPosition = rayOrigin + rayDirection
	self.currentCamera.CFrame = CFrame.new(newPosition, newPosition + self.currentCamera.CFrame.LookVector)
end

-- Free mode zoom centered
function Movement.FreeZoomCentered(self: Movement, input: InputOrFakeInput)
	local direction = -math.sign(input.Position.Z)
	if direction == 0 then
		return
	end

	local OrthographyMode = eventCamera.GetOrthographicMode.Provider:Get()
	local zoomAmount = -(OrthographyMode and self.wheelPower * self.orthographyWheelPower or self.wheelPower)
		* direction
	local forward = self.currentCamera.CFrame.LookVector
	local newPosition = self.currentCamera.CFrame.Position + forward * zoomAmount
	self.currentCamera.CFrame = CFrame.new(newPosition, newPosition + forward)
end

-- Orbit mode zoom to cursor
function Movement.OrbitalZoomToMousePosition(self: Movement, input: InputOrFakeInput, isMousePosition: Vector2?)
	local direction = -math.sign(input.Position.Z)
	if direction == 0 then
		return
	end

	local OrthographyMode = eventCamera.GetOrthographicMode.Provider:Get()
	local currentDistance = eventCamera.GetFixedDistance.Provider:Get()
	local newDistance = math.clamp(currentDistance + direction, 0.5, 500)
	local distanceChange = newDistance - currentDistance
	local mousePosition: Vector2 = isMousePosition or UserInputService:GetMouseLocation()
	local rayDirection = self.currentCamera:ScreenPointToRay(mousePosition.X, mousePosition.Y).Direction.Unit
		* -(OrthographyMode and self.wheelPower * self.orthographyWheelPower or self.wheelPower)
	local offset = rayDirection * distanceChange

	local FocusPointValue: Vector3 = eventCamera.GetFocusPoint.Provider:Get()
	eventCamera.ChangeFocusPointValue.Callable:Call(FocusPointValue + offset)
	eventCamera.ChangeFixedDistanceValue.Callable:Call(newDistance)
	eventCamera.RequestRefresh.Callable:Call(true)
end

-- Orbit mode zoom centered
function Movement.OrbitalZoomCentered(self: Movement, input: InputOrFakeInput)
	local direction = -math.sign(input.Position.Z)
	if direction == 0 then
		return
	end

	local OrthographyMode = eventCamera.GetOrthographicMode.Provider:Get()
	local fixedDistance = eventCamera.GetFixedDistance.Provider:Get()
	local distance: number = fixedDistance
		+ (OrthographyMode and self.wheelPower * self.orthographyWheelPower or self.wheelPower) * direction

	eventCamera.ChangeFixedDistanceValue.Callable:Call(math.clamp(distance, 0.5, 500))
	eventCamera.RequestRefresh.Callable:Call(true)
end

-- Handle wheel zoom
function Movement.wheel(self: Movement, input: InputOrFakeInput)
	local mode = eventCamera.GetMode.Provider:Get()

	if mode == "Free" then
		if self.zoomToMousePosition then
			self:FreeZoomToMousePosition(input)
		else
			self:FreeZoomCentered(input)
		end
	elseif self.zoomToMousePosition then
		self:OrbitalZoomToMousePosition(input)
	else
		self:OrbitalZoomCentered(input)
	end
end

-- Start panning
function Movement.startPan(self: Movement, input: InputOrFakeInput)
	if
		(
			input.UserInputType == Enum.UserInputType.MouseButton3
			and not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		) or (input.UserInputType == Enum.UserInputType.MouseButton1 and self.panBtn)
	then
		Log("[Movement] [startPan] Pan Starting")
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isPanningForBtn = true
		end
		self.isPanning = true
		self.lastMousePosition = UserInputService:GetMouseLocation()

		self.panRun = RunService.RenderStepped:Connect(function()
			self:panCamera(nil)
		end)
	end
end

-- Stop panning
function Movement.stopPan(self: Movement, input: InputOrFakeInput)
	local allowed = { Enum.UserInputType.MouseButton3, Enum.UserInputType.MouseButton1 }

	if Sift.Array.includes(allowed, input.UserInputType) and self.isPanning then
		Log("[Movement] [stopPan] Pan Stopped")
		self.isPanning = false
		self.isPanningForBtn = false
		self.lastMousePosition = nil
	end
end

-- Apply pan movement
function Movement.panCamera(self: Movement, value: Vector2?)
	if (not self.isPanning or not self.lastMousePosition) and not value then
		if self.panRun then
			self.panRun:Disconnect()
			self.panRun = nil
		end
		return
	end

	local delta

	if not value then
		local currentMousePosition = UserInputService:GetMouseLocation()
		delta = (currentMousePosition - self.lastMousePosition)
		self.lastMousePosition = currentMousePosition
	else
		delta = value
		self.lastMousePosition = nil
	end

	local mode = eventCamera.GetMode.Provider:Get()

	if mode == "Free" then
		local moveX = (-delta.X * self.panSpeed)
		local moveY = (delta.Y * self.panSpeed)
		local cameraCFrame = self.currentCamera.CFrame
		local rightVector = cameraCFrame.RightVector
		local upVector = cameraCFrame.UpVector
		self.currentCamera.CFrame = cameraCFrame + (rightVector * moveX) + (upVector * moveY)
	else
		local deltaX = -delta.X * self.panSpeed
		local deltaY = delta.Y * self.panSpeed
		local xRot, yRot = eventCamera.GetCameraRotationAngles.Provider:Get()
		local rotation = CFrame.fromOrientation(math.rad(yRot), math.rad(xRot), 0)

		local rightVector = rotation.RightVector
		local upVector = rotation.UpVector
		local focusPoint = eventCamera.GetFocusPoint.Provider:Get()
		eventCamera.ChangeFocusPointValue.Callable:Call(focusPoint + (rightVector * deltaX) + (upVector * deltaY))
		eventCamera.RequestRefresh.Callable:Call(true)
	end
end

-- Apply camera movement with WASD or arrow keys
function Movement.startMoving(self: Movement)
	local mode = eventCamera.GetMode.Provider:Get()

	if not UserInputService:GetFocusedTextBox() then
		local moveVector = Vector3.new(KeyModule.axis.X.active, KeyModule.axis.Y.active, KeyModule.axis.Z.active)

		if moveVector.Magnitude == 0 then
			return
		end

		local speed = KeyModule.ftnSpeed * 0.5

		self.currentCamera.CFrame *= CFrame.new(moveVector.X * speed, 0, moveVector.Z * speed)

		if moveVector.Y ~= 0 then
			local offset = Vector3.new(0, moveVector.Y * speed, 0)
			self.currentCamera.CFrame += offset
		end

		if mode ~= "Free" then
			eventCamera.ActiveFreeMode.Callable:Call()
		end
	end
end

BindInit()

-- Type Definitions
export type Movement = typeof(Movement) & {
	-- Connections
	_Janitor: Janitor.Janitor,

	-- Camera
	currentCamera: Camera,
	orthography: boolean,

	-- Key
	move: RBXScriptConnection?,

	-- Zoom
	zoomToMousePosition: boolean,
	wheelPower: number,
	orthographyWheelPower: number,
	wheelInput: RBXScriptConnection?,
	zoomBtn: boolean,
	panZoomingForBtn: boolean,

	panZooming: boolean,
	lastMousePositionPanZoom: Vector2,
	panZoomRun: RBXScriptConnection?,
	panZoomBegan: RBXScriptConnection?,
	panZoomEnded: RBXScriptConnection?,

	-- Pan
	panSpeed: number,
	isPanning: boolean,
	lastMousePosition: Vector2?,
	panRun: RBXScriptConnection?,
	panBegan: RBXScriptConnection?,
	panEnded: RBXScriptConnection?,
	panBtn: boolean,
	isPanningForBtn: boolean,

	-- Shortcuts
	panDown: ShortcutKeys.ShortcutConnect?,
	panLeft: ShortcutKeys.ShortcutConnect?,
	panRight: ShortcutKeys.ShortcutConnect?,
	panUp: ShortcutKeys.ShortcutConnect?,
}

type InputOrFakeInput = InputObject | { UserInputType: Enum, Position: Vector3 }
