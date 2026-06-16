--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveSpectrum = require(ReplicatedStorage.DirectPackages.WaterSystem.WaveSpectrum)

local parent = script.Parent

if not parent:IsA("Actor") then
	return
end

local actor = parent :: Actor
local resultEvent = actor:WaitForChild("WaveBakeResult") :: BindableEvent

actor:BindToMessageParallel("BakeSpectrum", function(requestId: number, cascades: { WaveSpectrum.CascadeConfig }, options: WaveSpectrum.SpectrumOptions)
	local ok, result = pcall(function()
		return WaveSpectrum.Bake(cascades, options)
	end)

	task.synchronize()
	resultEvent:Fire(requestId, ok, result)
end)

actor:SetAttribute("Ready", true)
