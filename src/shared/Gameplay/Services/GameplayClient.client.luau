local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local _Timeline = require(ReplicatedStorage.DirectPackages.Timeline).new(10)
local NotesAnimation = require(ReplicatedStorage.DirectPackages.NotesAnimation)
local EventTree = require(ReplicatedStorage.Packages.EventTree)

local eventGameplay = EventTree.GameplayService
local _World = workspace.World
local Notes = Workspace.Notes

local Gameplay = {}

local function _Compute(Props, Progress: number)

end

local function BindInit()
	type BindInit = { Init: (self: any) -> nil }
	local self: BindInit = Gameplay :: BindInit
	eventGameplay.Init.Callable:Register(function()
		self:Init()
	end)
end

function Gameplay:Init()
  self.NotesAnimation = NotesAnimation.new({ Notes.CubicNote, Notes.MeshPart, Notes.SphericalNote, Notes.TriangularNote})
  self.NotesAnimation:Init()
  self:BindEvent()
end

function Gameplay:BindEvent()
  eventGameplay.Start.Callable:Register(function()
    self:Start()
  end)
end

function Gameplay:Start()
  self.NotesAnimation:Start()
end

BindInit()
