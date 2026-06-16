local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local toolbar = plugin:CreateToolbar("Material Graph")
local toggleButton = toolbar:CreateButton("Material Graph", "Open Material Graph editor", "")
toggleButton.ClickableWhenViewportHidden = true

local dockInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	980,
	660,
	720,
	480
)

local widget = plugin:CreateDockWidgetPluginGuiAsync("GameplayTeaseMaterialGraphEditor", dockInfo)
widget.Title = "Material Graph"

local NODE_DEFS = {
	FBMNoise = {
		Family = "Source",
		Inputs = {},
		Outputs = { "noise" },
		Parameters = [[NoiseScale = 0.1,
AnimationRadius = 1.5,
Octaves = 3,]],
	},
	ForceFieldIntensity = {
		Family = "Source",
		Inputs = {},
		Outputs = { "forceField" },
		Parameters = [[WarpScale = 1.5,
CoreIntensity = 25,
BloomSpread = 4.5,
Strength = 1,
NoiseScale = 0.2,
TimeRadius = 1.35,]],
	},
	ShineBand = {
		Family = "Source",
		Inputs = {},
		Outputs = { "shine" },
		Parameters = [[ShineBandWidth = 0.18,
ShinePeak = 1,
ShineAngleDeg = 30,
ShineFadeIn = 0.18,
ShineFadeOut = 0.22,]],
	},
	TriangularStripeForceField = {
		Family = "Source",
		Inputs = {},
		Outputs = { "forceField" },
		Parameters = [[Strength = 1.15,
ShineLineWidth = 0.02,
ShineLineStrength = 1,
StripeSpeed = 1,
StripeWaviness = 0.007,
StripeBreakup = 0.28,]],
	},
	TriangularNotesLayers = {
		Family = "Material",
		Inputs = {},
		Outputs = { "color", "alpha" },
		Parameters = [[ColorAKey = "ColorA",
ColorBKey = "ColorB",
ColorCKey = "ColorC",
ColorDKey = "ColorD",
ColorEKey = "ColorE",
AnimationRadius = 0.565,]],
	},
	NoiseToPalette = {
		Family = "Material",
		Inputs = { "noise" },
		Outputs = { "color", "alpha" },
		Parameters = [[PigmentThreshold = 0.3,
ColorAKey = "PrimaryColor",
ColorBKey = "SecondaryColor",]],
	},
	ForceFieldMaterial = {
		Family = "Material",
		Inputs = { "forceField" },
		Outputs = { "color", "alpha", "emissive", "emissiveAlpha" },
		Parameters = [[ColorKey = "PrimaryColor",]],
	},
	ShineMaterial = {
		Family = "Material",
		Inputs = { "shine" },
		Outputs = { "color", "alpha", "emissive", "emissiveAlpha" },
		Parameters = [[BackgroundColorKey = "BackgroundColor",
ShineBackgroundAlpha = 0.52,]],
	},
}

local PALETTE = {
	Source = { "FBMNoise", "ForceFieldIntensity", "ShineBand", "TriangularStripeForceField" },
	Material = { "NoiseToPalette", "ForceFieldMaterial", "ShineMaterial", "TriangularNotesLayers" },
}

type GraphNode = {
	id: string,
	typeName: string,
	inputs: { [string]: string },
	outputs: { [string]: string },
	parameters: string,
	x: number,
	y: number,
}

type Scope = {
	kind: "Main" | "Bake",
	name: string,
	sharedKey: string,
	outputsText: string,
	workspaceIncludes: string,
	workspaceValues: string,
	nodes: { GraphNode },
}

local state = {
	moduleName = "GeneratedMaterialWorkspace",
	width = "64",
	height = "64",
	targetFPS = "15",
	bakedFrameCount = "180",
	projection = "Flat",
	channels = {
		ColorMap = true,
		EmissiveMask = true,
	},
	surfaceAppearance = [[AlphaMode = Enum.AlphaMode.Transparency,
EmissiveStrength = 4,
EmissiveTint = Color3.fromRGB(255, 255, 255),]],
	workspaceIncludes = "",
	workspaceValues = [[PrimaryColor = Color3.fromRGB(255, 160, 70),
SecondaryColor = Color3.fromRGB(180, 70, 10),
BackgroundColor = Color3.fromRGB(255, 160, 70),
ColorA = Color3.fromRGB(22, 180, 222),
ColorB = Color3.fromRGB(103, 226, 232),
ColorC = Color3.fromRGB(129, 239, 238),
ColorD = Color3.fromRGB(29, 118, 228),
ColorE = Color3.fromRGB(41, 205, 226),]],
	scopes = {} :: { Scope },
	activeScope = 1,
	selectedNodeId = nil :: string?,
	nextNodeId = 1,
	message = "",
}

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundColor3 = Color3.fromRGB(25, 27, 31)
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = widget

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.BackgroundColor3 = Color3.fromRGB(35, 38, 44)
topBar.BorderSizePixel = 0
topBar.Size = UDim2.new(1, 0, 0, 42)
topBar.Parent = root

local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(0, 42)
body.Size = UDim2.new(1, 0, 1, -42)
body.Parent = root

local paletteFrame = Instance.new("ScrollingFrame")
paletteFrame.Name = "Palette"
paletteFrame.BackgroundColor3 = Color3.fromRGB(30, 33, 39)
paletteFrame.BorderSizePixel = 0
paletteFrame.CanvasSize = UDim2.fromOffset(0, 0)
paletteFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
paletteFrame.ScrollBarThickness = 6
paletteFrame.Size = UDim2.new(0, 190, 1, 0)
paletteFrame.Parent = body

local canvasFrame = Instance.new("ScrollingFrame")
canvasFrame.Name = "Canvas"
canvasFrame.BackgroundColor3 = Color3.fromRGB(21, 23, 27)
canvasFrame.BorderSizePixel = 0
canvasFrame.Position = UDim2.fromOffset(190, 0)
canvasFrame.Size = UDim2.new(1, -520, 1, 0)
canvasFrame.CanvasSize = UDim2.fromOffset(1200, 900)
canvasFrame.ScrollBarThickness = 8
canvasFrame.Parent = body

local inspectorFrame = Instance.new("ScrollingFrame")
inspectorFrame.Name = "Inspector"
inspectorFrame.BackgroundColor3 = Color3.fromRGB(30, 33, 39)
inspectorFrame.BorderSizePixel = 0
inspectorFrame.Position = UDim2.new(1, -330, 0, 0)
inspectorFrame.Size = UDim2.new(0, 330, 1, 0)
inspectorFrame.CanvasSize = UDim2.fromOffset(0, 0)
inspectorFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
inspectorFrame.ScrollBarThickness = 6
inspectorFrame.Parent = body

local paletteLayout = Instance.new("UIListLayout")
paletteLayout.Padding = UDim.new(0, 8)
paletteLayout.SortOrder = Enum.SortOrder.LayoutOrder
paletteLayout.Parent = paletteFrame

local inspectorLayout = Instance.new("UIListLayout")
inspectorLayout.Padding = UDim.new(0, 8)
inspectorLayout.SortOrder = Enum.SortOrder.LayoutOrder
inspectorLayout.Parent = inspectorFrame

local function clearChildren(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			continue
		end

		child:Destroy()
	end
end

local function addPadding(parent: Instance, left: number, top: number, right: number, bottom: number)
	local padding = parent:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.Parent = parent
end

addPadding(paletteFrame, 10, 10, 10, 10)
addPadding(inspectorFrame, 10, 10, 10, 10)

local function makeLabel(parent: Instance, text: string, height: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = Color3.fromRGB(225, 229, 235)
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, 0, 0, height or 22)
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, text: string, height: number?, callback: () -> ())
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(48, 54, 64)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.TextColor3 = Color3.fromRGB(240, 242, 246)
	button.TextSize = 13
	button.AutoButtonColor = true
	button.Size = UDim2.new(1, 0, 0, height or 30)
	button.Parent = parent
	button.MouseButton1Click:Connect(callback)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	return button
end

local function makeTextBox(parent: Instance, text: string, height: number, onCommit: (string) -> ())
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Color3.fromRGB(21, 23, 27)
	box.BorderColor3 = Color3.fromRGB(62, 68, 80)
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Code
	box.MultiLine = height > 34
	box.Text = text
	box.TextColor3 = Color3.fromRGB(235, 239, 246)
	box.TextSize = 12
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.Size = UDim2.new(1, 0, 0, height)
	box.Parent = parent
	box.FocusLost:Connect(function()
		onCommit(box.Text)
	end)
	return box
end

local function quote(value: string): string
	return string.format("%q", value)
end

local function identifierName(value: string): string
	local result = string.gsub(value, "%W", "_")
	if result == "" or string.match(result, "^%d") then
		result = "GeneratedMaterialWorkspace"
	end

	return result
end

local function indentText(text: string, indent: string): string
	local lines = string.split(text, "\n")
	for index, line in ipairs(lines) do
		lines[index] = indent .. line
	end
	return table.concat(lines, "\n")
end

local function nodeDefaults(typeName: string): GraphNode
	local def = NODE_DEFS[typeName]
	local inputs = {}
	local outputs = {}

	for _, inputName in ipairs(def.Inputs) do
		inputs[inputName] = inputName
	end

	for _, outputName in ipairs(def.Outputs) do
		outputs[outputName] = outputName
	end

	local id = typeName .. tostring(state.nextNodeId)
	state.nextNodeId += 1

	return {
		id = id,
		typeName = typeName,
		inputs = inputs,
		outputs = outputs,
		parameters = def.Parameters,
		x = 40 + (#state.scopes[state.activeScope].nodes % 3) * 220,
		y = 40 + math.floor(#state.scopes[state.activeScope].nodes / 3) * 150,
	}
end

local function activeScope(): Scope
	return state.scopes[state.activeScope]
end

local function findSelectedNode(): GraphNode?
	local selected = state.selectedNodeId
	if selected == nil then
		return nil
	end

	for _, node in ipairs(activeScope().nodes) do
		if node.id == selected then
			return node
		end
	end

	return nil
end

local function mapToSource(map: { [string]: string }, defaults: { string }, indent: string): string?
	local lines = {}

	for _, key in ipairs(defaults) do
		local value = map[key]
		if value ~= nil and value ~= key then
			table.insert(lines, indent .. key .. " = " .. quote(value) .. ",")
		end
	end

	if #lines == 0 then
		return nil
	end

	return "{\n" .. table.concat(lines, "\n") .. "\n" .. string.sub(indent, 1, math.max(#indent - 1, 0)) .. "}"
end

local function nodesToSource(nodes: { GraphNode }, indent: string): string
	local lines = {}

	for _, node in ipairs(nodes) do
		local def = NODE_DEFS[node.typeName]
		local nodeLines = {
			indent .. "{",
			indent .. "\tType = " .. quote(node.typeName) .. ",",
		}
		local inputSource = mapToSource(node.inputs, def.Inputs, indent .. "\t\t")
		local outputSource = mapToSource(node.outputs, def.Outputs, indent .. "\t\t")

		if inputSource ~= nil then
			table.insert(nodeLines, indent .. "\tInputs = " .. inputSource .. ",")
		end

		if outputSource ~= nil then
			table.insert(nodeLines, indent .. "\tOutputs = " .. outputSource .. ",")
		end

		if node.parameters ~= "" then
			table.insert(nodeLines, indent .. "\tParameters = {")
			table.insert(nodeLines, indentText(node.parameters, indent .. "\t\t"))
			table.insert(nodeLines, indent .. "\t},")
		end

		table.insert(nodeLines, indent .. "},")
		table.insert(lines, table.concat(nodeLines, "\n"))
	end

	return table.concat(lines, "\n")
end

local function channelsToSource(): string
	local channels = {}
	if state.channels.ColorMap then
		table.insert(channels, quote("ColorMap"))
	end
	if state.channels.EmissiveMask then
		table.insert(channels, quote("EmissiveMask"))
	end
	return "{ " .. table.concat(channels, ", ") .. " }"
end

local function bakesToSource(indent: string): string
	local lines = {}

	for _, scope in ipairs(state.scopes) do
		if scope.kind ~= "Bake" then
			continue
		end

		local bakeLines = {
			indent .. "[" .. quote(scope.name) .. "] = {",
			indent .. "\tBake = true,",
			indent .. "\tSharedKey = " .. quote(scope.sharedKey) .. ",",
			indent .. "\tOutputs = {",
			indentText(scope.outputsText, indent .. "\t\t"),
			indent .. "\t},",
		}

		if scope.workspaceIncludes ~= "" or scope.workspaceValues ~= "" then
			table.insert(bakeLines, indent .. "\tWorkspace = {")
			if scope.workspaceIncludes ~= "" then
				table.insert(bakeLines, indent .. "\t\tIncludes = {")
				table.insert(bakeLines, indentText(scope.workspaceIncludes, indent .. "\t\t\t"))
				table.insert(bakeLines, indent .. "\t\t},")
			end
			if scope.workspaceValues ~= "" then
				table.insert(bakeLines, indent .. "\t\tValues = {")
				table.insert(bakeLines, indentText(scope.workspaceValues, indent .. "\t\t\t"))
				table.insert(bakeLines, indent .. "\t\t},")
			end
			table.insert(bakeLines, indent .. "\t},")
		end

		table.insert(bakeLines, indent .. "\tNodes = {")
		table.insert(bakeLines, nodesToSource(scope.nodes, indent .. "\t\t"))
		table.insert(bakeLines, indent .. "\t},")
		table.insert(bakeLines, indent .. "},")
		table.insert(lines, table.concat(bakeLines, "\n"))
	end

	return table.concat(lines, "\n")
end

local function generateSource(): string
	local mainScope = state.scopes[1]
	local moduleIdentifier = identifierName(state.moduleName)
	local includesBlock = ""

	if state.workspaceIncludes ~= "" then
		includesBlock = [[			Includes = {
]] .. indentText(state.workspaceIncludes, "\t\t\t\t") .. [[
			},
]]
	end

	return [[local MaterialAnimation = require(script.Parent.Parent.MaterialAnimation)

local ]] .. moduleIdentifier .. [[ = {}

function ]] .. moduleIdentifier .. [[.new(options)
	return MaterialAnimation.new({
		Width = options and options.Width or ]] .. state.width .. [[,
		Height = options and options.Height or ]] .. state.height .. [[,
		TargetFPS = options and options.TargetFPS or ]] .. state.targetFPS .. [[,
		BakedFrameCount = options and options.BakedFrameCount or ]] .. state.bakedFrameCount .. [[,
		Projection = options and options.Projection or ]] .. quote(state.projection) .. [[,
		Channels = ]] .. channelsToSource() .. [[,
		Workspace = {
]] .. includesBlock .. [[
			Values = {
]] .. indentText(state.workspaceValues, "\t\t\t\t") .. [[
			},
			Bakes = {
]] .. bakesToSource("\t\t\t\t") .. [[
			},
		},
		Nodes = {
]] .. nodesToSource(mainScope.nodes, "\t\t\t") .. [[
		},
		SurfaceAppearance = {
]] .. indentText(state.surfaceAppearance, "\t\t\t") .. [[
		},
	})
end

return ]] .. moduleIdentifier .. "\n"
end

local function ensureFolder(parent: Instance, name: string): Instance
	local child = parent:FindFirstChild(name)
	if child == nil then
		child = Instance.new("Folder")
		child.Name = name
		child.Parent = parent
	end
	return child
end

local function exportModule()
	local directPackages = ensureFolder(ReplicatedStorage, "DirectPackages")
	local materialAnimation = ensureFolder(directPackages, "MaterialAnimation")
	local workspaces = ensureFolder(materialAnimation, "Workspaces")
	local module = workspaces:FindFirstChild(state.moduleName)

	if module == nil then
		module = Instance.new("ModuleScript")
		module.Name = state.moduleName
		module.Parent = workspaces
	end

	if not module:IsA("ModuleScript") then
		state.message = "Export target exists but is not a ModuleScript."
		return
	end

	module.Source = generateSource()
	Selection:Set({ module })
	state.message = "Exported " .. state.moduleName .. " to MaterialAnimation.Workspaces."
end

local function addNode(typeName: string)
	table.insert(activeScope().nodes, nodeDefaults(typeName))
	state.message = "Added " .. typeName
end

local function clearGraph()
	state.scopes = {
		{
			kind = "Main",
			name = "Main",
			sharedKey = "",
			outputsText = "",
			workspaceIncludes = "",
			workspaceValues = "",
			nodes = {},
		},
	}
	state.activeScope = 1
	state.selectedNodeId = nil
end

local function addBake()
	local name = "Bake" .. tostring(#state.scopes)
	table.insert(state.scopes, {
		kind = "Bake",
		name = name,
		sharedKey = state.moduleName .. "." .. name,
		outputsText = [[noise = "noise",]],
		workspaceIncludes = "",
		workspaceValues = "",
		nodes = {},
	})
	state.activeScope = #state.scopes
	state.selectedNodeId = nil
end

local refresh

local function makeScopeButton(scope: Scope, index: number)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = if index == state.activeScope then Color3.fromRGB(72, 96, 140) else Color3.fromRGB(44, 48, 56)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.Text = scope.name
	button.TextColor3 = Color3.fromRGB(240, 242, 246)
	button.TextSize = 13
	button.Size = UDim2.fromOffset(120, 28)
	button.Position = UDim2.fromOffset(10 + (index - 1) * 126, 7)
	button.Parent = topBar
	button.MouseButton1Click:Connect(function()
		state.activeScope = index
		state.selectedNodeId = nil
		refresh()
	end)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
end

local function refreshTopBar()
	clearChildren(topBar)

	for index, scope in ipairs(state.scopes) do
		makeScopeButton(scope, index)
	end

	local addButton = Instance.new("TextButton")
	addButton.BackgroundColor3 = Color3.fromRGB(54, 72, 58)
	addButton.BorderSizePixel = 0
	addButton.Font = Enum.Font.GothamMedium
	addButton.Text = "+ Bake"
	addButton.TextColor3 = Color3.fromRGB(240, 242, 246)
	addButton.TextSize = 13
	addButton.Size = UDim2.fromOffset(82, 28)
	addButton.Position = UDim2.fromOffset(10 + #state.scopes * 126, 7)
	addButton.Parent = topBar
	addButton.MouseButton1Click:Connect(function()
		addBake()
		refresh()
	end)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = addButton
end

local function refreshPalette()
	clearChildren(paletteFrame)
	makeLabel(paletteFrame, "Nodes", 24)

	for _, family in ipairs({ "Source", "Material" }) do
		makeLabel(paletteFrame, family, 20)
		for _, typeName in ipairs(PALETTE[family]) do
			makeButton(paletteFrame, "+ " .. typeName, 30, function()
				addNode(typeName)
				refresh()
			end)
		end
	end

	makeLabel(paletteFrame, "Quick Graphs", 24)
	makeButton(paletteFrame, "Notes Sample", 30, function()
		state.moduleName = "GeneratedNotesMaterial"
		clearGraph()
		addBake()
		activeScope().name = "Pigment"
		activeScope().sharedKey = state.moduleName .. ".Pigment"
		activeScope().outputsText = [[noise = "pigment",]]
		addNode("FBMNoise")
		state.activeScope = 1
		addNode("NoiseToPalette")
		state.message = "Loaded notes sample."
		refresh()
	end)
	makeButton(paletteFrame, "ForceField Sample", 30, function()
		state.moduleName = "GeneratedForceFieldMaterial"
		clearGraph()
		addBake()
		activeScope().name = "ForceField"
		activeScope().sharedKey = state.moduleName .. ".ForceField"
		activeScope().outputsText = [[forceField = "forceField",]]
		addNode("ForceFieldIntensity")
		state.activeScope = 1
		addNode("ForceFieldMaterial")
		state.message = "Loaded force field sample."
		refresh()
	end)
	makeButton(paletteFrame, "Shine Sample", 30, function()
		state.moduleName = "GeneratedShineMaterial"
		clearGraph()
		addBake()
		activeScope().name = "Shine"
		activeScope().sharedKey = state.moduleName .. ".Shine"
		activeScope().outputsText = [[shine = "shine",]]
		addNode("ShineBand")
		state.activeScope = 1
		addNode("ShineMaterial")
		state.message = "Loaded shine sample."
		refresh()
	end)
end

local function nodeSummary(node: GraphNode): string
	local def = NODE_DEFS[node.typeName]
	local lines = { node.typeName, node.id }

	if #def.Inputs > 0 then
		local inputs = {}
		for _, inputName in ipairs(def.Inputs) do
			table.insert(inputs, inputName .. "<" .. (node.inputs[inputName] or inputName))
		end
		table.insert(lines, table.concat(inputs, "  "))
	end

	if #def.Outputs > 0 then
		local outputs = {}
		for _, outputName in ipairs(def.Outputs) do
			table.insert(outputs, outputName .. ">" .. (node.outputs[outputName] or outputName))
		end
		table.insert(lines, table.concat(outputs, "  "))
	end

	return table.concat(lines, "\n")
end

local function refreshCanvas()
	clearChildren(canvasFrame)

	local scope = activeScope()
	makeLabel(canvasFrame, scope.name .. " Graph", 26).Position = UDim2.fromOffset(18, 12)

	for index, node in ipairs(scope.nodes) do
		local card = Instance.new("TextButton")
		card.Name = node.id
		card.BackgroundColor3 = if node.id == state.selectedNodeId then Color3.fromRGB(68, 84, 116) else Color3.fromRGB(39, 43, 51)
		card.BorderColor3 = Color3.fromRGB(78, 88, 104)
		card.Font = Enum.Font.Code
		card.Text = nodeSummary(node)
		card.TextColor3 = Color3.fromRGB(238, 241, 246)
		card.TextSize = 12
		card.TextXAlignment = Enum.TextXAlignment.Left
		card.TextYAlignment = Enum.TextYAlignment.Top
		card.Size = UDim2.fromOffset(190, 112)
		card.Position = UDim2.fromOffset(node.x, node.y)
		card.Parent = canvasFrame
		card.MouseButton1Click:Connect(function()
			state.selectedNodeId = node.id
			refresh()
		end)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = card

		local numberLabel = Instance.new("TextLabel")
		numberLabel.BackgroundTransparency = 1
		numberLabel.Font = Enum.Font.GothamBold
		numberLabel.Text = tostring(index)
		numberLabel.TextColor3 = Color3.fromRGB(142, 153, 174)
		numberLabel.TextSize = 11
		numberLabel.Size = UDim2.fromOffset(24, 18)
		numberLabel.Position = UDim2.new(1, -26, 0, 4)
		numberLabel.Parent = card
	end
end

local function refreshInspector()
	clearChildren(inspectorFrame)

	makeLabel(inspectorFrame, "Graph", 22)
	makeLabel(inspectorFrame, "Module Name", 18)
	makeTextBox(inspectorFrame, state.moduleName, 28, function(text)
		state.moduleName = text
	end)
	makeLabel(inspectorFrame, "Size / FPS / Frames", 18)
	makeTextBox(inspectorFrame, state.width, 26, function(text)
		state.width = text
	end)
	makeTextBox(inspectorFrame, state.height, 26, function(text)
		state.height = text
	end)
	makeTextBox(inspectorFrame, state.targetFPS, 26, function(text)
		state.targetFPS = text
	end)
	makeTextBox(inspectorFrame, state.bakedFrameCount, 26, function(text)
		state.bakedFrameCount = text
	end)
	makeLabel(inspectorFrame, "Projection", 18)
	makeTextBox(inspectorFrame, state.projection, 26, function(text)
		state.projection = text
	end)
	makeLabel(inspectorFrame, "Workspace Includes", 18)
	makeTextBox(inspectorFrame, state.workspaceIncludes, 70, function(text)
		state.workspaceIncludes = text
	end)
	makeLabel(inspectorFrame, "Workspace Values", 18)
	makeTextBox(inspectorFrame, state.workspaceValues, 150, function(text)
		state.workspaceValues = text
	end)

	local scope = activeScope()
	if scope.kind == "Bake" then
		makeLabel(inspectorFrame, "Active Bake", 22)
		makeLabel(inspectorFrame, "Bake Name", 18)
		makeTextBox(inspectorFrame, scope.name, 26, function(text)
			scope.name = text
		end)
		makeLabel(inspectorFrame, "SharedKey", 18)
		makeTextBox(inspectorFrame, scope.sharedKey, 26, function(text)
			scope.sharedKey = text
		end)
		makeLabel(inspectorFrame, "Outputs", 18)
		makeTextBox(inspectorFrame, scope.outputsText, 70, function(text)
			scope.outputsText = text
		end)
		makeLabel(inspectorFrame, "Bake Workspace Includes", 18)
		makeTextBox(inspectorFrame, scope.workspaceIncludes, 60, function(text)
			scope.workspaceIncludes = text
		end)
		makeLabel(inspectorFrame, "Bake Workspace Values", 18)
		makeTextBox(inspectorFrame, scope.workspaceValues, 80, function(text)
			scope.workspaceValues = text
		end)
	end

	local selected = findSelectedNode()
	if selected ~= nil then
		local def = NODE_DEFS[selected.typeName]
		makeLabel(inspectorFrame, "Selected Node", 22)
		makeLabel(inspectorFrame, selected.typeName .. " (" .. def.Family .. ")", 20)
		makeLabel(inspectorFrame, "Id", 18)
		makeTextBox(inspectorFrame, selected.id, 26, function(text)
			selected.id = text
			state.selectedNodeId = text
		end)

		if #def.Inputs > 0 then
			makeLabel(inspectorFrame, "Inputs", 18)
			for _, inputName in ipairs(def.Inputs) do
				makeLabel(inspectorFrame, inputName, 16)
				makeTextBox(inspectorFrame, selected.inputs[inputName] or inputName, 24, function(text)
					selected.inputs[inputName] = text
				end)
			end
		end

		if #def.Outputs > 0 then
			makeLabel(inspectorFrame, "Outputs", 18)
			for _, outputName in ipairs(def.Outputs) do
				makeLabel(inspectorFrame, outputName, 16)
				makeTextBox(inspectorFrame, selected.outputs[outputName] or outputName, 24, function(text)
					selected.outputs[outputName] = text
				end)
			end
		end

		makeLabel(inspectorFrame, "Parameters", 18)
		makeTextBox(inspectorFrame, selected.parameters, 120, function(text)
			selected.parameters = text
		end)
		makeButton(inspectorFrame, "Delete Node", 30, function()
			local nodes = activeScope().nodes
			for index, node in ipairs(nodes) do
				if node.id == selected.id then
					table.remove(nodes, index)
					break
				end
			end
			state.selectedNodeId = nil
			refresh()
		end)
	end

	makeLabel(inspectorFrame, "SurfaceAppearance", 18)
	makeTextBox(inspectorFrame, state.surfaceAppearance, 90, function(text)
		state.surfaceAppearance = text
	end)

	makeButton(inspectorFrame, "Export ModuleScript", 34, function()
		exportModule()
		refresh()
	end)

	makeButton(inspectorFrame, "Clear Graph", 30, function()
		clearGraph()
		state.message = "Graph cleared."
		refresh()
	end)

	if state.message ~= "" then
		makeLabel(inspectorFrame, state.message, 42)
	end
end

function refresh()
	refreshTopBar()
	refreshPalette()
	refreshCanvas()
	refreshInspector()
end

clearGraph()
refresh()

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	toggleButton:SetActive(widget.Enabled)
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleButton:SetActive(widget.Enabled)
end)
