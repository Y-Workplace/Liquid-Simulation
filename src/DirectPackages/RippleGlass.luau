--!strict

local RunService = game:GetService("RunService")
local Base = require(script.Parent.WaterSystem.OceanTile.Base)

export type RippleGlass = {
	MeshPart: MeshPart?,
	Pulse: (self: RippleGlass, strength: number?) -> nil,
	Start: (self: RippleGlass) -> nil,
	Destroy: (self: RippleGlass) -> nil,
}

type Wave = {
	StartTime: number,
	Strength: number,
}

local RippleGlass = {}
RippleGlass.__index = RippleGlass

local SEGMENTS = 96
local RINGS = 32
local RADIUS = 25

local SPEED = 25
local WIDTH = 2.5

function RippleGlass.new(): RippleGlass
	local self = setmetatable({}, RippleGlass)

	self.MeshPart = nil
	self._Mesh = nil
	self._Vertices = {}
	self._Waves = {} :: { Wave }
	self._Connection = nil

	return self
end

local _rippleMeshCreationFailed = false

local function BuildDiscMesh()
	-- Obtain an EditableMesh from the global pool only. Do not attempt to
	-- create new EditableMesh instances at runtime.
	local editableMesh, pooledMeshPart, err = Base.createEditableMesh(true)

	if editableMesh == nil then
		if not _rippleMeshCreationFailed then
			warn("[RippleGlass] No pooled EditableMesh available for ripples - ripples disabled")
			_rippleMeshCreationFailed = true
		end
		return nil, nil
	end

	local Vertices = {}

	local Center = editableMesh:AddVertex(Vector3.zero)

	for Ring = 1, RINGS do
		local RadiusAlpha = Ring / RINGS
		local Radius = RadiusAlpha * RADIUS

		Vertices[Ring] = {}

		for Segment = 0, SEGMENTS - 1 do
			local Angle = (Segment / SEGMENTS) * math.pi * 2

			local X = math.cos(Angle) * Radius
			local Z = math.sin(Angle) * Radius

			local VertexId = editableMesh:AddVertex(Vector3.new(X, 0, Z))

			Vertices[Ring][Segment + 1] = VertexId
		end
	end

	for Segment = 1, SEGMENTS do
		local Next = (Segment % SEGMENTS) + 1

		editableMesh:AddTriangle(Center, Vertices[1][Next], Vertices[1][Segment])
	end

	for Ring = 1, RINGS - 1 do
		for Segment = 1, SEGMENTS do
			local Next = (Segment % SEGMENTS) + 1

			local A = Vertices[Ring][Segment]
			local B = Vertices[Ring][Next]

			local C = Vertices[Ring + 1][Segment]
			local D = Vertices[Ring + 1][Next]

			editableMesh:AddTriangle(A, B, C)
			editableMesh:AddTriangle(B, D, C)
		end
	end

	editableMesh:RemoveUnused()

	return editableMesh, pooledMeshPart
end

function RippleGlass:Pulse(Strength: number?)
	table.insert(self._Waves, {
		StartTime = os.clock(),
		Strength = Strength or 1,
	})
end

function RippleGlass:Start()
	local editableMesh, pooledMeshPart = BuildDiscMesh()

	if not editableMesh then
		return
	end

	self._Mesh = editableMesh

	local meshPart

	if pooledMeshPart ~= nil then
		meshPart = pooledMeshPart
	else
		local ok, mp = pcall(function()
			local m = Instance.new("MeshPart")
			local okAssign = pcall(function()
				m.MeshContent = Content.fromObject(editableMesh)
			end)
			if okAssign then
				m.Parent = nil
				return m
			end
			return nil
		end)

		if not ok or mp == nil then
			if not _rippleMeshCreationFailed then
				warn("[RippleGlass] Failed to create MeshPart for ripple (no pooled MeshPart) - ripples disabled")
				_rippleMeshCreationFailed = true
			end
			-- release editableMesh back to pool
			pcall(function()
				if Base.releaseEditableMesh then
					Base.releaseEditableMesh(editableMesh, nil)
				end
			end)
			return
		end

		meshPart = mp
	end

	meshPart.Material = Enum.Material.Glass
	meshPart.Transparency = 5

	meshPart.Anchored = true
	meshPart.CanCollide = false
	meshPart.CanTouch = false
	meshPart.CanQuery = false

	meshPart.Parent = workspace

	local Highlight = Instance.new("Highlight")
	Highlight.Enabled = false
	Highlight.Adornee = meshPart
	Highlight.Parent = meshPart

	self.MeshPart = meshPart

	local Vertices = editableMesh:GetVertices()

	local BasePositions = {}

	for _, VertexId in Vertices do
		BasePositions[VertexId] = editableMesh:GetPosition(VertexId)
	end

	self._Connection = RunService.RenderStepped:Connect(function()
		local Camera = workspace.CurrentCamera

		if not Camera then
			return
		end

		MeshPart.CFrame = Camera.CFrame * CFrame.new(0, 0, -10) * CFrame.Angles(math.rad(90), 0, 0)

		local Now = os.clock()

		for _, VertexId in Vertices do
			local BasePosition = BasePositions[VertexId]

			local Radius = Vector2.new(BasePosition.X, BasePosition.Z).Magnitude

			local Height = 0

			for Index = #self._Waves, 1, -1 do
				local Wave = self._Waves[Index]

				local Age = Now - Wave.StartTime

				local WaveRadius = Age * SPEED

				local Distance = Radius - WaveRadius

				local Contribution = math.exp(-(Distance * Distance) / (WIDTH * WIDTH))

				Height += Contribution * Wave.Strength * 1.25

				if Age > 3 then
					table.remove(self._Waves, Index)
				end
			end

			editableMesh:SetPosition(VertexId, Vector3.new(BasePosition.X, Height, BasePosition.Z))
		end
	end)
end

function RippleGlass:Destroy()
	if self._Connection then
		self._Connection:Disconnect()
	end

	if self.MeshPart then
		-- If this MeshPart is pooled it will have been unparented on release;
		-- otherwise destroy the local instance.
		pcall(function()
			if self.MeshPart.Parent ~= nil then
				self.MeshPart:Destroy()
			end
		end)
	end

	if self._Mesh then
		pcall(function()
			if Base.releaseEditableMesh then
				Base.releaseEditableMesh(self._Mesh, nil)
			else
				pcall(function()
					self._Mesh:Destroy()
				end)
			end
		end)
	end
end

return RippleGlass
