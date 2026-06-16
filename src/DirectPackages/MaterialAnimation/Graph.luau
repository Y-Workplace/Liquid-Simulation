local NodeRegistry = require(script.Parent.NodeRegistry)

export type NodeInstance = {
	Id: string?,
	Type: string,
	Parameters: any?,
	Inputs: { [string]: string }?,
	Outputs: { [string]: string }?,
}

export type CompiledNode = {
	definition: NodeRegistry.NodeDefinition,
	id: string?,
	parameters: any,
	state: any,
	inputKeys: { [string]: string },
	outputKeys: { [string]: string },
	dependsOnTime: boolean,
}

local Graph = {}

local function compileNode(instance: NodeInstance, workspace: any): CompiledNode
	local definition = NodeRegistry.Get(instance.Type)
	local inputKeys = {}
	local outputKeys = {}
	local parameters = instance.Parameters or {}

	for _, inputName in ipairs(definition.Inputs or {}) do
		inputKeys[inputName] = if instance.Inputs and instance.Inputs[inputName] then instance.Inputs[inputName] else inputName
	end

	for _, outputName in ipairs(definition.Outputs or {}) do
		outputKeys[outputName] = if instance.Outputs and instance.Outputs[outputName] then instance.Outputs[outputName] else outputName
	end

	return {
		definition = definition,
		id = instance.Id,
		parameters = parameters,
		state = if definition.Prepare then definition.Prepare(parameters, workspace) else nil,
		inputKeys = inputKeys,
		outputKeys = outputKeys,
		dependsOnTime = definition.DependsOnTime == true,
	}
end

local function cloneAvailable(initialAvailable: { [string]: boolean }?): { [string]: boolean }
	local available = {}

	if initialAvailable ~= nil then
		for key, value in pairs(initialAvailable) do
			if value then
				available[key] = true
			end
		end
	end

	return available
end

local function canRunNode(node: CompiledNode, available: { [string]: boolean }): boolean
	for _, inputKey in pairs(node.inputKeys) do
		if not available[inputKey] then
			return false
		end
	end

	return true
end

local function markOutputs(node: CompiledNode, available: { [string]: boolean }, owners: { [string]: string })
	for outputName, outputKey in pairs(node.outputKeys) do
		assert(owners[outputKey] == nil, `Graph output "{outputKey}" is produced by more than one node`)
		available[outputKey] = true
		owners[outputKey] = node.id or node.definition.Name .. "." .. outputName
	end
end

function Graph.Compile(
	instances: { NodeInstance },
	workspace: any,
	initialAvailable: { [string]: boolean }?
): ({ CompiledNode }, boolean)
	local pending = table.create(#instances)
	for _, instance in ipairs(instances) do
		table.insert(pending, compileNode(instance, workspace))
	end

	local ordered = table.create(#pending)
	local available = cloneAvailable(initialAvailable)
	local owners = {}
	local graphDependsOnTime = false

	while #pending > 0 do
		local progressed = false
		local index = 1

		while index <= #pending do
			local node = pending[index]
			if canRunNode(node, available) then
				graphDependsOnTime = graphDependsOnTime or node.dependsOnTime
				table.insert(ordered, node)
				markOutputs(node, available, owners)
				table.remove(pending, index)
				progressed = true
			else
				index += 1
			end
		end

		if not progressed then
			local blocked = pending[1]
			local missing = {}
			for inputName, inputKey in pairs(blocked.inputKeys) do
				if not available[inputKey] then
					table.insert(missing, inputName .. "=" .. inputKey)
				end
			end

			error(`Cannot compile material graph. Node "{blocked.id or blocked.definition.Name}" is missing inputs: {table.concat(missing, ", ")}`)
		end
	end

	return ordered, graphDependsOnTime
end

function Graph.Evaluate(nodes: { CompiledNode }, context: any, seed: { [string]: any }?): { [string]: any }
	local sample = {}

	if seed ~= nil then
		for key, value in pairs(seed) do
			sample[key] = value
		end
	end

	for _, node in ipairs(nodes) do
		local inputs = {}
		for inputName, inputKey in pairs(node.inputKeys) do
			inputs[inputName] = sample[inputKey]
		end

		context.nodeState = node.state
		local output = node.definition.Execute(inputs, node.parameters, context)
		if output ~= nil then
			for outputName, value in pairs(output) do
				local outputKey = node.outputKeys[outputName]
				if outputKey ~= nil then
					sample[outputKey] = value
				end
			end
		end
	end

	return sample
end

return Graph
