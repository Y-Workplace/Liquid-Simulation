local Editor = script.Editor
local Logger = require(script.Logger.Logger)
local ToolsDown = require(Editor.ToolsDown)
local DisplaySelector = require(Editor.DisplaySelector)
local Explorer = require(Editor.Explorer)
local Properties = require(Editor.Properties)

local UI = {}

function UI.Init()
	ToolsDown:Init()
	ToolsDown:Start()
	DisplaySelector:Init()
	DisplaySelector:Start()
	Explorer:Init()
  Logger:Init()
  Properties:Init()
end

return UI
