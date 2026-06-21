--[[
    WebGL Water — ported to Roblox EditableMesh
    Based on https://madebyevan.com/webgl-water/ (Evan Wallace, MIT License)

    Setup:
      1. Place this LocalScript under StarterPlayerScripts.
      2. Create a MeshPart in Workspace named "OceanMesh" and a
         "ReflectionOceanMesh" MeshPart for reflections.
         • Anchored: true | CanCollide: false | CastShadow: false
      3. The simulation runs per-client using EditableMesh.
]]

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

-- Configuration
local CFG = {
	GRID = 64, -- vertices per side
	WORLD_SIZE = 200, -- world size in studs

	UPDATE_RATE = 1 / 40, -- seconds per fixed simulation step

	DROP_RADIUS = 0.05, -- drop radius in UV [0,1]
	DROP_STR = 0.06, -- drop strength

	SPHERE_RADIUS = 0.18, -- player sphere radius in normalized [-1,1]
	SPHERE_SCALE = 1.2,

	INIT_DROPS = 16,
}

CFG.CELL_SIZE = CFG.WORLD_SIZE / CFG.GRID
CFG.HEIGHT_SCALE = 0.25

-- Water module
-- Each cell: { height, velocity, normalX, normalZ }
local Water = {}
Water.__index = Water

--[=[
    Container for the heightfield grid. Each cell stores:
    { height:number, velocity:number, normalX:number, normalZ:number }

    @class Water
    @return Water
]=]
function Water.new(size: number): Water
	local self = setmetatable({}, Water)
	self.size = size
	local n = size * size
	self.A = table.create(n)
	self.B = table.create(n)
	for i = 1, n do
		self.A[i] = { 0, 0, 0, 0 }
		self.B[i] = { 0, 0, 0, 0 }
	end
	return self
end

--[=[
    @param x number -- column index (1-based)
    @param y number -- row index (1-based)
    @return number -- 1-based index into internal arrays A/B
]=]
function Water:idx(x: number, y: number): number
	return (math.clamp(y, 1, self.size) - 1) * self.size + math.clamp(x, 1, self.size)
end

--[=[
    Apply a circular drop disturbance to the heightfield.

    @param cx number -- drop center x in UV space [0,1]
    @param cy number -- drop center y in UV space [0,1]
    @param radius number
    @param strength number
    @return nil
]=]
function Water:addDrop(cx: number, cy: number, radius: number, strength: number)
	local size = self.size
	local A = self.A
	for y = 1, size do
		for x = 1, size do
			local u = (x - 0.5) / size
			local v = (y - 0.5) / size
			local du, dv = cx - u, cy - v
			local dist = math.sqrt(du * du + dv * dv)
			local drop = math.max(0, 1 - dist / radius)
			drop = 0.5 - math.cos(drop * math.pi) * 0.5
			local i = self:idx(x, y)
			A[i][1] = A[i][1] + drop * strength
		end
	end
end

--[=[
    Advance the heightfield simulation by one fixed step.

    @return nil
]=]
function Water:stepSimulation()
	local size = self.size
	local A, B = self.A, self.B
	local speed = 0.2
	local damp = 0.996
	for y = 1, size do
		for x = 1, size do
			local i = self:idx(x, y)
			if x == 1 or x == size or y == 1 or y == size then
				B[i][1] = 0
				B[i][2] = 0
				B[i][3] = A[i][3]
				B[i][4] = A[i][4]
			else
				local h = A[i][1]
				local avg = (
					A[self:idx(x - 1, y)][1]
					+ A[self:idx(x + 1, y)][1]
					+ A[self:idx(x, y - 1)][1]
					+ A[self:idx(x, y + 1)][1]
				) * 0.25
				local vel = (A[i][2] + (avg - h) * speed) * damp
				B[i][1] = h + vel
				B[i][2] = vel
				B[i][3] = A[i][3]
				B[i][4] = A[i][4]
			end
		end
	end
	self.A, self.B = self.B, self.A
end

--[=[
    Compute per-cell normals using central differences.

    @return nil
]=]
function Water:updateNormals()
	local size = self.size
	local A = self.A
	for y = 1, size do
		for x = 1, size do
			local i = self:idx(x, y)
			local h = A[i][1]
			local dxH = A[self:idx(x + 1, y)][1] - h
			local dyH = A[self:idx(x, y + 1)][1] - h
			local scale = 1 / CFG.CELL_SIZE
			local nx = -dxH * scale
			local ny = 1.0
			local nz = -dyH * scale
			local len = math.sqrt(nx * nx + ny * ny + nz * nz)
			if len > 1e-6 then
				A[i][3] = nx / len
				A[i][4] = nz / len
			else
				A[i][3] = 0
				A[i][4] = 0
			end
		end
	end
end

--[=[
    Apply a moving spherical disturbance (e.g., player) to the heightfield.

    @param oldCX number
    @param oldCZ number
    @param newCX number
    @param newCZ number
    @param radius number
    @return nil
]=]
function Water:moveSphere(oldCX: number, oldCZ: number, newCX: number, newCZ: number, radius: number)
	local A = self.A
	local size = self.size

	local dx = newCX - oldCX
	local dz = newCZ - oldCZ

	local speed = math.sqrt(dx * dx + dz * dz)
	local strength = speed * 0.01 + speed * speed * 0.003
	strength = math.clamp(strength, 0.001, 0.03)

	local areaScale = (CFG.WORLD_SIZE / size)
	strength *= (1 / areaScale) * 2.5

	for y = 1, size do
		for x = 1, size do
			local wx = (x - 0.5) / size * 2 - 1
			local wz = (y - 0.5) / size * 2 - 1

			local dx2 = wx - newCX
			local dz2 = wz - newCZ
			local dist = dx2 * dx2 + dz2 * dz2

			if dist < radius * radius then
				local i = self:idx(x, y)
				local impulse = 0.02 + speed * 0.08
				impulse = math.clamp(impulse, 0.01, 0.06)
				local sigma = radius * 0.18
				local falloff = math.exp(-dist / (2 * sigma * sigma))
				local h = strength * falloff
				A[i][1] += h * 0.4
				A[i][2] += h * 1.2
			end
		end
	end
end

-- Exported Luau type for Water (methods and fields).
export type Water = typeof(Water) & {
	size: number,
	A: { { number } },
	B: { { number } },
}

-- Renderer module
local Renderer = {}
Renderer.__index = Renderer

--[=[
    Builds an EditableMesh grid and stores vertex/uv/normal ids for updates.

    @class Renderer
    @param gridSize number
    @param worldSize number
    @param meshPart Instance
    @param ReflectionPart Instance
    @return Renderer
]=]
function Renderer.new(gridSize: number, worldSize: number, meshPart: MeshPart, ReflectionPart: MeshPart): Renderer
	local self = setmetatable({}, Renderer)
	self.n = gridSize
	self.wSize = worldSize
	self.meshPart = meshPart
	self.ReflectionPart = ReflectionPart
	self.vertIds = {}
	self.uvIds = {}
	self.normIds = {}

	local em = AssetService:CreateEditableMesh()
	self.em = em
	local n = gridSize

	for gy = 1, n do
		self.vertIds[gy] = {}
		self.uvIds[gy] = {}
		self.normIds[gy] = {}
		for gx = 1, n do
			local wx = ((gx - 1) / (n - 1) - 0.5) * worldSize
			local wz = ((gy - 1) / (n - 1) - 0.5) * worldSize
			self.vertIds[gy][gx] = em:AddVertex(Vector3.new(wx, 0, wz))
			self.uvIds[gy][gx] = em:AddUV(Vector2.new((gx - 1) / (n - 1), (gy - 1) / (n - 1)))
			self.normIds[gy][gx] = em:AddNormal(Vector3.new(0, 1, 0))
		end
	end

	for gy = 1, n - 1 do
		for gx = 1, n - 1 do
			local v00 = self.vertIds[gy][gx]
			local v10 = self.vertIds[gy][gx + 1]
			local v01 = self.vertIds[gy + 1][gx]
			local v11 = self.vertIds[gy + 1][gx + 1]
			local u00 = self.uvIds[gy][gx]
			local u10 = self.uvIds[gy][gx + 1]
			local u01 = self.uvIds[gy + 1][gx]
			local u11 = self.uvIds[gy + 1][gx + 1]
			local n00 = self.normIds[gy][gx]
			local n10 = self.normIds[gy][gx + 1]
			local n01 = self.normIds[gy + 1][gx]
			local n11 = self.normIds[gy + 1][gx + 1]

			local f1 = em:AddTriangle(v00, v01, v10)
			em:SetFaceUVs(f1, { u00, u01, u10 })
			em:SetFaceNormals(f1, { n00, n01, n10 })

			local f2 = em:AddTriangle(v10, v01, v11)
			em:SetFaceUVs(f2, { u10, u01, u11 })
			em:SetFaceNormals(f2, { n10, n01, n11 })
		end
	end

	local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	meshPart:ApplyMesh(mp)
	ReflectionPart:ApplyMesh(mp)

	return self
end

--[=[
    @param water table -- Water instance
    @return nil
]=]
function Renderer:applyWater(water: Water)
	local em = self.em
	local n = self.n
	local wSize = self.wSize
	local hScale = CFG.HEIGHT_SCALE
	local A = water.A
	local gSize = water.size

	for gy = 1, n do
		for gx = 1, n do
			local sx = math.clamp(math.round((gx - 1) / (n - 1) * (gSize - 1)) + 1, 1, gSize)
			local sy = math.clamp(math.round((gy - 1) / (n - 1) * (gSize - 1)) + 1, 1, gSize)
			local cell = A[water:idx(sx, sy)]

			local wx = ((gx - 1) / (n - 1) - 0.5) * wSize
			local wz = ((gy - 1) / (n - 1) - 0.5) * wSize
			em:SetPosition(self.vertIds[gy][gx], Vector3.new(wx, cell[1] * hScale, wz))

			local nx = cell[3]
			local nz = cell[4]
			local ny2 = 1 - nx * nx - nz * nz
			local ny = if ny2 > 0 then math.sqrt(ny2) else 1
			em:SetNormal(self.normIds[gy][gx], Vector3.new(nx, ny, nz))
		end
	end
end

-- Exported Luau type for Renderer
export type Renderer = typeof(Renderer) & {
	n: number,
	wSize: number,
	meshPart: Instance,
	ReflectionPart: Instance,
	vertIds: { [number]: { [number]: any } },
	uvIds: { [number]: { [number]: any } },
	normIds: { [number]: { [number]: any } },
	em: any,
}

-- Player tracker for local player
local PlayerTracker = {}
PlayerTracker.__index = PlayerTracker

--[=[
    Tracks the local player's HumanoidRootPart and converts world positions
    into mesh normalized [-1,1] space.

    @class PlayerTracker
    @param water table
    @param meshPart Instance
    @param worldSize number
    @return PlayerTracker
]=]
function PlayerTracker.new(water: Water, meshPart: MeshPart, worldSize: number): PlayerTracker
	local self = setmetatable({}, PlayerTracker)
	self.water = water
	self.meshPart = meshPart
	local size = meshPart.Size
	self.halfX = size.X * 0.5
	self.halfZ = size.Z * 0.5
	self.prevNX = nil
	self.prevNZ = nil
	self.wasOnWater = false
	return self
end

--[=[
    @param wpos Vector3
    @return number, number
]=]
function PlayerTracker:worldToNorm(wpos: Vector3): (number, number)
	local loc = self.meshPart.CFrame:PointToObjectSpace(wpos)
	local size = self.meshPart.Size
	local nx = loc.X / (size.X * 0.5)
	local nz = loc.Z / (size.Z * 0.5)
	return nx, nz
end

--[=[
    @param hrpPos Vector3
    @return boolean
]=]
function PlayerTracker:isOverWater(hrpPos: Vector3): boolean
	local loc = self.meshPart.CFrame:PointToObjectSpace(hrpPos)
	local insideXZ = math.abs(loc.X) <= self.halfX and math.abs(loc.Z) <= self.halfZ
	return insideXZ
end

--[=[
    @param hrp Instance
    @return nil
]=]
function PlayerTracker:update(hrp: BasePart?)
	if not hrp then
		return
	end
	local water = self.water
	local radius = CFG.SPHERE_RADIUS
	local pos = hrp.Position

	if self:isOverWater(pos) then
		local nx, nz = self:worldToNorm(pos)
		nx = math.clamp(nx, -0.98, 0.98)
		nz = math.clamp(nz, -0.98, 0.98)

		if self.prevNX then
			local dx = nx - self.prevNX
			local dz = nz - self.prevNZ
			local moveMag = dx * dx + dz * dz
			if moveMag > 2e-6 then
				water:moveSphere(self.prevNX, self.prevNZ, nx, nz, radius)
			end
		else
			local u = nx * 0.5 + 0.5
			local v = nz * 0.5 + 0.5
			water:addDrop(u, v, CFG.DROP_RADIUS * 2.5, CFG.DROP_STR * 2)
		end

		self.prevNX = nx
		self.prevNZ = nz
		self.wasOnWater = true
	else
		if self.wasOnWater and self.prevNX then
			local u = self.prevNX * 0.5 + 0.5
			local v = self.prevNZ * 0.5 + 0.5
			water:addDrop(u, v, CFG.DROP_RADIUS * 1.5, -CFG.DROP_STR * 0.8)
		end
		self.prevNX = nil
		self.prevNZ = nil
		self.wasOnWater = false
	end
end

-- Exported Luau type for PlayerTracker
export type PlayerTracker = typeof(PlayerTracker) & {
	water: Water,
	meshPart: Instance,
	halfX: number,
	halfZ: number,
	prevNX: number?,
	prevNZ: number?,
	wasOnWater: boolean,
}

-- Main
local localPlayer = game:GetService("Players").LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local root = workspace:WaitForChild("Water")
local meshPart = root:WaitForChild("OceanMesh", 10)
local ReflectionPart = root:WaitForChild("ReflectionOceanMesh", 10)

--[=[
    @return nil
]=]
local function main()
	local water = Water.new(CFG.GRID)
	local renderer = Renderer.new(CFG.GRID, CFG.WORLD_SIZE, meshPart, ReflectionPart)
	local tracker = PlayerTracker.new(water, meshPart, CFG.WORLD_SIZE)

	for i = 1, CFG.INIT_DROPS do
		local u = math.random() * 0.6 + 0.2
		local v = math.random() * 0.6 + 0.2
		local str = (i % 2 == 0) and CFG.DROP_STR or -CFG.DROP_STR
		water:addDrop(u, v, CFG.DROP_RADIUS, str)
	end

	local hrp = character:WaitForChild("HumanoidRootPart")
	localPlayer.CharacterAdded:Connect(function(newChar)
		character = newChar
		hrp = newChar:WaitForChild("HumanoidRootPart")
		tracker.prevNX = nil
		tracker.prevNZ = nil
		tracker.wasOnWater = true
	end)

	_G.OceanDrop = function(worldX: number, worldZ: number, rad: number?, str: number?)
		local loc = meshPart.CFrame:PointToObjectSpace(Vector3.new(worldX, 0, worldZ))
		local half = CFG.WORLD_SIZE * 0.5
		local u = loc.X / (half * 2) + 0.5
		local v = loc.Z / (half * 2) + 0.5
		water:addDrop(u, v, rad or CFG.DROP_RADIUS, str or CFG.DROP_STR)
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		tracker:update(hrp)
		while acc >= CFG.UPDATE_RATE do
			water:stepSimulation()
			water:updateNormals()
			acc = acc - CFG.UPDATE_RATE
		end
		renderer:applyWater(water)
	end)

	print(
		string.format(
			"[WebGLWater] Started (LocalScript) — grid %dx%d, plane %.0f studs.",
			CFG.GRID,
			CFG.GRID,
			CFG.WORLD_SIZE
		)
	)
end

main()
