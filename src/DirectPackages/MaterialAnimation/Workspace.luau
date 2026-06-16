local AnimationProjection = require(script.Parent.Parent.AnimationProjection)
local Graph = require(script.Parent.Graph)

export type BakeDefinition = {
	Bake: boolean?,
	SharedKey: string?,
	Width: number?,
	Height: number?,
	BakedFrameCount: number?,
	Projection: AnimationProjection.ProjectionMode?,
	SphericalNormalization: boolean?,
	Workspace: any?,
	Nodes: { Graph.NodeInstance },
	Outputs: any?,
	YieldEveryFrame: boolean?,
}

export type RuntimeOptions = {
	width: number,
	height: number,
	bakedFrameCount: number,
	projectionMode: AnimationProjection.ProjectionMode,
	yieldEveryFrame: boolean?,
}

type BakedOutput = {
	width: number,
	height: number,
	frameCount: number,
	keys: { string },
	valuesByKey: { [string]: { { any } } },
}

type WorkspaceRuntime = {
	staticValues: { [string]: any },
	availableKeys: { [string]: boolean },
	bakes: { BakedOutput },
	currentValues: { [string]: any },
	options: RuntimeOptions,
}

local WorkspaceRuntimeClass = {}
WorkspaceRuntimeClass.__index = WorkspaceRuntimeClass

local Workspace = {}
local sharedBakeCache: { [string]: BakedOutput } = {}

local RESERVED_KEYS = {
	Values = true,
	Includes = true,
	Bakes = true,
	Bake = true,
	Nodes = true,
	Outputs = true,
	Workspace = true,
	SharedKey = true,
}

local TAU = math.pi * 2

local function resolveDimension(value: number?, fallback: number): number
	if value == nil then
		return fallback
	end

	return math.max(1, math.round(value))
end

local function copyValues(target: { [string]: any }, source: any?)
	if source == nil then
		return
	end

	for key, value in pairs(source) do
		if not RESERVED_KEYS[key] then
			target[key] = value
		end
	end
end

local function outputAliases(outputs: any?): { [string]: string }
	local aliases = {}

	if outputs == nil then
		return aliases
	end

	for key, value in pairs(outputs) do
		if type(key) == "number" then
			aliases[value] = value
		else
			aliases[key] = value
		end
	end

	return aliases
end

local function collectWorkspaceValues(spec: any?): { [string]: any }
	local values = {}
	if spec == nil then
		return values
	end

	if spec.Includes ~= nil then
		for _, include in ipairs(spec.Includes) do
			copyValues(values, collectWorkspaceValues(include))
		end
	end

	copyValues(values, spec)
	copyValues(values, spec.Values)

	return values
end

local function collectWorkspaceBakes(spec: any?, output: { BakeDefinition })
	if spec == nil then
		return
	end

	if spec.Includes ~= nil then
		for _, include in ipairs(spec.Includes) do
			collectWorkspaceBakes(include, output)
		end
	end

	if spec.Bakes ~= nil then
		for _, bake in pairs(spec.Bakes) do
			table.insert(output, bake)
		end
	end
end

local function buildContext(
	options: RuntimeOptions,
	workspaceValues: { [string]: any },
	config: any
): any
	return {
		x = 0,
		y = 0,
		u = 0,
		v = 0,
		width = options.width,
		height = options.height,
		frame = 1,
		frameCount = options.bakedFrameCount,
		t = 0,
		progress = 0,
		cycleT = 0,
		projectionMode = options.projectionMode,
		config = config,
		state = {},
		workspace = workspaceValues,
		nodeState = nil,
	}
end

local function bakeSubgraph(spec: BakeDefinition, parentOptions: RuntimeOptions): BakedOutput?
	if spec.Bake == false then
		return nil
	end

	if spec.SharedKey ~= nil and sharedBakeCache[spec.SharedKey] ~= nil then
		return sharedBakeCache[spec.SharedKey]
	end

	local width = resolveDimension(spec.Width, parentOptions.width)
	local height = resolveDimension(spec.Height, parentOptions.height)
	local projectionMode = AnimationProjection.Resolve({
		Projection = spec.Projection or parentOptions.projectionMode,
		SphericalNormalization = spec.SphericalNormalization,
	})
	local childRuntime = Workspace.new(spec.Workspace or {}, {
		width = width,
		height = height,
		bakedFrameCount = parentOptions.bakedFrameCount,
		projectionMode = projectionMode,
		yieldEveryFrame = parentOptions.yieldEveryFrame,
	})
	local staticValues = childRuntime:GetStaticValues()
	local nodes, dependsOnTime = Graph.Compile(spec.Nodes or {}, staticValues, childRuntime:GetAvailableKeys())
	local frameCount = resolveDimension(spec.BakedFrameCount, if dependsOnTime then parentOptions.bakedFrameCount else 1)
	local aliases = outputAliases(spec.Outputs)
	local outputKeys = {}
	local valuesByKey = {}

	for sourceKey, targetKey in pairs(aliases) do
		table.insert(outputKeys, targetKey)
		valuesByKey[targetKey] = table.create(frameCount)
		aliases[sourceKey] = targetKey
	end

	local config = {
		width = width,
		height = height,
		size = Vector2.new(width, height),
		bakedFrameCount = frameCount,
	}
	local context = buildContext({
		width = width,
		height = height,
		bakedFrameCount = frameCount,
		projectionMode = projectionMode,
		yieldEveryFrame = spec.YieldEveryFrame or parentOptions.yieldEveryFrame,
	}, staticValues, config)

	for frame = 1, frameCount do
		context.frame = frame
		context.t = ((frame - 1) / frameCount) * TAU
		context.progress = (frame - 1) / frameCount
		context.cycleT = if frameCount > 1 then (frame - 1) / (frameCount - 1) else 0

		for _, key in ipairs(outputKeys) do
			valuesByKey[key][frame] = table.create(width * height)
		end

		for y = 0, height - 1 do
			context.y = y
			context.v = if height > 1 then y / (height - 1) else 0

			for x = 0, width - 1 do
				context.x = x
				context.u = if width > 1 then x / (width - 1) else 0
				context.workspace = childRuntime:Resolve(context)

				local sample = Graph.Evaluate(nodes, context, context.workspace)
				local index = y * width + x + 1

				for sourceKey, targetKey in pairs(aliases) do
					valuesByKey[targetKey][frame][index] = sample[sourceKey]
				end
			end
		end

		if spec.YieldEveryFrame or parentOptions.yieldEveryFrame then
			task.wait()
		end
	end

	local baked = {
		width = width,
		height = height,
		frameCount = frameCount,
		keys = outputKeys,
		valuesByKey = valuesByKey,
	}

	if spec.SharedKey ~= nil then
		sharedBakeCache[spec.SharedKey] = baked
	end

	return baked
end

function WorkspaceRuntimeClass:GetStaticValues(): { [string]: any }
	return self.staticValues
end

function WorkspaceRuntimeClass:GetAvailableKeys(): { [string]: boolean }
	return self.availableKeys
end

function WorkspaceRuntimeClass:Resolve(context: any): { [string]: any }
	local values = self.currentValues

	for _, baked in ipairs(self.bakes) do
		local x = if baked.width > 1 then math.clamp(math.round(context.u * (baked.width - 1)), 0, baked.width - 1) else 0
		local y = if baked.height > 1 then math.clamp(math.round(context.v * (baked.height - 1)), 0, baked.height - 1) else 0
		local frame = if baked.frameCount > 1 then ((context.frame - 1) % baked.frameCount) + 1 else 1
		local index = y * baked.width + x + 1

		for _, key in ipairs(baked.keys) do
			values[key] = baked.valuesByKey[key][frame][index]
		end
	end

	return values
end

function Workspace.new(spec: any?, options: RuntimeOptions): WorkspaceRuntime
	local staticValues = collectWorkspaceValues(spec)
	local runtime = setmetatable({
		staticValues = staticValues,
		availableKeys = {},
		bakes = {},
		currentValues = {},
		options = options,
	}, WorkspaceRuntimeClass) :: any

	for key, value in pairs(staticValues) do
		runtime.availableKeys[key] = true
		runtime.currentValues[key] = value
	end

	local bakeDefinitions = {}
	collectWorkspaceBakes(spec, bakeDefinitions)
	for _, bake in ipairs(bakeDefinitions) do
		local baked = bakeSubgraph(bake, options)
		if baked ~= nil then
			table.insert(runtime.bakes, baked)
			for _, key in ipairs(baked.keys) do
				runtime.availableKeys[key] = true
			end
		end
	end

	return runtime
end

function Workspace.ClearSharedBakes()
	table.clear(sharedBakeCache)
end

return Workspace
