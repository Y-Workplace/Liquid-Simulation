-- Required Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SafeLoader = ReplicatedStorage:WaitForChild("Shared")
	:WaitForChild("LoadingScreen")
	:WaitForChild("Modules")
	:WaitForChild("SafeLoader")
require(SafeLoader)()

print "Game loaded"

-- Local References

local localPlayer = Players.LocalPlayer

-- Required Modules
local EventTree = require(ReplicatedStorage.Packages.EventTree)
local LoggerSystem = require(ReplicatedStorage.Packages.LoggerSystem)
--local UI = require(ReplicatedStorage.UI)

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

local InitializeServices = {
 "Core",
 "CameraService",
 "MovementService",
 "GameplayService",
}

-- Initializes
local function Init()
	Logger:Info("[Client] [Init] Initializing")

	for _, serviceName in ipairs(InitializeServices) do
		Logger:Info("Initializing:", serviceName)

		local serviceNode = EventTree[serviceName]

		if not serviceNode then
			Logger:Warn("[Client] Missing service node: " .. serviceName)
			continue
		end

		if not serviceNode.Init then
			Logger:Warn("[Client] Missing Init node for service: " .. serviceName)
			continue
		end

		if not serviceNode.Init.Callable then
			Logger:Warn("[Client] Missing Init.Callable for service: " .. serviceName)
			continue
		end

		local ok, err = xpcall(function()
			serviceNode.Init.Callable:Call()
		end, debug.traceback)

		if ok then
			Logger:Info(serviceName .. " Initialized")
		else
			Logger:Warn(serviceName .. " Initialization Failed\n" .. tostring(err))
      warn(tostring(err))
		end
	end

	-- UI.Init()
end

Init()
EventTree.Core.Start.Callable:Call()
