--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RippleGlass = require(ReplicatedStorage.DirectPackages.RippleGlass)

local Effect = RippleGlass.new()

--Effect:Start()

task.spawn(function()
	while false do
		task.wait(math.random() * 0.5 + 0.25)

		Effect:Pulse(math.random(50, 150) / 100)
	end
end)
