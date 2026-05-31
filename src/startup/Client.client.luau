-- Required Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SafeLoader = ReplicatedStorage:WaitForChild("Shared")
	:WaitForChild("LoadingScreen")
	:WaitForChild("Modules")
	:WaitForChild("SafeLoader")
require(SafeLoader)()

-- Local References
local PlayerGui = game.Players.LocalPlayer.PlayerGui
local g_btnSu = PlayerGui.TopTools.Fixe.Test
local g_designio = g_btnSu.Parent.ui
local g_editorUI = PlayerGui.Editor
local localPlayer = Players.LocalPlayer

-- Required Modules
local EventTree = require(ReplicatedStorage.Packages.EventTree)
local LoggerSystem = require(ReplicatedStorage.Packages.LoggerSystem)
--local EditorOld = require(ReplicatedStorage.Editor.Core.Editor).New()
local UI = require(ReplicatedStorage.UI)

-- Log system
local Logger = LoggerSystem.new("Client")

Logger:Info("[Main] Starting Boostrap")
local BoostrapFinnish = false
EventTree.Boostrap.Finnish.Provider:Await(function(status: boolean)
	BoostrapFinnish = status
end)

local Boostrap = ReplicatedStorage.Shared.Core.BootstrapClient
Boostrap.Parent = localPlayer.PlayerScripts

while not BoostrapFinnish do
	task.wait()
end
Logger:Info("[Main] Boostrap Finnished")

g_btnSu.Parent.Parent.Enabled = false

g_designio.MouseButton1Click:Connect(function()
	if g_editorUI.Enabled then
		g_editorUI.Enabled = false
	else
		g_editorUI.Enabled = true
	end
end)
Logger:Info("[Main] Studio Gui ON")

--[[
-- Função do jogo

local m_Object = require(ReplicatedStorage.Editor.Function.Object)
local PathAnimate = require(ReplicatedStorage.Editor.Function.PathAnimate).New()
local m_Path = require(ReplicatedStorage.Editor.Function.Path)
local m_SimpleLerp = require(ReplicatedStorage.Editor.Function.SimpleLerp)

local g_pathTest = m_Path.New("HJ", {
	Vector3.new(-62, 12.5, 22),
	Vector3.new(-61, 10.5, 13),
	Vector3.new(-63, 9.5, 7),
	Vector3.new(-59, 11.5, 0),
	Vector3.new(-54, 11.5, -7)
})

g_btnSu.Activated:Connect(function()
	local note = m_Object.new("Part", g_engine)
	note.path = g_pathTest

	local tweenInfo = m_SimpleLerp.New(4, "Sine", "InOut")
	local tweenInfo1 = m_SimpleLerp.New(4, "Sine", "InOut")
	local tweenInfo2 = m_SimpleLerp.New(4, "Sine", "InOut")
	local tweenInfo3 = m_SimpleLerp.New(4, "Sine", "InOut")

	note:Spawn()

	PathAnimate:Add(note)

	tweeninfo:Start(note.object, "CFrame", CFrame.new(0,60,80), CFrame.new(0,0,0))

	tweenInfo:Play()
	task.wait(2)
	tweenInfo:Pause()
	task.wait(2)
	tweenInfo:Play()
	task.wait(2)

	tweeninfo1:Start(note, "Per", 0.8, 0.1)
	tweeninfo1:Play()

	tweeninfo2:Start(note.object, "Transparency", 1, 0)
	tweeninfo2:Play()

	task.wait(9)

	PathAnimate:Remove(note)
end)

PathAnimate:Run()
]]

local InitializeServices = {
	"Editor",
	"GridManager",
	"CameraService",
	"MovementService",
	"ContextMenu",
	"Explorer",
	"Properties",
  "Tools",
}

-- Initializes
local function Init()
	Logger:Info("[Client] [Init] Initializing")

	for _, Service in ipairs(InitializeServices) do
		Logger:Info("Initializating:", Service)
		local ok, err = pcall(function()
			EventTree[Service].Init.Callable:Call()
		end)
		if ok then
			Logger:Info(Service .. " Initializad")
		else
			Logger:Warn(Service .. " Initialization Failed\n" .. err)
		end
	end

	UI.Init()
end

-- Starts the editor system
local function StartEditor()
	Logger:Info("[Client] [StartEditor] Starting Editor")

	EventTree.Editor.Start.Callable:Call()
	--EditorOld:Start()
end

Init()
StartEditor()
