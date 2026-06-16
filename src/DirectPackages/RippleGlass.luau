--!strict

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

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
	self._Waves = {} :: {Wave}
	self._Connection = nil

	return self
end

local function BuildDiscMesh()
	local EditableMesh = AssetService:CreateEditableMesh()

	local Vertices = {}

	local Center = EditableMesh:AddVertex(Vector3.zero)

	for Ring = 1, RINGS do
		local RadiusAlpha = Ring / RINGS
		local Radius = RadiusAlpha * RADIUS

		Vertices[Ring] = {}

		for Segment = 0, SEGMENTS - 1 do
			local Angle = (Segment / SEGMENTS) * math.pi * 2

			local X = math.cos(Angle) * Radius
			local Z = math.sin(Angle) * Radius

			local VertexId =
				EditableMesh:AddVertex(
					Vector3.new(X, 0, Z)
				)

			Vertices[Ring][Segment + 1] = VertexId
		end
	end

	for Segment = 1, SEGMENTS do
		local Next =
			(Segment % SEGMENTS) + 1

		EditableMesh:AddTriangle(
			Center,
			Vertices[1][Next],
			Vertices[1][Segment]
		)
	end

	for Ring = 1, RINGS - 1 do
		for Segment = 1, SEGMENTS do
			local Next =
				(Segment % SEGMENTS) + 1

			local A = Vertices[Ring][Segment]
			local B = Vertices[Ring][Next]

			local C = Vertices[Ring + 1][Segment]
			local D = Vertices[Ring + 1][Next]

			EditableMesh:AddTriangle(A, B, C)
			EditableMesh:AddTriangle(B, D, C)
		end
	end

	EditableMesh:RemoveUnused()

	return EditableMesh
end

function RippleGlass:Pulse(Strength: number?)
	table.insert(
		self._Waves,
		{
			StartTime = os.clock(),
			Strength = Strength or 1,
		}
	)
end

function RippleGlass:Start()
	local EditableMesh = BuildDiscMesh()

	self._Mesh = EditableMesh

	local MeshPart =
		AssetService:CreateMeshPartAsync(
			Content.fromObject(EditableMesh)
		)

	MeshPart.Material = Enum.Material.Glass
	MeshPart.Transparency = 5

	MeshPart.Anchored = true
	MeshPart.CanCollide = false
	MeshPart.CanTouch = false
	MeshPart.CanQuery = false

	MeshPart.Parent = workspace

	local Highlight = Instance.new("Highlight")
	Highlight.Enabled = false
	Highlight.Adornee = MeshPart
	Highlight.Parent = MeshPart

	self.MeshPart = MeshPart

	local Vertices = EditableMesh:GetVertices()

	local BasePositions = {}

	for _, VertexId in Vertices do
		BasePositions[VertexId] =
			EditableMesh:GetPosition(VertexId)
	end

	self._Connection =
		RunService.RenderStepped:Connect(function()
			local Camera =
				workspace.CurrentCamera

			if not Camera then
				return
			end

			MeshPart.CFrame =
				Camera.CFrame
				* CFrame.new(0, 0, -10) * CFrame.Angles(math.rad(90), 0, 0)

			local Now = os.clock()

			for _, VertexId in Vertices do
				local BasePosition =
					BasePositions[VertexId]

				local Radius =
					Vector2.new(
						BasePosition.X,
						BasePosition.Z
					).Magnitude

				local Height = 0

				for Index = #self._Waves, 1, -1 do
					local Wave =
						self._Waves[Index]

					local Age =
						Now - Wave.StartTime

					local WaveRadius =
						Age * SPEED

					local Distance =
						Radius - WaveRadius

					local Contribution =
						math.exp(
							-(Distance * Distance)
								/ (WIDTH * WIDTH)
						)

					Height +=
						Contribution
						* Wave.Strength
						* 1.25

					if Age > 3 then
						table.remove(
							self._Waves,
							Index
						)
					end
				end

				EditableMesh:SetPosition(
					VertexId,
					Vector3.new(
						BasePosition.X,
						Height,
						BasePosition.Z
					)
				)
			end
		end)
end

function RippleGlass:Destroy()
	if self._Connection then
		self._Connection:Disconnect()
	end

	if self.MeshPart then
		self.MeshPart:Destroy()
	end
end

return RippleGlass
