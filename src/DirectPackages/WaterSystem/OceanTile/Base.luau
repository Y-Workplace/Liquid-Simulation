--!strict

local AssetService = game:GetService("AssetService")

local WaterDepthMap = require(script.Parent.Parent.WaterDepthMap)
local WaterObstacleMap = require(script.Parent.Parent.WaterObstacleMap)
local WaterBuffer = require(script.Parent.Parent.WaterBuffer)
local Constants = require(script.Parent.Constants)

type TileConfig = any

local WAVE_LOOP_POSITION_BYTES = Constants.WAVE_LOOP_POSITION_BYTES
local WAVE_LOOP_HEIGHT_BYTES = Constants.WAVE_LOOP_HEIGHT_BYTES
local OBSTACLE_IMPACT_VERTEX_BYTES = Constants.OBSTACLE_IMPACT_VERTEX_BYTES
local VERTEX_BAKE_STATIC_BYTES = Constants.VERTEX_BAKE_STATIC_BYTES

-- Pool configuration
local EDITABLE_MESH_POOL_TARGET = 20
local editableMeshPool: { any } = {}
local editableMeshPoolLookup: { [EditableMesh]: number } = {}
local editableImagePool: { any } = {}
local editableImagePoolLookup: { [EditableImage]: number } = {}
local editableImagePoolExhausted = false

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / math.max(edge1 - edge0, 1e-6), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(lerpNumber(a.R, b.R, t), lerpNumber(a.G, b.G, t), lerpNumber(a.B, b.B, t))
end

local function hashNoise(x: number, z: number, seed: number): number
	local value = math.sin((x + seed * 13.17) * 12.9898 + (z - seed * 7.31) * 78.233) * 43758.5453123

	return value - math.floor(value)
end

local function cframeWithUp(position: Vector3, upVector: Vector3): CFrame
	local up = if upVector.Magnitude > 0.001 then upVector.Unit else Vector3.yAxis
	local right = Vector3.yAxis:Cross(up)

	if right.Magnitude <= 0.001 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	local back = right:Cross(up).Unit

	return CFrame.fromMatrix(position, right, up, back)
end

local function normalizeAssetId(assetId: string?): string?
	if assetId == nil or assetId == "" then
		return nil
	end

	if string.find(assetId, "rbxassetid://") == 1 then
		return assetId
	end

	if string.match(assetId, "^%d+$") then
		return "rbxassetid://" .. assetId
	end

	return assetId
end

local function readNumberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)

	if type(value) == "number" then
		return value
	end

	return fallback
end

local function readBooleanAttribute(instance: Instance, name: string, fallback: boolean): boolean
	local value = instance:GetAttribute(name)

	if type(value) == "boolean" then
		return value
	end

	return fallback
end

local getBaseCFrame: (BasePart) -> CFrame

local function createUniformCoordinateBuffer(size: number, resolution: number): buffer
	local coordinates = buffer.create((resolution + 1) * 4)

	for index = 0, resolution do
		buffer.writef32(coordinates, index * 4, (index / resolution - 0.5) * size)
	end

	return coordinates
end

local function createWorldGridCoordinateBuffer(
	baseCFrame: CFrame,
	localAxis: Vector3,
	size: number,
	spacing: number,
	maxResolution: number
): (buffer, number)
	local maxVertexCount = maxResolution + 1
	local coordinates = buffer.create(maxVertexCount * 4)
	local halfSize = size * 0.5
	local axis = baseCFrame:VectorToWorldSpace(localAxis).Unit
	local originAxis = baseCFrame.Position:Dot(axis)
	local startAxis = originAxis - halfSize
	local endAxis = originAxis + halfSize
	local firstGrid = math.ceil((startAxis + 1e-4) / spacing)
	local lastGrid = math.floor((endAxis - 1e-4) / spacing)
	local gridCount = math.max(lastGrid - firstGrid + 1, 0)
	local gridStep = math.max(1, math.ceil((gridCount + 2) / maxVertexCount))
	local count = 1

	buffer.writef32(coordinates, 0, -halfSize)

	for grid = firstGrid, lastGrid, gridStep do
		if count >= maxResolution then
			break
		end

		local localCoordinate = grid * spacing - originAxis

		if localCoordinate > -halfSize + 1e-4 and localCoordinate < halfSize - 1e-4 then
			buffer.writef32(coordinates, count * 4, localCoordinate)
			count += 1
		end
	end

	if count < 2 then
		buffer.writef32(coordinates, count * 4, 0)
		count += 1
	end

	buffer.writef32(coordinates, count * 4, halfSize)

	return coordinates, count
end

local function getGridCoordinates(sourcePart: BasePart, config: TileConfig): (number, number, buffer, buffer)
	local explicitResolution = sourcePart:GetAttribute("OceanResolution")

	if type(explicitResolution) == "number" then
		local resolution = math.clamp(math.round(explicitResolution), 2, config.Resolution)

		return resolution,
			resolution,
			createUniformCoordinateBuffer(sourcePart.Size.X, resolution),
			createUniformCoordinateBuffer(sourcePart.Size.Z, resolution)
	end

	local spacing = math.max(readNumberAttribute(sourcePart, "OceanVertexSpacing", config.VertexSpacing), 0.5)
	local maxResolution = math.clamp(math.round(config.Resolution), 2, 160)
	local baseCFrame = getBaseCFrame(sourcePart)
	local xCoordinates, resolutionX = createWorldGridCoordinateBuffer(
		baseCFrame,
		Vector3.xAxis,
		math.max(sourcePart.Size.X, 0.001),
		spacing,
		maxResolution
	)
	local zCoordinates, resolutionZ = createWorldGridCoordinateBuffer(
		baseCFrame,
		Vector3.zAxis,
		math.max(sourcePart.Size.Z, 0.001),
		spacing,
		maxResolution
	)

	return resolutionX, resolutionZ, xCoordinates, zCoordinates
end

local function getSurfaceOffset(sourcePart: BasePart): number
	return readNumberAttribute(sourcePart, "OceanSurfaceOffset", sourcePart.Size.Y * 0.5)
end

local function createWaterBuffer(sourcePart: BasePart, config: TileConfig): WaterBuffer.WaterBuffer?
	if not config.InteractiveWavesEnabled then
		return nil
	end

	return WaterBuffer.new({
		Resolution = config.InteractiveResolution,
		SizeX = math.max(sourcePart.Size.X, 1),
		SizeZ = math.max(sourcePart.Size.Z, 1),
		Damping = config.InteractiveDamping,
		MaxHeight = config.InteractiveMaxHeight,
		MaxVelocity = config.InteractiveMaxVelocity,
		MoveSphereScale = config.InteractiveMoveSphereScale,
	})
end

local function createDepthMap(
	sourcePart: BasePart,
	generatedParent: Instance,
	config: TileConfig
): WaterDepthMap.WaterDepthMap?
	if not config.DepthMapEnabled then
		return nil
	end

	local sourceParent = sourcePart.Parent

	return WaterDepthMap.new({
		CFrame = getBaseCFrame(sourcePart),
		SizeX = math.max(sourcePart.Size.X, 1),
		SizeZ = math.max(sourcePart.Size.Z, 1),
		Resolution = config.DepthMapResolution,
		MaxDepth = config.MaxRaycastDepth,
		FallbackDepth = config.FallbackDepth,
		SourcePart = sourcePart,
		IgnoreInstances = if sourceParent ~= nil then { sourceParent, generatedParent } else { generatedParent },
	})
end

local function createObstacleMap(
	sourcePart: BasePart,
	generatedParent: Instance,
	config: TileConfig
): WaterObstacleMap.WaterObstacleMap?
	if not config.ObstacleMapEnabled then
		return nil
	end

	local obstacleRoot = workspace:FindFirstChild(config.ObstacleRootName)
	local sourceParent = sourcePart.Parent

	return WaterObstacleMap.new({
		CFrame = getBaseCFrame(sourcePart),
		SizeX = math.max(sourcePart.Size.X, 1),
		SizeZ = math.max(sourcePart.Size.Z, 1),
		Resolution = config.ObstacleMapResolution,
		ObstacleRoot = obstacleRoot,
		RayHeight = config.ObstacleRayHeight,
		RayDepth = config.ObstacleRayDepth,
		InfluenceRadius = config.ObstacleInfluenceRadius,
		ExcludeInstances = if sourceParent ~= nil
			then { sourceParent, generatedParent }
			else { sourcePart, generatedParent },
		BakeAnchoredObstacles = config.BakeAnchoredObstacles,
	})
end

local function createRawEditableMesh(): (EditableMesh?, string?)
	local ok, editableMesh = pcall(function()
		return AssetService:CreateEditableMesh({ FixedSize = false })
	end)

	if not ok then
		return nil, tostring(editableMesh)
	end

	if editableMesh == nil then
		return nil, "AssetService:CreateEditableMesh returned nil"
	end

	return editableMesh, nil
end

-- Best-effort clear of editable mesh state before reuse/destroy.
-- Some EditableMesh implementations may expose clearing APIs; call them if present.
local function clearEditableMeshForReuse(editableMesh: any, tileState: any?)
	if editableMesh == nil then
		return
	end

	pcall(function()
		if type(editableMesh.Clear) == "function" then
			editableMesh:Clear()
		end

		if type(editableMesh.ClearColors) == "function" then
			editableMesh:ClearColors()
		end

		if type(editableMesh.ClearUVs) == "function" then
			editableMesh:ClearUVs()
		end
	end)
end

local function tryCreateMeshPartFromEditable(editableMesh: EditableMesh)
	local ok, partOrErr = pcall(function()
		local mp
		-- try fast-path: assign MeshContent directly
		local okAssign, assignErr = pcall(function()
			mp = AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))
		end)

		if okAssign then
			mp.Parent = nil
			return mp
		end

		-- direct assignment failed; do not call AssetService here (avoid runtime budget calls)
		return nil, tostring(assignErr)
	end)

	if not ok then
		return nil, tostring(partOrErr)
	end

	if partOrErr == nil then
		return nil, "failed to create MeshPart from editable mesh"
	end

	return partOrErr
end

local function warmEditableMeshPool()
	-- Interleaved warm-up for EditableMesh and EditableImage to avoid
	-- exhausting a shared AssetService budget by creating many of one
	-- resource type before the other. Stop the loop on first failure.
	warn("[WaterSystem] EditableMesh pool warm-up starting, target=" .. tostring(EDITABLE_MESH_POOL_TARGET))
	for i = 1, EDITABLE_MESH_POOL_TARGET do
		local editableMesh, meshErr = createRawEditableMesh()

		if editableMesh == nil then
			warn(`[WaterSystem] EditableMesh pool warm: failed to create mesh {i}: {tostring(meshErr)}`)
			warn(debug.traceback())
			break
		end

		local meshPart = nil
		local mp, mpErr = tryCreateMeshPartFromEditable(editableMesh)

		if mp ~= nil then
			meshPart = mp
			meshPart.Parent = nil
		else
			-- fast-path assignment failed (likely plugin capability). Try AssetService creation once
			local okCreate, created = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))
			end)
			if okCreate and created ~= nil then
				meshPart = created
				meshPart.Parent = nil
			else
				meshPart = nil
			end
		end

		table.insert(editableMeshPool, {
			EditableMesh = editableMesh,
			MeshPart = meshPart,
			InUse = false,
		})
		editableMeshPoolLookup[editableMesh] = #editableMeshPool
		warn(
			`[WaterSystem] EditableMesh pool slot {#editableMeshPool} created (mesh={tostring(editableMesh)}, meshPart={tostring(
				meshPart
			)})`
		)

		-- Now attempt to create one EditableImage paired with this mesh
		local okImg, editableImage = pcall(function()
			return AssetService:CreateEditableImage()
		end)

		if not okImg or editableImage == nil then
			warn(
				`[WaterSystem] EditableImage pool warm: failed to create image for slot {i}: {tostring(editableImage)}`
			)
			warn(debug.traceback())
			break
		end

		table.insert(editableImagePool, {
			EditableImage = editableImage,
			InUse = false,
		})
		editableImagePoolLookup[editableImage] = #editableImagePool
	end
end

local function createEditableMesh(onlyFromPool: boolean?): (EditableMesh?, MeshPart?, string?)
	for slotIndex, entry in ipairs(editableMeshPool) do
		if not entry.InUse and entry.EditableMesh ~= nil then
			entry.InUse = true
			editableMeshPoolLookup[entry.EditableMesh] = slotIndex
			warn(
				`[WaterSystem] createEditableMesh: returning pooled slot {slotIndex} (mesh={tostring(entry.EditableMesh)})`
			)
			return entry.EditableMesh, entry.MeshPart, nil
		end
	end

	if onlyFromPool then
		warn(
			`[WaterSystem] createEditableMesh: pool exhausted ({#editableMeshPool}/{EDITABLE_MESH_POOL_TARGET}) — onlyFromPool requested`
		)
		warn(debug.traceback())
		return nil, nil, `[WaterSystem] EditableMesh pool exhausted ({#editableMeshPool}/{EDITABLE_MESH_POOL_TARGET})`
	end

	-- Pool exhausted: attempt non-pooled creation
	local fallback, fallbackErr = createRawEditableMesh()

	if fallback == nil then
		warn(
			"[WaterSystem] createEditableMesh: non-pooled fallback CreateEditableMesh failed: " .. tostring(fallbackErr)
		)
		return nil,
			nil,
			`[WaterSystem] EditableMesh pool exhausted ({#editableMeshPool}/{EDITABLE_MESH_POOL_TARGET}): {tostring(
				fallbackErr
			)}`
	end

	local fallbackMeshPart, fallbackMeshPartErr = tryCreateMeshPartFromEditable(fallback)

	if fallbackMeshPart == nil then
		-- leave nil, caller will handle lack of meshpart
	end

	return fallback, fallbackMeshPart, nil
end

local function releaseEditableMesh(editableMesh: EditableMesh, tileState: any?): boolean
	local slotIndex = editableMeshPoolLookup[editableMesh]

	if slotIndex == nil then
		-- non-pooled: try to clear and destroy
		pcall(function()
			clearEditableMeshForReuse(editableMesh, tileState)
		end)
		pcall(function()
			editableMesh:Destroy()
		end)
		return true
	end

	local entry = editableMeshPool[slotIndex]
	if entry == nil then
		editableMeshPoolLookup[editableMesh] = nil
		return false
	end

	entry.InUse = false
	-- keep entry.EditableMesh and entry.MeshPart for reuse
	return true
end

local function createEditableImage(onlyFromPool: boolean?): (EditableImage?, string?)
	-- Return pooled EditableImage only if requested; never create at runtime
	for slotIndex, entry in ipairs(editableImagePool) do
		if not entry.InUse and entry.EditableImage ~= nil then
			entry.InUse = true
			editableImagePoolLookup[entry.EditableImage] = slotIndex
			-- Reset exhaustion flag when we successfully allocate from pool
			editableImagePoolExhausted = false
			return entry.EditableImage, nil
		end
	end

	if onlyFromPool then
		editableImagePoolExhausted = true
		return nil, `[WaterSystem] EditableImage pool exhausted ({#editableImagePool})`
	end

	-- Non-pooled creation allowed only when caller explicitly permits it
	local ok, imgOrErr = pcall(function()
		return AssetService:CreateEditableImage()
	end)

	if not ok or imgOrErr == nil then
		return nil, tostring(imgOrErr)
	end

	return imgOrErr, nil
end

local function releaseEditableImage(editableImage: EditableImage): boolean
	local slotIndex = editableImagePoolLookup[editableImage]

	if slotIndex == nil then
		pcall(function()
			editableImage:Destroy()
		end)
		return true
	end

	local entry = editableImagePool[slotIndex]
	if entry == nil then
		editableImagePoolLookup[editableImage] = nil
		return false
	end

	entry.InUse = false
	-- pool now has a free slot; clear exhausted flag so future callers may attempt to allocate
	editableImagePoolExhausted = false
	return true
end

local function createMeshPart(editableMesh: EditableMesh?): (MeshPart?, string?)
	-- If no editable mesh provided, fall back to a plain MeshPart instance.
	if editableMesh == nil then
		local ok, partOrErr = pcall(function()
			return Instance.new("MeshPart")
		end)

		if not ok then
			return nil, tostring(partOrErr)
		end

		return partOrErr, nil
	end

	local meshPart, err = tryCreateMeshPartFromEditable(editableMesh)

	if meshPart == nil then
		-- If we couldn't assign MeshContent, fall back to a plain MeshPart instance
		local ok, partOrErr = pcall(function()
			return Instance.new("MeshPart")
		end)

		if not ok then
			return nil, tostring(partOrErr)
		end

		return partOrErr, nil
	end

	return meshPart, nil
end

function getBaseCFrame(sourcePart: BasePart): CFrame
	return sourcePart.CFrame * CFrame.new(0, getSurfaceOffset(sourcePart), 0)
end

local function gridIndex(resolutionX: number, x: number, z: number): number
	return z * (resolutionX + 1) + x + 1
end

local function getAxisCell(coordinates: buffer, resolution: number, value: number): (number, number, number)
	local first = buffer.readf32(coordinates, 0)
	local last = buffer.readf32(coordinates, resolution * 4)

	if value <= first then
		return 0, 0, 0
	end

	if value >= last then
		return resolution, resolution, 0
	end

	local low = 0
	local high = resolution

	while high - low > 1 do
		local mid = math.floor((low + high) * 0.5)
		local midValue = buffer.readf32(coordinates, mid * 4)

		if value >= midValue then
			low = mid
		else
			high = mid
		end
	end

	local lowValue = buffer.readf32(coordinates, low * 4)
	local highValue = buffer.readf32(coordinates, high * 4)
	local alpha = math.clamp((value - lowValue) / math.max(highValue - lowValue, 1e-6), 0, 1)

	return low, high, alpha
end

local function distanceToSourcePart(sourcePart: BasePart, worldPosition: Vector3): number
	local localPosition = sourcePart.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = sourcePart.Size * 0.5
	local closestLocal = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	local closestWorld = sourcePart.CFrame:PointToWorldSpace(closestLocal)

	return (worldPosition - closestWorld).Magnitude
end

local function isWorldPositionNearCamera(worldPosition: Vector3, maxDistance: number): boolean
	local camera = workspace.CurrentCamera

	if camera == nil then
		return true
	end

	return (Vector3.new(worldPosition.X, 0, worldPosition.Z) - Vector3.new(
		camera.CFrame.Position.X,
		0,
		camera.CFrame.Position.Z
	)).Magnitude <= maxDistance
end

local function wavePositionOffset(
	frameIndex: number,
	vertexIndex: number,
	vertexCount: number,
	component: number
): number
	return (frameIndex * vertexCount + (vertexIndex - 1)) * WAVE_LOOP_POSITION_BYTES + component * 4
end

local function waveHeightOffset(frameIndex: number, vertexIndex: number, vertexCount: number): number
	return (frameIndex * vertexCount + (vertexIndex - 1)) * WAVE_LOOP_HEIGHT_BYTES
end

local function obstacleImpactVertexOffset(index: number): number
	return (index - 1) * OBSTACLE_IMPACT_VERTEX_BYTES
end

local function vertexBakeStaticOffset(vertexIndex: number, component: number): number
	return (vertexIndex - 1) * VERTEX_BAKE_STATIC_BYTES + component * 4
end

-- Warm the pool once at module load. Best-effort; stop on first failure.
pcall(function()
	warmEditableMeshPool()
end)

return {
	smoothstep = smoothstep,
	lerpNumber = lerpNumber,
	lerpColor = lerpColor,
	hashNoise = hashNoise,
	cframeWithUp = cframeWithUp,
	normalizeAssetId = normalizeAssetId,
	readNumberAttribute = readNumberAttribute,
	readBooleanAttribute = readBooleanAttribute,
	getBaseCFrame = getBaseCFrame,
	getGridCoordinates = getGridCoordinates,
	getSurfaceOffset = getSurfaceOffset,
	createWaterBuffer = createWaterBuffer,
	createDepthMap = createDepthMap,
	createObstacleMap = createObstacleMap,
	createEditableMesh = createEditableMesh,
	getEditableMeshPoolAvailableCount = function()
		local n = 0
		for _, entry in ipairs(editableMeshPool) do
			if not entry.InUse and entry.EditableMesh ~= nil then
				n += 1
			end
		end
		return n
	end,
	createEditableImage = createEditableImage,
	isEditableImagePoolExhausted = function()
		return editableImagePoolExhausted
	end,
	releaseEditableMesh = releaseEditableMesh,
	releaseEditableImage = releaseEditableImage,
	createMeshPart = createMeshPart,
	gridIndex = gridIndex,
	getAxisCell = getAxisCell,
	distanceToSourcePart = distanceToSourcePart,
	isWorldPositionNearCamera = isWorldPositionNearCamera,
	wavePositionOffset = wavePositionOffset,
	waveHeightOffset = waveHeightOffset,
	obstacleImpactVertexOffset = obstacleImpactVertexOffset,
	vertexBakeStaticOffset = vertexBakeStaticOffset,
}
