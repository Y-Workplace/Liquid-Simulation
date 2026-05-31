local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventTree = require(ReplicatedStorage.Packages.EventTree)
local Registry = require(ReplicatedStorage.Packages.Registry)

local boots = {
	{ domain = "Camera", serviceName = "CameraClient" },
	{ domain = "GridManager", serviceName = "GridManagerClient" },
	{ domain = "Movement", serviceName = "MovementClient" },
	{ domain = "ContextMenu", serviceName = "ContextMenuClient" },
	{ domain = "Explorer", serviceName = "ExplorerClient" },
	{ domain = "Editor", serviceName = "EditorClient" },
	{ domain = "Properties", serviceName = "PropertiesClient" },
  { domain = "Tools", serviceName = "ToolsClient" },
}

for _, boot in ipairs(boots) do
	Registry:Load(boot.domain, boot.serviceName)
end

EventTree.Boostrap.Finnish.Provider:Register(function()
	return true
end)
