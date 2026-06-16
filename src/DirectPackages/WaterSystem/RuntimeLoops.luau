--!strict

local RunService = game:GetService("RunService")

local BuoyancyController = require(script.Parent.BuoyancyController)
local PhysicalInteractionController = require(script.Parent.PhysicalInteractionController)
local PlayerSurfaceController = require(script.Parent.PlayerSurfaceController)
local UnderwaterEffectsController = require(script.Parent.UnderwaterEffectsController)

local RuntimeLoops = {}

local function disconnect(connection: RBXScriptConnection?)
	if connection ~= nil then
		connection:Disconnect()
	end
end

local function runStep(self: any, label: string, step: (any, number) -> (), deltaTime: number)
	local ok, err = pcall(step, self, deltaTime)

	if not ok then
		warn("[WaterSystem] " .. label .. " controller failed: " .. tostring(err))
	end
end

function RuntimeLoops.start(self: any)
	if self._BuoyancyConnection == nil then
		self._BuoyancyConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Buoyancy", BuoyancyController.step, deltaTime)
			end
		end)
	end

	if self._PhysicalConnection == nil then
		self._PhysicalConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Physical interaction", PhysicalInteractionController.step, deltaTime)
			end
		end)
	end

	if self._PlayerSurfaceConnection == nil then
		self._PlayerSurfaceConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Player surface", PlayerSurfaceController.step, deltaTime)
			end
		end)
	end

	if self._UnderwaterConnection == nil then
		self._UnderwaterConnection = RunService.RenderStepped:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Underwater effects", UnderwaterEffectsController.step, deltaTime)
			end
		end)
	end
end

function RuntimeLoops.stop(self: any)
	disconnect(self._BuoyancyConnection)
	disconnect(self._PhysicalConnection)
	disconnect(self._PlayerSurfaceConnection)
	disconnect(self._UnderwaterConnection)

	self._BuoyancyConnection = nil
	self._PhysicalConnection = nil
	self._PlayerSurfaceConnection = nil
	self._UnderwaterConnection = nil

	PlayerSurfaceController.cleanup(self)
	UnderwaterEffectsController.cleanup(self)

	self._PhysicalAccumulator = 0
	self._BuoyancyAccumulator = 0
	self._PhysicalTime = 0
	self._BuoyancyTime = 0
	self._UnderwaterTime = 0
	table.clear(self._PhysicalStates)
end

return RuntimeLoops
