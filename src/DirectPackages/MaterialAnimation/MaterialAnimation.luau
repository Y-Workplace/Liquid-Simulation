local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local AnimationProjection = require(script.Parent.Parent.AnimationProjection)
local Graph = require(script.Parent.Graph)
local WorkspaceRuntime = require(script.Parent.Workspace)

export type ChannelName = "ColorMap" | "EmissiveMask"

export type Sample = {
	color: Color3?,
	alpha: number?,
	emissive: number?,
	emissiveColor: Color3?,
	emissiveAlpha: number?,
	[string]: any,
}

export type PixelContext = {
	x: number,
	y: number,
	u: number,
	v: number,
	width: number,
	height: number,
	frame: number,
	frameCount: number,
	t: number,
	progress: number,
	cycleT: number,
	projectionMode: AnimationProjection.ProjectionMode,
	config: any,
	state: any,
	workspace: any,
	nodeState: any?,
}

export type SurfaceAppearanceConfig = {
	AlphaMode: Enum.AlphaMode?,
	EmissiveStrength: number?,
	EmissiveTint: Color3?,
	Name: string?,
}

export type NodeInstance = {
	Id: string?,
	Type: string,
	Parameters: any?,
	Inputs: { [string]: string }?,
	Outputs: { [string]: string }?,
}

export type Definition = {
	Width: number?,
	Height: number?,
	Size: Vector2?,
	TargetFPS: number?,
	BakedFrameCount: number?,
	LoopDuration: number?,
	Projection: AnimationProjection.ProjectionMode?,
	SphericalNormalization: boolean?,
	Channels: { ChannelName }?,
	Nodes: { NodeInstance },
	Workspace: any?,
	Config: any?,
	SurfaceAppearance: SurfaceAppearanceConfig?,
	YieldEveryFrame: boolean?,
}

export type MaterialAnimation = {
	channels: { ChannelName },
	framesByChannel: { [ChannelName]: { buffer } },
	editables: { [ChannelName]: EditableImage },
	nodes: { Graph.CompiledNode },
	projectionMode: AnimationProjection.ProjectionMode,
	config: any,
	workspace: any,
	workspaceRuntime: any,
	surfaceAppearance: SurfaceAppearanceConfig?,
	yieldEveryFrame: boolean,
	dependsOnTime: boolean,
	connection: RBXScriptConnection?,
	accumulator: number,
	frameIndex: number,
	Init: (self: MaterialAnimation) -> (),
	Start: (self: MaterialAnimation) -> (),
	Stop: (self: MaterialAnimation) -> (),
	Destroy: (self: MaterialAnimation) -> (),
	GetEditable: (self: MaterialAnimation, channel: ChannelName) -> EditableImage?,
	GetSurfaceAppearanceConfig: (self: MaterialAnimation) -> SurfaceAppearanceConfig?,
	HasChannel: (self: MaterialAnimation, channel: ChannelName) -> boolean,
}

local DEFAULT_WIDTH = 64
local DEFAULT_HEIGHT = 64
local DEFAULT_TARGET_FPS = 15
local DEFAULT_BAKED_FRAME_COUNT = 180
local BYTES_PP = 4
local TAU = math.pi * 2

local MaterialAnimationClass = {}
MaterialAnimationClass.__index = MaterialAnimationClass

local function resolveDimension(value: number?, fallback: number): number
	if value == nil then
		return fallback
	end

	return math.max(1, math.round(value))
end

local function resolveBakedFrameCount(definition: Definition, targetFPS: number): number
	if definition.BakedFrameCount ~= nil then
		return math.max(1, math.round(definition.BakedFrameCount))
	end

	if definition.LoopDuration ~= nil then
		return math.max(2, math.round(definition.LoopDuration * targetFPS))
	end

	return DEFAULT_BAKED_FRAME_COUNT
end

local function resolveConfig(definition: Definition): any
	local size = definition.Size
	local width = resolveDimension(definition.Width, if size then size.X else DEFAULT_WIDTH)
	local height = resolveDimension(definition.Height, if size then size.Y else DEFAULT_HEIGHT)
	local targetFPS = definition.TargetFPS or DEFAULT_TARGET_FPS
	local bakedFrameCount = resolveBakedFrameCount(definition, targetFPS)

	local config = definition.Config or {}
	config.width = width
	config.height = height
	config.size = Vector2.new(width, height)
	config.targetFPS = targetFPS
	config.frameTime = 1 / targetFPS
	config.bakedFrameCount = bakedFrameCount
	config.totalBytes = width * height * BYTES_PP

	return config
end

local function setPixel(config: any, buf: buffer, x: number, y: number, color: Color3, alpha: number)
	local idx = (y * config.width + x) * BYTES_PP

	buffer.writeu8(buf, idx + 0, math.clamp(math.floor(color.R * 255), 0, 255))
	buffer.writeu8(buf, idx + 1, math.clamp(math.floor(color.G * 255), 0, 255))
	buffer.writeu8(buf, idx + 2, math.clamp(math.floor(color.B * 255), 0, 255))
	buffer.writeu8(buf, idx + 3, math.clamp(math.floor(alpha * 255), 0, 255))
end

local function writeSampleChannel(config: any, channel: ChannelName, buf: buffer, x: number, y: number, sample: Sample)
	if channel == "EmissiveMask" then
		local emissiveColor = sample.emissiveColor
		if emissiveColor == nil then
			local emissive = sample.emissive or 0
			emissiveColor = Color3.new(emissive, emissive, emissive)
		end

		setPixel(config, buf, x, y, emissiveColor, if sample.emissiveAlpha ~= nil then sample.emissiveAlpha else 1)
		return
	end

	setPixel(config, buf, x, y, sample.color or Color3.new(0, 0, 0), if sample.alpha ~= nil then sample.alpha else 1)
end

local function cloneChannels(channels: { ChannelName }?): { ChannelName }
	if channels == nil then
		return { "ColorMap" }
	end

	local result = table.create(#channels)
	for _, channel in ipairs(channels) do
		table.insert(result, channel)
	end

	return result
end

function MaterialAnimationClass.new(definition: Definition): MaterialAnimation
	local channels = cloneChannels(definition.Channels)
	local framesByChannel = {}
	local config = resolveConfig(definition)
	local projectionMode = AnimationProjection.Resolve(definition)
	local workspaceRuntime = WorkspaceRuntime.new(definition.Workspace or {}, {
		width = config.width,
		height = config.height,
		bakedFrameCount = config.bakedFrameCount,
		projectionMode = projectionMode,
		yieldEveryFrame = definition.YieldEveryFrame == true,
	})
	local workspace = workspaceRuntime:GetStaticValues()
	local nodes, dependsOnTime = Graph.Compile(definition.Nodes, workspace, workspaceRuntime:GetAvailableKeys())

	for _, channel in ipairs(channels) do
		framesByChannel[channel] = {}
	end

	return setmetatable({
		channels = channels,
		framesByChannel = framesByChannel,
		editables = {},
		nodes = nodes,
		projectionMode = projectionMode,
		config = config,
		workspace = workspace,
		workspaceRuntime = workspaceRuntime,
		surfaceAppearance = definition.SurfaceAppearance,
		yieldEveryFrame = definition.YieldEveryFrame == true,
		dependsOnTime = dependsOnTime,
		connection = nil,
		accumulator = 0,
		frameIndex = 1,
	}, MaterialAnimationClass) :: any
end

function MaterialAnimationClass:HasChannel(channel: ChannelName): boolean
	return self.framesByChannel[channel] ~= nil
end

function MaterialAnimationClass:GetEditable(channel: ChannelName): EditableImage?
	return self.editables[channel]
end

function MaterialAnimationClass:GetSurfaceAppearanceConfig(): SurfaceAppearanceConfig?
	return self.surfaceAppearance
end

function MaterialAnimationClass:_IsInitialized(): boolean
	for _, channel in ipairs(self.channels) do
		if self.editables[channel] == nil then
			return false
		end
	end

	return true
end

function MaterialAnimationClass:_EvaluatePixel(context: PixelContext): Sample
	return Graph.Evaluate(self.nodes, context, context.workspace) :: Sample
end

function MaterialAnimationClass:_BakeFrames()
	for _, channel in ipairs(self.channels) do
		table.clear(self.framesByChannel[channel])
	end

	local config = self.config
	local context = {
		x = 0,
		y = 0,
		u = 0,
		v = 0,
		width = config.width,
		height = config.height,
		frame = 1,
		frameCount = config.bakedFrameCount,
		t = 0,
		progress = 0,
		cycleT = 0,
		projectionMode = self.projectionMode,
		config = config,
		state = {},
		workspace = self.workspace,
		nodeState = nil,
	} :: PixelContext

	for frame = 1, config.bakedFrameCount do
		context.frame = frame
		context.t = ((frame - 1) / config.bakedFrameCount) * TAU
		context.progress = (frame - 1) / config.bakedFrameCount
		context.cycleT = if config.bakedFrameCount > 1 then (frame - 1) / (config.bakedFrameCount - 1) else 0

		local buffersByChannel = {}
		for _, channel in ipairs(self.channels) do
			buffersByChannel[channel] = buffer.create(config.totalBytes)
		end

		for y = 0, config.height - 1 do
			context.y = y
			context.v = if config.height > 1 then y / (config.height - 1) else 0

			for x = 0, config.width - 1 do
				context.x = x
				context.u = if config.width > 1 then x / (config.width - 1) else 0
				context.workspace = self.workspaceRuntime:Resolve(context)

				local sample = self:_EvaluatePixel(context)
				for _, channel in ipairs(self.channels) do
					writeSampleChannel(config, channel, buffersByChannel[channel], x, y, sample)
				end
			end
		end

		for _, channel in ipairs(self.channels) do
			table.insert(self.framesByChannel[channel], buffersByChannel[channel])
		end

		if self.yieldEveryFrame then
			task.wait()
		end
	end
end

function MaterialAnimationClass:_WriteFrame(frameIndex: number)
	for _, channel in ipairs(self.channels) do
		local editable = self.editables[channel]
		local frame = self.framesByChannel[channel][frameIndex]

		if editable ~= nil and frame ~= nil then
			editable:WritePixelsBuffer(Vector2.new(0, 0), self.config.size, frame)
		end
	end
end

function MaterialAnimationClass:Init()
	for _, channel in ipairs(self.channels) do
		if self.editables[channel] == nil then
			self.editables[channel] = AssetService:CreateEditableImage({ Size = self.config.size })
		end
	end

	if #(self.framesByChannel[self.channels[1]]) == 0 then
		self:_BakeFrames()
	end

	self:_WriteFrame(self.frameIndex)
end

function MaterialAnimationClass:Start()
	if not self:_IsInitialized() then
		self:Init()
	end

	self:Stop()

	self.connection = RunService.RenderStepped:Connect(function(dt)
		self.accumulator += dt

		if self.accumulator < self.config.frameTime then
			return
		end

		self.accumulator -= self.config.frameTime
		self.frameIndex = (self.frameIndex % self.config.bakedFrameCount) + 1
		self:_WriteFrame(self.frameIndex)
	end)
end

function MaterialAnimationClass:Stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

function MaterialAnimationClass:Destroy()
	self:Stop()

	for _, editable in pairs(self.editables) do
		editable:Destroy()
	end

	for _, channel in ipairs(self.channels) do
		table.clear(self.framesByChannel[channel])
	end

	table.clear(self.editables)
end

local MaterialAnimation = {}

function MaterialAnimation.ValidateGraph(nodes: { NodeInstance })
	Graph.Compile(nodes, {}, {})
end

function MaterialAnimation.new(definition: Definition): MaterialAnimation
	return MaterialAnimationClass.new(definition)
end

return MaterialAnimation
