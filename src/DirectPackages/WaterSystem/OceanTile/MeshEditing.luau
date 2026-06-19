--!strict

type InternalOceanTile = any

return function(deps: any)
	local function addMeshVertex(
		tile: InternalOceanTile,
		baseLocal: Vector3,
		gridX: number,
		gridZ: number,
		waveInfluence: number,
		surfaceEnabled: boolean
	): number
		local editableMesh = tile.EditableMesh
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
		local faceId = tile.EditableMesh:AddTriangle(vertices[a].id, vertices[b].id, vertices[c].id)
		local face = {
			id = faceId,
			a = a,
			b = b,
			c = c,
		}

		table.insert(tile._Faces, face)
	end

	local function markMeshInvalid(tile: InternalOceanTile, err: any)
		if tile._MeshInvalid then
			return
		end

		tile._MeshInvalid = true
		warn("[WaterSystem] EditableMesh update failed; rebuilding tile on next frame: " .. tostring(err))
	end

	local function trySetVertexPosition(tile: InternalOceanTile, vertexId: number, position: Vector3): boolean
		if tile._Destroyed or tile._MeshInvalid then
			return false
		end

		local ok, err = pcall(function()
			tile.EditableMesh:SetPosition(vertexId, position)
		end)

		if not ok then
			markMeshInvalid(tile, err)
			return false
		end

		return true
	end

	return {
		addMeshVertex = addMeshVertex,
		addMeshFace = addMeshFace,
		markMeshInvalid = markMeshInvalid,
		trySetVertexPosition = trySetVertexPosition,
	}
end
