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
	if self._ExternalStateConnection == nil then
		self._ExternalStateConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "External state", self._StepExternalState, deltaTime)
			end
		end)
	end

	if self._SourceStreamingConnection == nil then
		self._SourceStreamingConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Source streaming", self._StepSourceStreaming, deltaTime)
			end
		end)
	end

	if self._LodBufferConnection == nil then
		self._LodBufferConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "LOD buffer", self._StepLodBuffers, deltaTime)
			end
		end)
	end

	if self._WaveBufferConnection == nil then
		self._WaveBufferConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Wave buffer", self._StepWaveBuffers, deltaTime)
			end
		end)
	end

	if self._SurfaceBufferConnection == nil then
		self._SurfaceBufferConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Surface buffer", self._StepSurfaceBuffers, deltaTime)
			end
		end)
	end

	if self._EffectBufferConnection == nil then
		self._EffectBufferConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Effect buffer", self._StepEffectBuffers, deltaTime)
			end
		end)
	end

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
		self._UnderwaterConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if self._Running then
				runStep(self, "Underwater effects", UnderwaterEffectsController.step, deltaTime)
			end
		end)
	end
end

function RuntimeLoops.stop(self: any)
	disconnect(self._ExternalStateConnection)
	disconnect(self._SourceStreamingConnection)
	disconnect(self._LodBufferConnection)
	disconnect(self._WaveBufferConnection)
	disconnect(self._SurfaceBufferConnection)
	disconnect(self._EffectBufferConnection)
	disconnect(self._BuoyancyConnection)
	disconnect(self._PhysicalConnection)
	disconnect(self._PlayerSurfaceConnection)
	disconnect(self._UnderwaterConnection)

	self._ExternalStateConnection = nil
	self._SourceStreamingConnection = nil
	self._LodBufferConnection = nil
	self._WaveBufferConnection = nil
	self._SurfaceBufferConnection = nil
	self._EffectBufferConnection = nil
	self._BuoyancyConnection = nil
	self._PhysicalConnection = nil
	self._PlayerSurfaceConnection = nil
	self._UnderwaterConnection = nil

	PlayerSurfaceController.cleanup(self)
	UnderwaterEffectsController.cleanup(self)

	self._PhysicalAccumulator = 0
	self._BuoyancyAccumulator = 0
	self._PlayerSurfaceAccumulator = 0
	self._ExternalStateAccumulator = 0
	self._LodBufferAccumulator = 0
	self._WaveBufferAccumulator = 0
	self._SurfaceBufferAccumulator = 0
	self._EffectBufferAccumulator = 0
	self._UnderwaterAccumulator = 0
	self._PhysicalTime = 0
	self._BuoyancyTime = 0
	self._UnderwaterTime = 0
	table.clear(self._PhysicalStates)
end

return RuntimeLoops
