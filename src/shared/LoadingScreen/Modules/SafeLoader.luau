local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Root = require(script.Parent.Root)
local Player: Player
local PlayerGui: PlayerGui

local REQUIRED_INSTANCES = {
	game:GetService("Lighting"),
	game:GetService("MaterialService"),
	game:GetService("NetworkClient"),
	game:GetService("ServerScriptService"),
	game:GetService("ServerStorage"),
	game:GetService("StarterPack"),
	game:GetService("StarterPlayer"),
	game:GetService("Teams"),
	game:GetService("SoundService"),
	game:GetService("TextChatService"),
	game:GetService("VoiceChatService"),
	game:GetService("TestService"),
	game:GetService("UserInputService"),
	game:GetService("TweenService"),
	game:GetService("ContextActionService"),
	game:GetService("HttpService"),
}

local function WaitForViewportUpdate()
	local camera = workspace.CurrentCamera

	while not camera do
		RunService.Heartbeat:Wait()
		camera = workspace.CurrentCamera
	end

	while camera.ViewportSize.X <= 0 or camera.ViewportSize.Y <= 0 do
		RunService.RenderStepped:Wait()
	end

	RunService.RenderStepped:Wait()
end

local function WaitForGuiInset()
	local inset = GuiService:GetGuiInset()

	while inset.Y <= 0 do
		RunService.RenderStepped:Wait()
		inset = GuiService:GetGuiInset()
	end

	RunService.RenderStepped:Wait()
end

local function WaitForInstances()
	for _, instance in ipairs(REQUIRED_INSTANCES) do
		if not instance then
			repeat
				task.wait()
			until instance
		end
	end
end

local function WaitForPlayer()
  while not Players.LocalPlayer do
    task.wait()
  end
  Player = Players.LocalPlayer
  while not Player.PlayerGui do
    task.wait()
  end
  PlayerGui = Player.PlayerGui
end

local function WaitPath(root: string, path: { string }, ServiceName: string)
	local current = root

	if current == "" then
		for _, name in ipairs(path) do
			current = game:GetService(ServiceName):WaitForChild(name, 50)
		end
	else
		local segments = current:split("|")
		local currentInstance = game:GetService(ServiceName):WaitForChild(segments[1])

		for i = 2, #segments do
			currentInstance = currentInstance:WaitForChild(segments[i])
		end

		for _, name in ipairs(path) do
			currentInstance:WaitForChild(name, 50)
		end
	end
end

local function LoadRoot()
	for ServiceName, service in pairs(Root) do
		for _, item in ipairs(service) do
			WaitPath(item.root, item.path, ServiceName)
		end
	end
end

--[[
	ReplicateGui

	Roblox normally replicates all StarterGui contents into PlayerGui
	automatically when a player joins the game.

	However, this project overrides the default client initialization flow:
	- CharacterAutoLoads is disabled
	- Client loading is controlled manually by SafeLoader
	- The game bootstrap requires a deterministic initialization order

	As a result, the automatic replication of StarterGui may not occur
	at the expected time (or may not occur at all). To avoid relying on
	internal engine behavior, we manually replicate the GUI here.

	This guarantees that:
	- PlayerGui already exists
	- All StarterGui contents are available
	- UI services can initialize deterministically

	IMPORTANT:
	This method assumes StarterGui is used strictly as a template.
	After cloning, the runtime operates exclusively on PlayerGui.
]]

local function ReplicateGui()
	for _, gui in ipairs(StarterGui:GetChildren()) do
		local clone = gui:Clone()
		clone.Parent = PlayerGui
	end
end

function SafeLoader()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	WaitForPlayer()
	WaitForViewportUpdate()
	WaitForGuiInset()
	WaitForInstances()
	LoadRoot()
	ReplicateGui()
end

return SafeLoader
