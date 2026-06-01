local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Timeline = require(ReplicatedStorage.DirectPackages.Timeline).new(10)
local EventTree = require(ReplicatedStorage.Packages.EventTree)

local eventGameplay = EventTree.GameplayService
local World = workspace.World

local Gameplay = {}

local function Compute(Props, Progress: number)

end

local function BindInit()
	type BindInit = { Init: (self: any) -> nil }
	local self: BindInit = Gameplay :: BindInit
	eventGameplay.Init.Callable:Register(function()
		self:Init()
	end)
end

function Gameplay:Init()


  self:BindEvent()
end

function Gameplay:BindEvent()
  eventGameplay.Start.Callable:Register(function()
    self:Start()
  end)
end

function Gameplay:Start()

end

BindInit()
