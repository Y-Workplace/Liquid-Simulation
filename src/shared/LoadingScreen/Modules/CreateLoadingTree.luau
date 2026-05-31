local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local function Scan(root: Instance, output: { any }, _tree: string?)
	local childrenNames = {}
	for _, child in ipairs(root:GetChildren()) do
		table.insert(childrenNames, child.Name)
	end

	local tree = _tree and _tree == "" and tostring(root) or _tree and _tree .. "|" .. tostring(root) or ""

	if #childrenNames > 0 then
		table.insert(output, {
			root = tree,
			path = childrenNames,
		})
	end

	for _, child in ipairs(root:GetChildren()) do
		Scan(child, output, tree)
	end
end

local function BuildStarterGuiTree(Service)
	local tree = {}
	Scan(Service, tree)
	return tree
end

local function TableToText(tbl)
	local lines = {}

	for _, item in ipairs(tbl) do
		local rootName = '"' .. item.root .. '"'
		local pathParts = {}
		for _, n in ipairs(item.path) do
			table.insert(pathParts, '"' .. n .. '"')
		end
		local pathStr = "{ " .. table.concat(pathParts, ", ") .. " }"

		table.insert(lines, "{ root = " .. rootName .. ", path = " .. pathStr .. " }")
	end

	return "{\n\t\t" .. table.concat(lines, ",\n\t\t") .. "\n\t}"
end

local function TableToTextService(root)
	local lines = {}

	for name, tbl in pairs(root) do
		local insert = TableToText(tbl)

		table.insert(lines, name .. " = " .. insert)
	end

	return "{\n\t" .. table.concat(lines, ",\n\t") .. "\n}"
end

local CreateLoadingTree = {}
local metatable = {
	__call = function()
		local Root = {}

		Root.StarterGui = BuildStarterGuiTree(StarterGui)
		Root.ReplicatedStorage = BuildStarterGuiTree(ReplicatedStorage)
		Root.Workspace = BuildStarterGuiTree(workspace)

		print("\n\n\nreturn " .. TableToTextService(Root) .. "\n\n\n")
	end,
}

setmetatable(CreateLoadingTree, metatable)

return CreateLoadingTree

-- require(game.ReplicatedStorage.Shared.LoadingScreen.Modules.CreateLoadingTree)()
