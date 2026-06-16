--!strict

local AttributeUtils = {}

function AttributeUtils.readNumberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)

	if type(value) == "number" then
		return value
	end

	return fallback
end

function AttributeUtils.readBooleanAttribute(instance: Instance, name: string, fallback: boolean): boolean
	local value = instance:GetAttribute(name)

	if type(value) == "boolean" then
		return value
	end

	return fallback
end

function AttributeUtils.readColorAttribute(instance: Instance, name: string, fallback: Color3): Color3
	local value = instance:GetAttribute(name)

	if typeof(value) == "Color3" then
		return value
	end

	return fallback
end

function AttributeUtils.readStringAttribute(instance: Instance, name: string, fallback: string): string
	local value = instance:GetAttribute(name)

	if type(value) == "string" then
		return value
	end

	return fallback
end

function AttributeUtils.readFolderBoolean(sourceFolder: Instance?, name: string, fallback: boolean): boolean
	if sourceFolder == nil then
		return fallback
	end

	return AttributeUtils.readBooleanAttribute(sourceFolder, name, fallback)
end

function AttributeUtils.readFolderNumber(sourceFolder: Instance?, name: string, fallback: number): number
	if sourceFolder == nil then
		return fallback
	end

	return AttributeUtils.readNumberAttribute(sourceFolder, name, fallback)
end

return AttributeUtils
