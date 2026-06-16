export type NodeFamily = "Source" | "Filter" | "Combiner" | "Material" | "Output"

export type NodeDefinition = {
	Name: string,
	Family: NodeFamily,
	Inputs: { string },
	Outputs: { string },
	DependsOnTime: boolean?,
	Prepare: ((parameters: any, workspace: any) -> any)?,
	Execute: (inputs: { [string]: any }, parameters: any, context: any) -> { [string]: any }?,
}

local NodeRegistry = {}
local definitions: { [string]: NodeDefinition } = {}

function NodeRegistry.Register(definition: NodeDefinition)
	assert(type(definition.Name) == "string" and definition.Name ~= "", "Node definition requires a Name")
	assert(type(definition.Execute) == "function", `Node {definition.Name} requires an Execute function`)

	definitions[definition.Name] = definition
end

function NodeRegistry.Get(name: string): NodeDefinition
	local definition = definitions[name]
	assert(definition ~= nil, `Unknown material animation node: {name}`)

	return definition
end

function NodeRegistry.All(): { [string]: NodeDefinition }
	return definitions
end

NodeRegistry.Register(require(script.Parent.Nodes.FBMNoise))
NodeRegistry.Register(require(script.Parent.Nodes.ForceFieldIntensity))
NodeRegistry.Register(require(script.Parent.Nodes.ForceFieldMaterial))
NodeRegistry.Register(require(script.Parent.Nodes.NoiseToPalette))
NodeRegistry.Register(require(script.Parent.Nodes.ShineBand))
NodeRegistry.Register(require(script.Parent.Nodes.ShineMaterial))
NodeRegistry.Register(require(script.Parent.Nodes.TriangularNotesLayers))
NodeRegistry.Register(require(script.Parent.Nodes.TriangularStripeForceField))

return NodeRegistry
