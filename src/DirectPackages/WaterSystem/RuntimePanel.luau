--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

export type RuntimePanel = {
	Start: (self: RuntimePanel) -> (),
	Destroy: (self: RuntimePanel) -> (),
	SetFolder: (self: RuntimePanel, folder: Instance?) -> (),
	SetVisible: (self: RuntimePanel, visible: boolean) -> (),
}

type Control = {
	Refresh: (() -> ())?,
	Destroy: (() -> ())?,
}

type InternalRuntimePanel = RuntimePanel & {
	_System: any,
	_Folder: Instance?,
	_Gui: ScreenGui?,
	_Main: Frame?,
	_Body: ScrollingFrame?,
	_CascadeContainer: ScrollingFrame?,
	_StatsLabel: TextLabel?,
	_CameraPositionLabel: TextLabel?,
	_Connections: { RBXScriptConnection },
	_BuildConnections: { RBXScriptConnection },
	_Controls: { Control },
	_ActiveCascade: number,
	_FrameCount: number,
	_FpsTime: number,
	_Fps: number,
	_Visible: boolean,
	_Fullscreen: boolean,
}

local RuntimePanelClass = {}
RuntimePanelClass.__index = RuntimePanelClass

local PANEL_WIDTH = 370
local ROW_HEIGHT = 22
local LABEL_WIDTH = 142
local THEME = {
	bg = Color3.fromRGB(17, 18, 18),
	panel = Color3.fromRGB(24, 25, 24),
	header = Color3.fromRGB(38, 72, 123),
	section = Color3.fromRGB(88, 88, 88),
	field = Color3.fromRGB(30, 55, 91),
	fieldDark = Color3.fromRGB(19, 32, 48),
	accent = Color3.fromRGB(69, 143, 235),
	text = Color3.fromRGB(236, 236, 226),
	muted = Color3.fromRGB(164, 164, 154),
}

local COLOR_SWATCHES = {
	Color3.fromRGB(19, 64, 76),
	Color3.fromRGB(12, 84, 107),
	Color3.fromRGB(27, 96, 115),
	Color3.fromRGB(20, 46, 52),
	Color3.fromRGB(34, 99, 87),
}

local FOAM_SWATCHES = {
	Color3.fromRGB(214, 210, 198),
	Color3.fromRGB(238, 237, 226),
	Color3.fromRGB(188, 205, 200),
	Color3.fromRGB(224, 196, 178),
	Color3.fromRGB(180, 180, 170),
}

local WAVE_RESOLUTION_OPTIONS = {
	{ label = "16x16", value = 16 },
	{ label = "28x28", value = 28 },
	{ label = "48x48", value = 48 },
	{ label = "64x64", value = 64 },
	{ label = "96x96", value = 96 },
}

local MESH_QUALITY_OPTIONS = {
	{ label = "Low", value = 18 },
	{ label = "High", value = 28 },
	{ label = "High8K", value = 48 },
	{ label = "Max", value = 96 },
}

local CASCADE_KEYS = {
	TileLengthX = "Tile Length",
	TileLengthY = "Tile Length Y",
	DisplacementScale = "Displacement Scale",
	NormalScale = "Normal Scale",
	WindSpeed = "Wind Speed",
	WindDirection = "Wind Direction",
	FetchLength = "Fetch Length",
	Swell = "Swell",
	Spread = "Spread",
	Detail = "Detail",
	Whitecap = "Whitecap",
	FoamAmount = "Foam Amount",
}

local CASCADE_DEFAULTS = {
	{
		TileLengthX = 200,
		TileLengthY = 200,
		DisplacementScale = 2,
		NormalScale = 2,
		WindSpeed = 40,
		WindDirection = 0,
		FetchLength = 800,
		Swell = 0.95,
		Spread = 0.18,
		Detail = 1,
		Whitecap = 0.55,
		FoamAmount = 6,
	},
	{
		TileLengthX = 80,
		TileLengthY = 80,
		DisplacementScale = 1,
		NormalScale = 1,
		WindSpeed = 20,
		WindDirection = 12,
		FetchLength = 360,
		Swell = 0.7,
		Spread = 0.28,
		Detail = 0.92,
		Whitecap = 0.45,
		FoamAmount = 4,
	},
	{
		TileLengthX = 52,
		TileLengthY = 52,
		DisplacementScale = 1,
		NormalScale = 1,
		WindSpeed = 20,
		WindDirection = -18,
		FetchLength = 550,
		Swell = 0.8,
		Spread = 0.2,
		Detail = 1,
		Whitecap = 0.5,
		FoamAmount = 5,
	},
}

local function make(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)

	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end

	instance.Parent = parent
	return instance
end

local function connect(self: InternalRuntimePanel, connection: RBXScriptConnection): RBXScriptConnection
	table.insert(self._Connections, connection)
	return connection
end

local function connectBuild(self: InternalRuntimePanel, connection: RBXScriptConnection): RBXScriptConnection
	table.insert(self._BuildConnections, connection)
	return connection
end

local function formatNumber(value: number, decimals: number?): string
	local places = decimals or 3
	return string.format("%." .. tostring(places) .. "f", value)
end

local function cascadeAttr(index: number, key: string): string
	return "OceanCascade" .. tostring(index) .. key
end

local function readNumber(folder: Instance?, name: string, fallback: number): number
	if folder == nil then
		return fallback
	end

	local value = folder:GetAttribute(name)

	if type(value) == "number" then
		return value
	end

	return fallback
end

local function readBoolean(folder: Instance?, name: string, fallback: boolean): boolean
	if folder == nil then
		return fallback
	end

	local value = folder:GetAttribute(name)

	if type(value) == "boolean" then
		return value
	end

	return fallback
end

local function readColor(folder: Instance?, name: string, fallback: Color3): Color3
	if folder == nil then
		return fallback
	end

	local value = folder:GetAttribute(name)

	if typeof(value) == "Color3" then
		return value
	end

	return fallback
end

local function writeAttribute(self: InternalRuntimePanel, name: string, value: any, rebuildTiles: boolean?)
	local folder = self._Folder

	if folder == nil then
		return
	end

	folder:SetAttribute(name, value)

	if self._System and self._System.RefreshFromAttributes then
		self._System:RefreshFromAttributes(rebuildTiles == true)
	end
end

local function section(parent: Instance, title: string): TextLabel
	return make("TextLabel", {
		BackgroundColor3 = THEME.panel,
		BorderColor3 = THEME.section,
		Font = Enum.Font.Code,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "  " .. title,
		TextColor3 = THEME.text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
	}, parent) :: TextLabel
end

local function row(parent: Instance, label: string): Frame
	local frame = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
	}, parent) :: Frame

	make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, LABEL_WIDTH, 1, 0),
		Text = label .. ":",
		TextColor3 = THEME.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
	}, frame)

	return frame
end

local function addNumericSlider(
	self: InternalRuntimePanel,
	parent: Instance,
	label: string,
	attrName: string,
	fallback: number,
	minValue: number,
	maxValue: number,
	decimals: number,
	rebuildTiles: boolean?
)
	local frame = row(parent, label)
	local valueLabel = make("TextLabel", {
		BackgroundColor3 = THEME.field,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(LABEL_WIDTH, 2),
		Size = UDim2.new(1, -LABEL_WIDTH, 0, 18),
		TextColor3 = THEME.text,
		TextSize = 12,
    ZIndex = 2,
	}, frame) :: TextLabel
	local fill = make("Frame", {
		BackgroundColor3 = THEME.accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(0, 1),
	}, valueLabel) :: Frame
	local hitbox = make("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, valueLabel) :: TextButton
	local dragging = false

	local function refresh()
		local value = readNumber(self._Folder, attrName, fallback)
		local alpha = math.clamp((value - minValue) / math.max(maxValue - minValue, 0.0001), 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		valueLabel.Text = formatNumber(value, decimals)
	end

	local function setFromX(x: number)
		local alpha = math.clamp((x - valueLabel.AbsolutePosition.X) / math.max(valueLabel.AbsoluteSize.X, 1), 0, 1)
		local value = minValue + (maxValue - minValue) * alpha
		local step = 10 ^ decimals

		if decimals <= 0 then
			value = math.round(value)
		else
			value = math.round(value * step) / step
		end

		writeAttribute(self, attrName, value, rebuildTiles)
		refresh()
	end

	connectBuild(self, hitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			setFromX(input.Position.X)
		end
	end))

	connectBuild(self, UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setFromX(input.Position.X)
		end
	end))

	connectBuild(self, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))

	refresh()
	table.insert(self._Controls, { Refresh = refresh })
end

local function addCheckbox(
	self: InternalRuntimePanel,
	parent: Instance,
	label: string,
	attrName: string,
	fallback: boolean,
	rebuildTiles: boolean?
)
	local frame = row(parent, label)
	local button = make("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = THEME.field,
		BorderColor3 = THEME.header,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(LABEL_WIDTH, 2),
		Size = UDim2.fromOffset(20, 18),
		TextColor3 = THEME.text,
		TextSize = 16,
	}, frame) :: TextButton

	local function refresh()
		button.Text = if readBoolean(self._Folder, attrName, fallback) then "X" else ""
	end

	connectBuild(self, button.Activated:Connect(function()
		writeAttribute(self, attrName, not readBoolean(self._Folder, attrName, fallback), rebuildTiles)
		refresh()
	end))

	refresh()
	table.insert(self._Controls, { Refresh = refresh })
end

local function addDropdown(
	self: InternalRuntimePanel,
	parent: Instance,
	label: string,
	attrName: string,
	options: { { label: string, value: number } },
	fallback: number,
	rebuildTiles: boolean?
)
	local frame = row(parent, label)
	local button = make("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = THEME.field,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(LABEL_WIDTH, 2),
		Size = UDim2.new(1, -LABEL_WIDTH, 0, 18),
		TextColor3 = THEME.text,
		TextSize = 12,
	}, frame) :: TextButton

	local function getIndex(): number
		local value = readNumber(self._Folder, attrName, fallback)

		for index, option in ipairs(options) do
			if option.value == value then
				return index
			end
		end

		return 1
	end

	local function refresh()
		local option = options[getIndex()]
		button.Text = option.label .. "     v"
	end

	connectBuild(self, button.Activated:Connect(function()
		local nextIndex = (getIndex() % #options) + 1
		writeAttribute(self, attrName, options[nextIndex].value, rebuildTiles)
		refresh()
	end))

	refresh()
	table.insert(self._Controls, { Refresh = refresh })
end

local function addTextBox(
	self: InternalRuntimePanel,
	parent: Instance,
	label: string,
	attrName: string,
	fallback: string,
	rebuildTiles: boolean?
)
	local frame = row(parent, label)
	local box = make("TextBox", {
		BackgroundColor3 = THEME.fieldDark,
		BorderColor3 = THEME.section,
		ClearTextOnFocus = false,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(LABEL_WIDTH, 2),
		Size = UDim2.new(1, -LABEL_WIDTH, 0, 18),
		TextColor3 = THEME.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame) :: TextBox

	local function refresh()
		local folder = self._Folder
		local value = if folder then folder:GetAttribute(attrName) else nil
		box.Text = if type(value) == "string" then value else fallback
	end

	connectBuild(self, box.FocusLost:Connect(function()
		writeAttribute(self, attrName, box.Text, rebuildTiles)
		refresh()
	end))

	refresh()
	table.insert(self._Controls, { Refresh = refresh })
end

local function addColorCycler(
	self: InternalRuntimePanel,
	parent: Instance,
	label: string,
	attrName: string,
	swatches: { Color3 },
	fallback: Color3
)
	local frame = row(parent, label)
	local button = make("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = fallback,
		BorderColor3 = THEME.section,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(LABEL_WIDTH, 2),
		Size = UDim2.new(1, -LABEL_WIDTH, 0, 18),
		Text = "",
	}, frame) :: TextButton

	local function refresh()
		button.BackgroundColor3 = readColor(self._Folder, attrName, fallback)
	end

	connectBuild(self, button.Activated:Connect(function()
		local current = readColor(self._Folder, attrName, fallback)
		local index = 1

		for swatchIndex, swatch in ipairs(swatches) do
			local delta = math.abs(swatch.R - current.R) + math.abs(swatch.G - current.G) + math.abs(swatch.B - current.B)

			if delta < 0.02 then
				index = swatchIndex
				break
			end
		end

		local nextColor = swatches[(index % #swatches) + 1]
		writeAttribute(self, attrName, nextColor, true)
		refresh()
	end))

	refresh()
	table.insert(self._Controls, { Refresh = refresh })
end

local function clearChildren(instance: Instance)
	for _, child in ipairs(instance:GetChildren()) do
		child:Destroy()
	end
end

function RuntimePanelClass:_RefreshControls()
	for _, control in ipairs(self._Controls) do
		if control.Refresh then
			control.Refresh()
		end
	end
end

function RuntimePanelClass:_BuildCascadeControls()
	local container = self._CascadeContainer

	if container == nil then
		return
	end

	clearChildren(container)

	local cascadeLayout = make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, container) :: UIListLayout

	connectBuild(self, cascadeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		container.CanvasSize = UDim2.fromOffset(0, cascadeLayout.AbsoluteContentSize.Y)
	end))

	local tabs = make("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 2,
		Size = UDim2.new(1, 0, 0, 24),
	}, container) :: ScrollingFrame

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabs)

	for index = 1, 3 do
		local button = make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = if self._ActiveCascade == index then THEME.header else THEME.field,
			BorderColor3 = THEME.section,
			Font = Enum.Font.Code,
			Selected = self._ActiveCascade == index,
			Size = UDim2.fromOffset(72, 20),
			Text = "Cascade " .. tostring(index),
			TextColor3 = THEME.text,
			TextSize = 12,
		}, tabs) :: TextButton

		connectBuild(self, button.Activated:Connect(function()
			self._ActiveCascade = index
			self:_Build()
		end))
	end

	local defaults = CASCADE_DEFAULTS[self._ActiveCascade]
	local prefix = "OceanCascade" .. tostring(self._ActiveCascade)

	addNumericSlider(self, container, CASCADE_KEYS.TileLengthX, prefix .. "TileLengthX", defaults.TileLengthX, 2, 200, 3, false)
	addNumericSlider(self, container, CASCADE_KEYS.TileLengthY, prefix .. "TileLengthY", defaults.TileLengthY, 2, 200, 3, false)
	addNumericSlider(self, container, CASCADE_KEYS.DisplacementScale, prefix .. "DisplacementScale", defaults.DisplacementScale, 0, 2, 3, false)
	addNumericSlider(self, container, CASCADE_KEYS.NormalScale, prefix .. "NormalScale", defaults.NormalScale, 0, 2, 3, false)
	section(container, "Wave Parameters")
	addNumericSlider(self, container, CASCADE_KEYS.WindSpeed, prefix .. "WindSpeed", defaults.WindSpeed, 0.1, 40, 3, false)
	addNumericSlider(self, container, CASCADE_KEYS.WindDirection, prefix .. "WindDirection", defaults.WindDirection, -180, 180, 0, false)
	addNumericSlider(self, container, CASCADE_KEYS.FetchLength, prefix .. "FetchLength", defaults.FetchLength, 1, 800, 3, false)
	addNumericSlider(self, container, CASCADE_KEYS.Swell, prefix .. "Swell", defaults.Swell, 0, 2, 3, false)
	addNumericSlider(self, container, CASCADE_KEYS.Spread, prefix .. "Spread", defaults.Spread, 0, 1, 3, false)
	addNumericSlider(self, container, CASCADE_KEYS.Detail, prefix .. "Detail", defaults.Detail, 0, 1, 3, false)
	section(container, "Foam")
	addNumericSlider(self, container, CASCADE_KEYS.Whitecap, prefix .. "Whitecap", defaults.Whitecap, 0, 2, 3, false)
	addNumericSlider(self, container, CASCADE_KEYS.FoamAmount, prefix .. "FoamAmount", defaults.FoamAmount, 0, 10, 3, false)
end

function RuntimePanelClass:_Build()
	local body = self._Body

	if body == nil then
		return
	end

	for _, connection in ipairs(self._BuildConnections) do
		connection:Disconnect()
	end

	table.clear(self._BuildConnections)
	table.clear(self._Controls)
	clearChildren(body)

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, body)

	section(body, "OceanWaves")

	self._StatsLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Text = "FPS:",
		TextColor3 = THEME.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
	}, body) :: TextLabel

	addCheckbox(self, body, "Enable Sea Spray", "OceanEnableSeaSpray", true, false)
	addTextBox(self, body, "Sea Spray AssetID", "OceanSeaSprayTextureId", "", true)
	addNumericSlider(self, body, "Sea Spray Rate", "OceanSeaSprayRate", 90, 0, 400, 0, false)
	addDropdown(self, body, "Max Mesh Resolution", "OceanResolution", WAVE_RESOLUTION_OPTIONS, 96, true)
	addNumericSlider(self, body, "Vertex Spacing", "OceanVertexSpacing", 9, 2, 32, 1, true)
	addDropdown(self, body, "Wave Mesh Quality", "OceanResolution", MESH_QUALITY_OPTIONS, 96, true)
	addNumericSlider(self, body, "Updates per Second", "OceanUpdatesPerSecond", 30, 0, 60, 3, false)
	addNumericSlider(self, body, "Load Distance", "OceanLoadDistance", 1024, 64, 4096, 0, false)
	addNumericSlider(self, body, "Unload Distance", "OceanUnloadDistance", 1152, 64, 4096, 0, false)
	addNumericSlider(self, body, "Near Update FPS", "OceanNearUpdatesPerSecond", 30, 0, 60, 0, false)
	addNumericSlider(self, body, "Mid Update FPS", "OceanMidUpdatesPerSecond", 8, 0, 60, 0, false)
	addNumericSlider(self, body, "Far Update FPS", "OceanFarUpdatesPerSecond", 2, 0, 30, 0, false)
	addCheckbox(self, body, "Get displacement textures from GPU", "OceanCpuReadback", true, false)
	addCheckbox(self, body, "Interactive Ripples", "OceanInteractiveWavesEnabled", true, true)
	addNumericSlider(self, body, "Physics Distance", "OceanPhysicsDistance", 220, 0, 1024, 0, false)
	addNumericSlider(self, body, "Foam Distance", "OceanFoamDistance", 220, 0, 1024, 0, false)
	addNumericSlider(self, body, "Ripple Resolution", "OceanInteractiveResolution", 64, 8, 256, 0, true)
	addNumericSlider(self, body, "Ripple Iterations", "OceanInteractiveSimulationIterations", 1, 1, 8, 0, false)
	addNumericSlider(self, body, "Ripple Damping", "OceanInteractiveDamping", 0.992, 0.9, 1, 3, true)
	addNumericSlider(self, body, "Ripple Max Height", "OceanInteractiveMaxHeight", 5, 0.1, 16, 1, true)
	addNumericSlider(self, body, "Sphere Scale", "OceanInteractiveMoveSphereScale", 0.18, 0, 1, 2, true)
	addNumericSlider(self, body, "Ripple Foam", "OceanInteractiveFoamStrength", 0.85, 0, 3, 2, false)
	addNumericSlider(self, body, "Ripple LOD Fade", "OceanInteractiveLodDissipation", 0.82, 0, 1, 2, false)

	section(body, "Depth / LOD")
	addCheckbox(self, body, "Depth Map", "OceanDepthMapEnabled", true, true)
	addNumericSlider(self, body, "Depth Resolution", "OceanDepthMapResolution", 12, 2, 32, 0, true)
	addNumericSlider(self, body, "Shallow Depth", "OceanShallowDepth", 8, 0, 32, 1, false)
	addNumericSlider(self, body, "Lake Depth", "OceanLakeDepth", 42, 1, 128, 1, false)
	addNumericSlider(self, body, "Ocean Depth", "OceanOceanDepth", 96, 4, 220, 1, false)
	addNumericSlider(self, body, "Shallow Waves", "OceanShallowWaveScale", 0.28, 0, 2, 2, false)
	addNumericSlider(self, body, "Deep Waves", "OceanDeepWaveScale", 1.08, 0, 3, 2, false)
	addNumericSlider(self, body, "Bake Frames", "OceanWaveLoopFrames", 48, 8, 160, 0, false)
	addNumericSlider(self, body, "Bake Seconds", "OceanWaveLoopDuration", 18, 2, 60, 0, false)
	addNumericSlider(self, body, "Far Wave Detail", "OceanFarWaveDetail", 0.42, 0.05, 1, 2, false)
	addNumericSlider(self, body, "LOD0 Radius", "OceanLod0Radius", 220, 0, 2048, 0, false)
	addNumericSlider(self, body, "LOD1 Radius", "OceanLod1Radius", 512, 0, 4096, 0, false)
	addNumericSlider(self, body, "LOD2 Radius", "OceanLod2Radius", 1024, 0, 8192, 0, false)
	addNumericSlider(self, body, "LOD Recenter", "OceanLodRecenterDistance", 64, 1, 512, 0, false)
	addCheckbox(self, body, "Volume Mesh", "OceanVolumeEnabled", true, true)
	addNumericSlider(self, body, "Side Spacing", "OceanVolumeSideSpacing", 36, 4, 128, 0, true)
	addNumericSlider(self, body, "Side Segments", "OceanVolumeVerticalSegments", 3, 1, 8, 0, true)
	addNumericSlider(self, body, "Bottom Resolution", "OceanVolumeBottomResolution", 6, 1, 24, 0, true)
	addNumericSlider(self, body, "Volume Waves", "OceanVolumeWaveScale", 0.22, 0, 1, 2, true)
	addCheckbox(self, body, "Chunk LOD", "OceanChunkLodEnabled", true, true)
	addNumericSlider(self, body, "Chunk LOD0 Dist", "OceanChunkLod0Distance", 100, 0, 2048, 0, true)
	addNumericSlider(self, body, "Chunk LOD1 Dist", "OceanChunkLod1Distance", 300, 0, 4096, 0, true)
	addNumericSlider(self, body, "Chunk LOD2 Dist", "OceanChunkLod2Distance", 600, 0, 8192, 0, true)
	addNumericSlider(self, body, "LOD Hysteresis", "OceanChunkLodHysteresis", 64, 0, 256, 0, false)
	addNumericSlider(self, body, "LOD Cooldown", "OceanChunkLodSwitchCooldown", 0.85, 0, 4, 2, false)
	addNumericSlider(self, body, "Chunk LOD0 Res", "OceanChunkLod0Resolution", 96, 2, 160, 0, true)
	addNumericSlider(self, body, "Chunk LOD1 Res", "OceanChunkLod1Resolution", 64, 2, 160, 0, true)
	addNumericSlider(self, body, "Chunk LOD2 Res", "OceanChunkLod2Resolution", 32, 2, 160, 0, true)
	addNumericSlider(self, body, "Chunk LOD3 Res", "OceanChunkLod3Resolution", 16, 2, 160, 0, true)
	addCheckbox(self, body, "View Culling", "OceanViewCullingEnabled", true, false)
	addNumericSlider(self, body, "Culling Padding", "OceanViewCullingPadding", 96, 0, 1024, 0, false)
	addNumericSlider(self, body, "Mid Vertex Step", "OceanMidLodVertexStep", 2, 1, 16, 0, true)
	addNumericSlider(self, body, "Far Vertex Step", "OceanFarLodVertexStep", 4, 1, 24, 0, true)
	addNumericSlider(self, body, "Extreme Vertex Step", "OceanExtremeLodVertexStep", 8, 1, 32, 0, true)

	section(body, "Localized Foam")
	addCheckbox(self, body, "Surface Buffer", "OceanFoamBufferEnabled", true, false)
	addNumericSlider(self, body, "Foam Resolution", "OceanFoamBufferResolution", 48, 2, 62, 0, true)
	addNumericSlider(self, body, "Foam Decay", "OceanFoamBufferDecay", 0.72, 0, 3, 2, false)
	addNumericSlider(self, body, "Foam Growth", "OceanFoamBufferGrowth", 7.5, 0, 30, 2, false)
	addTextBox(self, body, "Obstacle Root", "OceanObstacleRootName", "WaterObstacles", true)
	addCheckbox(self, body, "Bake Anchored", "OceanBakeAnchoredObstacles", true, true)
	addNumericSlider(self, body, "Shore Foam", "OceanShoreFoamStrength", 0.62, 0, 3, 2, false)
	addNumericSlider(self, body, "Obstacle Foam", "OceanObstacleFoamStrength", 0.9, 0, 3, 2, false)
	addNumericSlider(self, body, "Crest Foam", "OceanCrestFoamStrength", 0.72, 0, 3, 2, false)
	addNumericSlider(self, body, "High Wave Foam", "OceanHighWaveFoamStrength", 0.75, 0, 3, 2, false)
	addNumericSlider(self, body, "Obstacle Damping", "OceanObstacleWaveDamping", 0.65, 0, 1, 2, false)
	addCheckbox(self, body, "Obstacle Splash", "OceanStaticObstacleSplashEnabled", true, false)
	addNumericSlider(self, body, "Splash Interval", "OceanStaticObstacleSplashInterval", 0.45, 0.05, 2, 2, false)

	section(body, "Physics")
	addCheckbox(self, body, "Physical Objects", "OceanPhysicalInteractionEnabled", true, false)
	addCheckbox(self, body, "Player Box", "OceanPlayerInteractionEnabled", true, false)
	addCheckbox(self, body, "Buoyancy", "OceanBuoyancyEnabled", true, false)
	addNumericSlider(self, body, "Buoyancy Force", "OceanBuoyancyStrength", 38, 0, 120, 1, false)
	addNumericSlider(self, body, "Buoyancy Damping", "OceanBuoyancyDamping", 7, 0, 30, 1, false)
	addNumericSlider(self, body, "Water Drag", "OceanBuoyancyLinearDrag", 0.9, 0, 6, 2, false)
	addNumericSlider(self, body, "Angular Drag", "OceanBuoyancyAngularDrag", 0.7, 0, 6, 2, false)
	addNumericSlider(self, body, "Impact Speed", "OceanPhysicalImpactSpeed", 8, 0.1, 40, 1, false)
	addNumericSlider(self, body, "Interaction Radius", "OceanPhysicalRadiusScale", 0.55, 0.1, 1.5, 2, false)
	addCheckbox(self, body, "Splash Particles", "OceanSplashParticlesEnabled", true, false)
	addNumericSlider(self, body, "Splash Amount", "OceanSplashParticleEmitScale", 1, 0, 4, 2, false)
	addTextBox(self, body, "Splash Asset", "OceanSplashParticleTextureId", "", false)

	section(body, "Player / Camera")
	addCheckbox(self, body, "Surface Float", "OceanPlayerSurfaceFloatEnabled", true, false)
	addNumericSlider(self, body, "Float Influence", "OceanPlayerSurfaceInfluenceDepth", 3.5, 0, 12, 1, false)
	addNumericSlider(self, body, "Float Smooth", "OceanPlayerSurfaceSmoothness", 10, 0.1, 30, 1, false)
	addNumericSlider(self, body, "Float Offset", "OceanPlayerSurfaceOffset", -0.35, -4, 4, 2, false)
	addNumericSlider(self, body, "Float Max Speed", "OceanPlayerSurfaceMaxVerticalSpeed", 18, 1, 64, 0, false)
	addCheckbox(self, body, "Swim Anim", "OceanPlayerSwimAnimationEnabled", true, false)
	addNumericSlider(self, body, "Swim Move Threshold", "OceanPlayerSwimMovementThreshold", 0.12, 0, 1, 2, false)
	addNumericSlider(self, body, "Swim Depth", "OceanPlayerSwimDepth", 2.8, 0, 12, 1, false)
	addCheckbox(self, body, "Underwater FX", "OceanUnderwaterEffectsEnabled", true, false)
	addNumericSlider(self, body, "Underwater Start", "OceanUnderwaterDepthStart", 0.25, 0, 8, 2, false)
	addNumericSlider(self, body, "Underwater Full", "OceanUnderwaterDepthFull", 18, 1, 80, 0, false)
	addCheckbox(self, body, "Camera Drops", "OceanCameraDropsEnabled", true, false)
	addNumericSlider(self, body, "Drop Count", "OceanCameraDropCount", 14, 1, 32, 0, false)
	addNumericSlider(self, body, "Drop Duration", "OceanCameraDropDuration", 1.4, 0.1, 5, 1, false)

	addColorCycler(self, body, "Water Color", "OceanWaterColor", COLOR_SWATCHES, Color3.fromRGB(19, 64, 76))
	addColorCycler(self, body, "Tint Color", "OceanWaterTintColor", COLOR_SWATCHES, Color3.fromRGB(31, 143, 128))
	addColorCycler(self, body, "Foam Color", "OceanFoamColor", FOAM_SWATCHES, Color3.fromRGB(214, 210, 198))
	addNumericSlider(self, body, "Water Vertex Alpha", "OceanWaterVertexAlpha", 0.5, 0, 1, 3, true)
	addNumericSlider(self, body, "Foam Vertex Alpha", "OceanFoamVertexAlpha", 1, 0, 1, 3, true)
	addNumericSlider(self, body, "Foam Vertex Boost", "OceanFoamVertexBoost", 1.75, 0, 4, 3, false)
	addNumericSlider(self, body, "Vertex Pattern", "OceanFoamNoiseInfluence", 0.65, 0, 1, 3, false)
	addCheckbox(self, body, "Runtime Color", "OceanRuntimeSurfaceColorEnabled", false, false)
	addTextBox(self, body, "Foam Asset Override", "OceanFoamTextureId", "", true)
	addCheckbox(self, body, "Surface Image", "OceanFoamTextureFromVerticesEnabled", true, true)
	addNumericSlider(self, body, "Foam Image Res", "OceanFoamTextureResolution", 256, 16, 1024, 0, true)
	addNumericSlider(self, body, "Foam Image FPS", "OceanFoamTextureUpdateInterval", 0.08, 0, 0.5, 2, false)
	addNumericSlider(self, body, "Foam Layer Fade", "OceanFoamTextureTransparency", 0.72, 0, 1, 3, false)
	addNumericSlider(self, body, "Vertex Pattern Tile", "OceanFoamTextureStudsPerTile", 18, 1, 96, 0, false)
	addCheckbox(self, body, "Underwater DOF", "OceanUnderwaterDepthOfFieldEnabled", true, false)
	addNumericSlider(self, body, "DOF Focus", "OceanUnderwaterDepthOfFieldFocusDistance", 18, 1, 80, 0, false)
	addNumericSlider(self, body, "DOF Radius", "OceanUnderwaterDepthOfFieldInFocusRadius", 14, 1, 80, 0, false)
	addNumericSlider(self, body, "DOF Near", "OceanUnderwaterDepthOfFieldNearIntensity", 0.08, 0, 1, 2, false)
	addNumericSlider(self, body, "DOF Far", "OceanUnderwaterDepthOfFieldFarIntensity", 0.55, 0, 1, 2, false)
	addNumericSlider(self, body, "Vertex Pattern Size", "OceanFoamNoiseSize", 128, 16, 512, 0, true)
	addNumericSlider(self, body, "Vertex Pattern Seed", "OceanFoamNoiseSeed", 1234, 0, 9999, 0, true)

	section(body, "Wave Parameters")
	self._CascadeContainer = make("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundColor3 = THEME.panel,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 4,
		Size = UDim2.new(1, 0, 0, 322),
	}, body) :: ScrollingFrame

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self._CascadeContainer)

	self:_BuildCascadeControls()

	section(body, "Camera")
	self._CameraPositionLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Text = "Camera Position:",
		TextColor3 = THEME.text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
	}, body) :: TextLabel

	addNumericSlider(self, body, "Camera FOV", "OceanPanelCameraFOV", workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70, 20, 100, 3, false)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "Press Ctrl-H to toggle GUI visibility.\nPress Ctrl-F to toggle fullscreen.",
		TextColor3 = THEME.muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 2,
	}, body)

	self:_RefreshControls()
end

function RuntimePanelClass:_UpdateStats(deltaTime: number)
	self._FrameCount += 1
	self._FpsTime += deltaTime

	if self._FpsTime >= 0.25 then
		self._Fps = self._FrameCount / self._FpsTime
		self._FrameCount = 0
		self._FpsTime = 0
	end

	if self._StatsLabel then
		local ms = if self._Fps > 0 then 1000 / self._Fps else 0
		self._StatsLabel.Text = "FPS:                 " .. tostring(math.round(self._Fps)) .. " (" .. formatNumber(ms, 2) .. "ms)"
	end

	local camera = workspace.CurrentCamera

	if camera ~= nil then
		if self._CameraPositionLabel then
			local position = camera.CFrame.Position
			self._CameraPositionLabel.Text = string.format(
				"Camera Position:    (%.2f, %.2f, %.2f)",
				position.X,
				position.Y,
				position.Z
			)
		end

		local folder = self._Folder
		if folder ~= nil then
			local targetFov = readNumber(folder, "OceanPanelCameraFOV", camera.FieldOfView)
			if math.abs(camera.FieldOfView - targetFov) > 0.01 then
				camera.FieldOfView = targetFov
			end
		end
	end
end

function RuntimePanelClass:SetFolder(folder: Instance?)
	self._Folder = folder
	self:_RefreshControls()
end

function RuntimePanelClass:SetVisible(visible: boolean)
	self._Visible = visible

	if self._Gui then
		self._Gui.Enabled = visible
	end
end

function RuntimePanelClass:Start()
	if self._Gui ~= nil then
		return
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = make("ScreenGui", {
		Name = "OceanWavesRuntimePanel",
		DisplayOrder = 999,
		IgnoreGuiInset = false,
		ResetOnSpawn = false,
		Enabled = self._Visible,
	}, playerGui) :: ScreenGui

	local main = make("Frame", {
		BackgroundColor3 = THEME.bg,
		BorderColor3 = Color3.fromRGB(110, 110, 100),
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(PANEL_WIDTH, 640),
	}, gui) :: Frame

	make("TextLabel", {
		BackgroundColor3 = THEME.header,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "v",
		TextColor3 = THEME.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
	}, main)

	local scroll = make("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.panel,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(8, 30),
		ScrollBarThickness = 4,
		Size = UDim2.new(1, -16, 1, -38),
	}, main) :: ScrollingFrame

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)

	self._Gui = gui
	self._Main = main
	self._Body = scroll

	self:_Build()

	connect(self, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.KeyCode == Enum.KeyCode.Unknown then
			return
		end

		local ctrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

		if ctrlDown and input.KeyCode == Enum.KeyCode.H then
			self:SetVisible(not self._Visible)
		elseif ctrlDown and input.KeyCode == Enum.KeyCode.F then
			self._Fullscreen = not self._Fullscreen

			if self._Fullscreen then
				main.Position = UDim2.fromOffset(0, 0)
				main.Size = UDim2.fromScale(1, 1)
			else
				main.Position = UDim2.fromOffset(8, 8)
				main.Size = UDim2.fromOffset(PANEL_WIDTH, 640)
			end
		end
	end))

	connect(self, RunService.RenderStepped:Connect(function(deltaTime)
		self:_UpdateStats(deltaTime)
	end))
end

function RuntimePanelClass:Destroy()
	for _, connection in ipairs(self._Connections) do
		connection:Disconnect()
	end

	for _, connection in ipairs(self._BuildConnections) do
		connection:Disconnect()
	end

	table.clear(self._Connections)
	table.clear(self._BuildConnections)
	table.clear(self._Controls)

	if self._Gui then
		self._Gui:Destroy()
		self._Gui = nil
	end
end

local RuntimePanel = {}

function RuntimePanel.new(system: any): RuntimePanel
	return setmetatable({
		_System = system,
		_Folder = nil,
		_Gui = nil,
		_Main = nil,
		_Body = nil,
		_CascadeContainer = nil,
		_StatsLabel = nil,
		_CameraPositionLabel = nil,
		_Connections = {},
		_BuildConnections = {},
		_Controls = {},
		_ActiveCascade = 1,
		_FrameCount = 0,
		_FpsTime = 0,
		_Fps = 0,
		_Visible = true,
		_Fullscreen = false,
	}, RuntimePanelClass) :: any
end

return RuntimePanel
