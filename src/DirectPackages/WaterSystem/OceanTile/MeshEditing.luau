--!strict

type InternalOceanTile = any

return function(deps: any)
	local function markMeshInvalid(tile: InternalOceanTile, err: any)
		if tile._MeshInvalid then
			return
		end

		tile._MeshInvalid = true
		warn("[WaterSystem] EditableMesh update failed; rebuilding tile on next frame: " .. tostring(err))
	end

	local function addMeshVertex(
		tile: InternalOceanTile,
		baseLocal: Vector3,
		gridX: number,
		gridZ: number,
		waveInfluence: number,
		surfaceEnabled: boolean
	): number
		local editableMesh = tile.EditableMesh

		if editableMesh == nil or not tile._MeshEditingSupported then
			local vertices = tile._Vertices
			table.insert(vertices, {
				id = nil,
				baseLocal = baseLocal,
				gridX = gridX,
				gridZ = gridZ,
				waveInfluence = math.clamp(waveInfluence, 0, 1),
				surfaceEnabled = surfaceEnabled,
			})
			return #tile._Vertices
		end

		local vertices = tile._Vertices
		local vertexId = editableMesh:AddVertex(baseLocal)

		table.insert(vertices, {
			id = vertexId,
			baseLocal = baseLocal,
			gridX = gridX,
			gridZ = gridZ,
			waveInfluence = math.clamp(waveInfluence, 0, 1),
			surfaceEnabled = surfaceEnabled,
		})

		return #vertices
	end

	local function addMeshFace(tile: InternalOceanTile, a: number, b: number, c: number)
		local vertices = tile._Vertices

		if tile.EditableMesh == nil or not tile._MeshEditingSupported then
			local face = { id = nil, a = a, b = b, c = c }
			table.insert(tile._Faces, face)
			return
		end

		local faceId = tile.EditableMesh:AddTriangle(vertices[a].id, vertices[b].id, vertices[c].id)
		local face = { id = faceId, a = a, b = b, c = c }
		table.insert(tile._Faces, face)
	end

	local function trySetVertexPosition(tile: InternalOceanTile, vertexId: number, position: Vector3): boolean
		if tile._Destroyed or tile._MeshInvalid then
			return false
		end

		if tile._Destroyed or tile._MeshInvalid or not tile._MeshEditingSupported or tile.EditableMesh == nil then
			return false
		end

		tile.EditableMesh:SetPosition(vertexId, position)

		return true
	end

	return {
		addMeshVertex = addMeshVertex,
		addMeshFace = addMeshFace,
		markMeshInvalid = markMeshInvalid,
		trySetVertexPosition = trySetVertexPosition,
	}
end
