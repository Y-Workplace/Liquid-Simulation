local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local _Timeline = require(ReplicatedStorage.DirectPackages.Timeline).new(10)
local MaterialWorkspaces = ReplicatedStorage.DirectPackages.MaterialAnimation.Workspaces
local ForceFieldAnimation = require(MaterialWorkspaces.ForceFieldAnimation)
local MaterialBinder = require(ReplicatedStorage.DirectPackages.MaterialAnimation.SurfaceAppearanceBinder)
local NotesAnimation = require(MaterialWorkspaces.NotesAnimation)
local ShineAnimation = require(MaterialWorkspaces.ShineAnimation)
local TriangularForceFieldAnimation = require(MaterialWorkspaces.TriangularForceFieldAnimation)
local TriangularNotesAnimation = require(MaterialWorkspaces.TriangularNotesAnimation)
local WaterSystem = require(ReplicatedStorage.DirectPackages.WaterSystem)
local EventTree = require(ReplicatedStorage.Packages.EventTree)

local eventGameplay = EventTree.GameplayService
local _World = workspace.World
local Notes = workspace.Notes

local Gameplay = {}

local function _Compute(_Props, _Progress: number) end

local function BindMaterial(animation, parts: { MeshPart })
	animation:Init()
	MaterialBinder.Bind(animation, parts)
	task.wait()

	return animation
end

local function BindInit()
	type BindInit = { Init: (self: any) -> nil }
	local self: BindInit = Gameplay :: BindInit
	eventGameplay.Init.Callable:Register(function()
		self:Init()
	end)
end

function Gameplay:Init()
	self.Ocean = WaterSystem.new()

	--[[self.NoteFamily = {
		CubicNote = {
			NotesAnimation = BindMaterial(NotesAnimation.new(), { Notes.CubicNote, Notes.MeshPart }),
			ForceFieldAnimation = BindMaterial(
				ForceFieldAnimation.new(),
				{ Notes.CubicNote.ForceField, Notes.MeshPart.ForceField }
			),
			ShineAnimation = BindMaterial(ShineAnimation.new(), { Notes.CubicNote.Surface, Notes.MeshPart.Surface }),
		},
		SphericalNote = {
			NotesAnimation = BindMaterial(
				NotesAnimation.new({
					Projection = "Equirectangular",
					ColorA = Color3.fromRGB(136, 57, 239),
					ColorB = Color3.fromRGB(203, 166, 247),
				}),
				{ Notes.SphericalNote }
			),
			ForceFieldAnimation = BindMaterial(
				ForceFieldAnimation.new({ Projection = "Equirectangular", NoiseScale = 1, Color = Color3.fromRGB(136, 57, 239) }),
				{ Notes.SphericalNote.ForceField }
			),
			ShineAnimation = BindMaterial(
				ShineAnimation.new(
					{ Projection = "Equirectangular", ShineBackgroundColor = Color3.fromRGB(203, 166, 247) }
				),
				{ Notes.SphericalNote.Surface }
			),
		},
		TriangularNote = {
			NotesAnimation = BindMaterial(TriangularNotesAnimation.new(), { Notes.TriangularNote }),
			ForceFieldAnimation = BindMaterial(TriangularForceFieldAnimation.new(), { Notes.TriangularNote.ForceField }),
			ShineAnimation = BindMaterial(
				ShineAnimation.new({ ShineBackgroundColor = Color3.fromRGB(29, 118, 228) }),
				{ Notes.TriangularNote.Surface }
			),
		},
	}]]
	self:BindEvent()
end

function Gameplay:BindEvent()
	eventGameplay.Start.Callable:Register(function()
		self:Start()
	end)
end

function Gameplay:Start()
	if self.Ocean then
		self.Ocean:Start()
	end

	--[[for _, note in pairs(self.NoteFamily) do
		for _, animation in pairs(note) do
			animation:Start()
		end
	end]]
end

BindInit()
