local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local _Timeline = require(ReplicatedStorage.DirectPackages.Timeline).new(10)
local ForceFieldAnimation = require(ReplicatedStorage.DirectPackages.ForceFieldAnimation)
local NotesAnimation = require(ReplicatedStorage.DirectPackages.NotesAnimation)
local ShineAnimation = require(ReplicatedStorage.DirectPackages.ShineAnimation)
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

local options = {
	SphericalNormalization = true,
}

function Gameplay:Init()
  self.NotesAnimation = NotesAnimation.new({ Notes.CubicNote, Notes.MeshPart, Notes.SphericalNote, Notes.TriangularNote}, options)
  self.ForceFieldAnimation = ForceFieldAnimation.new({ Notes.CubicNote.ForceField, Notes.MeshPart.ForceField, Notes.SphericalNote.ForceField, Notes.TriangularNote.ForceField }, options)
  self.ShineAnimation = ShineAnimation.new({ Notes.CubicNote.Surface, Notes.MeshPart.Surface, Notes.SphericalNote.Surface, Notes.TriangularNote.Surface }, options)
  self.NotesAnimation:Init()
  self.ForceFieldAnimation:Init()
  self.ShineAnimation:Init()
  self:BindEvent()
end

function Gameplay:BindEvent()
  eventGameplay.Start.Callable:Register(function()
    self:Start()
  end)
end

function Gameplay:Start()
  self.NotesAnimation:Start()
  self.ForceFieldAnimation:Start()
  self.ShineAnimation:Start()
end

BindInit()
