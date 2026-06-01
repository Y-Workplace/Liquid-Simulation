--[[
    Singleton input state for editor / camera movement.
	Key handles keyboard input for character or camera movement.
	It tracks movement directions, modifiers (Shift, Control), and movement state.
]]

-- Services
local UserInputService = game:GetService("UserInputService")

local AxisMap = {
	[Enum.KeyCode.A] = { axis = "X", value = -1 },
	[Enum.KeyCode.D] = { axis = "X", value = 1 },

	[Enum.KeyCode.Q] = { axis = "Y", value = -1 },
	[Enum.KeyCode.E] = { axis = "Y", value = 1 },
	[Enum.KeyCode.Space] = { axis = "Y", value = 1 },

	[Enum.KeyCode.W] = { axis = "Z", value = -1 },
	[Enum.KeyCode.S] = { axis = "Z", value = 1 },
}

local AxisKeyCodes = {
	X = { Enum.KeyCode.A, Enum.KeyCode.D },
	Y = { Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Space },
	Z = { Enum.KeyCode.W, Enum.KeyCode.S },
}

local SupportedKeys = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Q] = true,
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.LeftControl] = true,
}

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
local Key = {}

-- Initializes
function Key.Init(self: Key)
	if self._initialized then
		return
	end
	Log("[Key] [Init] Initializing")

	self._initialized = true

	self.isShiftPressed = false
	self.isControlPressed = false

	-- Default movement speed
	self.ftnSpeed = 0.8

	-- Movement directions: W, S, A, D, Q, E/Space
	self.axis = {
		X = { active = 0, last = nil },
		Y = { active = 0, last = nil },
		Z = { active = 0, last = nil },
	}

	-- Input connections
	self.Running = nil
	self.Stopped = nil
end

-- Starts listening to keyboard input
function Key.Start(self: Key)
	if self.Running or self.Stopped then
		return
	end
	Log("[Key] [Start] Binding Connections")

	self.Running = UserInputService.InputBegan:Connect(function(input)
		self:SetKey(input, true)
	end)

	self.Stopped = UserInputService.InputEnded:Connect(function(input)
		self:SetKey(input, false)
	end)
end

-- Stops listening to keyboard input
function Key.Stop(self: Key)
	Log("[Key] [Unload] UnBinding Connections")

	if self.Running then
		self.Running:Disconnect()
		self.Running = nil
	end

	if self.Stopped then
		self.Stopped:Disconnect()
		self.Stopped = nil
	end
end

-- Checks if any movement key is currently active
function Key.CanMove(self: Key)
	return self.axis.X.active ~= 0 or self.axis.Y.active ~= 0 or self.axis.Z.active ~= 0
end

-- Sets or clears a key state based on input and value (pressed or released)
function Key.SetKey(self: Key, input: InputObject, value: boolean)
	if not SupportedKeys[input.KeyCode] or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	-- Movement key mapping
	local map = AxisMap[input.KeyCode]
	if map then
		local axis = self.axis[map.axis]

		if value == true then
			axis.active = map.value
			axis.last = input.KeyCode
		else
			local savedLast = false

			for _, keyCode in ipairs(AxisKeyCodes[map.axis]) do
				if UserInputService:IsKeyDown(keyCode) then
					local newMap = AxisMap[keyCode]
					axis.active = newMap.value
					axis.last = keyCode
					savedLast = true
					break
				end
			end

			if not savedLast and axis.last == input.KeyCode then
				axis.active = 0
				axis.last = nil
			end
		end
	else
		-- Modifier keys
		if input.KeyCode == Enum.KeyCode.LeftShift then
			self.isShiftPressed = value
		elseif input.KeyCode == Enum.KeyCode.LeftControl then
			self.isControlPressed = value
		end

		-- Adjust movement speed based on modifier keys
		if (self.isShiftPressed and self.isControlPressed) or self.isControlPressed then
			self.ftnSpeed = 1.5
		elseif self.isShiftPressed then
			self.ftnSpeed = 0.2
		else
			self.ftnSpeed = 0.8
		end
	end
end

--Type Definitions
export type Key = typeof(Key) & {
	_initialized: boolean,
	isShiftPressed: boolean,
	isControlPressed: boolean,

	-- Default movement speed
	ftnSpeed: number,

	-- Movement directions: W, S, A, D, Q, E/Space
	axis: {
		X: { active: number, last: Enum.KeyCode? },
		Y: { active: number, last: Enum.KeyCode? },
		Z: { active: number, last: Enum.KeyCode? },
	},

	-- Input connections
	Running: RBXScriptConnection?,
	Stopped: RBXScriptConnection?,
}

return Key :: Key
