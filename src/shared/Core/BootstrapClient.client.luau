local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventTree = require(ReplicatedStorage.Packages.EventTree)
local Registry = require(ReplicatedStorage.Packages.Registry)

local boots = {
  { domain = "Core", serviceName = "CoreClient" },
	{ domain = "LensFlare", serviceName = "LensFlareClient" },
  { domain = "Movement", serviceName = "MovementClient" },
  { domain = "Camera", serviceName = "CameraClient" },
  { domain = "Gameplay", serviceName = "GameplayClient" },
}

for _, boot in ipairs(boots) do
	Registry:Load(boot.domain, boot.serviceName)
end

EventTree.Boostrap.Finnish.Provider:Register(function()
	return true
end)
