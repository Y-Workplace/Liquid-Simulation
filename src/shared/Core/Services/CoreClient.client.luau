-- Local References
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Required Modules
local LoggerSystem = require(ReplicatedStorage.Packages.LoggerSystem)
local EventTree = require(ReplicatedStorage.Packages.EventTree)

-- Log system
local Logger = LoggerSystem.new("System")

-- Module Declaration
local Core = {}

local function BindInit()
	type BindInit = { Init: (self: any) -> nil }
	local self: BindInit = Core :: BindInit
	EventTree.Core.Init.Callable:Register(function(...)
		self:Init(...)
	end)
end

-- Initializes submodules
function Core.Init(self: Core)
	Logger:Info("[Init] Initializing")
	self:BindEvent()
end

function Core.BindEvent(self: Core)
	Logger:Info("[BindEvent] Binding Events")

	EventTree.Core.Start.Callable:Register(function()
		self:Start()
	end)
end

-- Starts the core system
function Core:Start()
  Logger:Info("[Core] Starting CameraService")
	EventTree.CameraService.Start.Callable:Call()

  Logger:Info("[Core] Starting MovementService")
	EventTree.MovementService.Start.Callable:Call()

  EventTree.LensFlare.Start.Callable:Call()

  EventTree.GameplayService.Start.Callable:Call()
end

BindInit()

export type Core = typeof(Core) & {}
