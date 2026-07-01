--[=[
	Connected Discord-GitHub
	Discord Username: rhythm.mania
	Roblox Username: @Y_Hythm

	-======================================================================-

    WebGL Water — ported to Roblox EditableMesh
    Based on https://madebyevan.com/webgl-water/ (Evan Wallace, MIT License)

    Setup:
      1. Place this LocalScript under StarterPlayerScripts.
      2. Create a MeshPart in Workspace named "OceanMesh" and a
         "ReflectionOceanMesh" MeshPart for reflections.
         • Anchored: true | CanCollide: false | CastShadow: false
      3. The simulation runs per-client using EditableMesh.

	-======================================================================-

	Why EditableMesh instead of a shader/terrain approach: the original WebGL
	demo drives a real heightfield mesh with per-vertex normals computed from
	a wave equation, not a fake procedural ripple. EditableMesh lets us mirror
	that 1:1 (real vertex displacement + real normals) instead of faking it
	with a scrolling normal map, at the cost of doing the simulation in Luau
	on the CPU instead of on the GPU like the original.
]=]

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

-- Configuration
local CFG = {
	GRID = 64, -- vertices per side of the RENDER mesh (not the sim grid — see Water.new)
	WORLD_SIZE = 200, -- world size in studs

	UPDATE_RATE = 1 / 40, -- fixed timestep for the wave equation; decoupled from
	-- frame rate so the simulation stays numerically stable
	-- (the diffusion-style update in stepSimulation blows up
	-- if dt varies too much between steps)

	DROP_RADIUS = 0.05, -- drop radius in UV [0,1]
	DROP_STR = 0.06, -- drop strength

	SPHERE_RADIUS = 0.18, -- radius of the disturbance the player's body pushes
	-- into the water, in normalized [-1,1] mesh space
	SPHERE_SCALE = 1.2,

	INIT_DROPS = 16, -- a handful of random drops at startup so the ocean
	-- doesn't look perfectly flat/dead the instant it loads
}

CFG.CELL_SIZE = CFG.WORLD_SIZE / CFG.GRID
CFG.HEIGHT_SCALE = 0.25 -- scales simulated height units into studs; kept low
-- so waves stay visually subtle instead of looking like a storm

-- Water module
-- Each cell: { height, velocity, normalX, normalZ }
-- Stored as a flat array of 4-element tables (not 4 parallel arrays) to keep
-- everything for one cell in one allocation/cache line during the hot loops.
local Water = {}
Water.__index = Water

--[=[
    Container for the heightfield grid. Each cell stores:
    { height:number, velocity:number, normalX:number, normalZ:number }

    Uses a double-buffer (A/B) so stepSimulation can read the previous frame's
    heights while writing the next frame's heights without cells corrupting
    each other mid-update (a single shared buffer would let a cell's neighbor
    read an already-updated value instead of the old one, which would
    silently break the wave equation's stability).

    @class Water
    @return Water
]=]
function Water.new(size: number): Water
	local self = setmetatable({}, Water)
	self.size = size
	local n = size * size
	self.A = table.create(n) -- current state (read from this frame)
	self.B = table.create(n) -- scratch buffer for next state, swapped in after each step
	for i = 1, n do
		self.A[i] = { 0, 0, 0, 0 }
		self.B[i] = { 0, 0, 0, 0 }
	end
	return self
end

--[=[
    Converts 2D grid coordinates into a 1D array index, clamping instead of
    wrapping so that any out-of-range neighbor lookup (e.g. x-1 at the left
    edge) safely collapses onto the edge cell itself rather than erroring or
    wrapping to the opposite side of the grid.

    @param x number -- column index (1-based)
    @param y number -- row index (1-based)
    @return number -- 1-based index into internal arrays A/B
]=]
function Water:idx(x: number, y: number): number
	return (math.clamp(y, 1, self.size) - 1) * self.size + math.clamp(x, 1, self.size)
end

--[=[
    Apply a circular drop disturbance to the heightfield.

    The falloff uses a cosine-based smoothstep (0.5 - cos(x*pi)*0.5) rather
    than a linear ramp so drops blend into the surrounding water smoothly —
    a linear falloff would leave a visible "kink" in the surface normals at
    the edge of the disturbed circle.

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
			-- sample at cell centers (x-0.5)/size, not x/size, so the drop
			-- is symmetric around its center regardless of grid resolution
			local u = (x - 0.5) / size
			local v = (y - 0.5) / size
			local du, dv = cx - u, cy - v
			local dist = math.sqrt(du * du + dv * dv)
			local drop = math.max(0, 1 - dist / radius)
			drop = 0.5 - math.cos(drop * math.pi) * 0.5 -- smooth (not linear) falloff, see above
			local i = self:idx(x, y)
			A[i][1] = A[i][1] + drop * strength
		end
	end
end

--[=[
    Advance the heightfield simulation by one fixed step.

    This is a discrete wave equation implemented as a damped diffusion:
    each cell's velocity is nudged toward the average height of its 4
    neighbors, then that velocity integrates into height. This is the same
    approach as the original WebGL demo's fragment-shader update pass,
    translated from a GPU texture convolution into a plain CPU loop.

    Border cells are pinned to height 0 (a fixed boundary) rather than
    simulated, which prevents energy from reflecting/building up forever at
    the mesh edges.

    @return nil
]=]
function Water:stepSimulation()
	local size = self.size
	local A, B = self.A, self.B
	local speed = 0.2 -- how strongly a cell is pulled toward its neighbors' average
	-- (higher = faster wave propagation, but too high goes unstable)
	local damp = 0.996 -- velocity decay per step so ripples eventually settle
	-- instead of oscillating forever
	for y = 1, size do
		for x = 1, size do
			local i = self:idx(x, y)
			if x == 1 or x == size or y == 1 or y == size then
				-- edge cells: clamp to a flat, resting boundary
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
				-- push velocity toward the neighborhood average, then damp it
				local vel = (A[i][2] + (avg - h) * speed) * damp
				B[i][1] = h + vel
				B[i][2] = vel
				-- normals are recomputed separately in updateNormals(), so we
				-- just carry the old values forward here
				B[i][3] = A[i][3]
				B[i][4] = A[i][4]
			end
		end
	end
	-- swap buffers instead of copying B into A — much cheaper, and safe since
	-- this frame's A is no longer needed once B is fully written
	self.A, self.B = self.B, self.A
end

--[=[
    Compute per-cell normals using central differences.

    Uses forward differences (x+1, y+1) rather than true central differences
    (x+1 minus x-1) for cost reasons — it's half the neighbor lookups per
    cell, and at this grid resolution the resulting normals are visually
    indistinguishable from proper central differencing.

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
			-- convert height deltas (in sim units) into slope-per-stud so the
			-- resulting normal is consistent regardless of world scale
			local scale = 1 / CFG.CELL_SIZE
			local nx = -dxH * scale
			local ny = 1.0
			local nz = -dyH * scale
			local len = math.sqrt(nx * nx + ny * ny + nz * nz)
			if len > 1e-6 then
				-- normalize; ny is reconstructed later on the render side from
				-- nx/nz (see Renderer:applyWater), so only nx/nz are stored here
				A[i][3] = nx / len
				A[i][4] = nz / len
			else
				-- degenerate/flat cell: fall back to a perfectly flat normal
				A[i][3] = 0
				A[i][4] = 0
			end
		end
	end
end

--[=[
    Apply a moving spherical disturbance (e.g., player) to the heightfield.

    Unlike addDrop (a single static impulse), this models a body dragging
    through the water: strength scales with how fast the player is moving
    between the old and new sample points, so standing still barely
    disturbs the water while swimming fast carves a visible wake.

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

	-- speed-based strength: a quadratic term is added on top of the linear
	-- term so fast motion feels disproportionately more disruptive (matches
	-- how a real wake grows nonlinearly with speed), then clamped so a single
	-- frame spike (e.g. teleport) can't blow up the simulation
	local speed = math.sqrt(dx * dx + dz * dz)
	local strength = speed * 0.01 + speed * speed * 0.003
	strength = math.clamp(strength, 0.001, 0.03)

	-- compensate for grid resolution: a coarser grid needs a proportionally
	-- stronger impulse per cell to produce the same visual displacement
	local areaScale = (CFG.WORLD_SIZE / size)
	strength *= (1 / areaScale) * 2.5

	for y = 1, size do
		for x = 1, size do
			local wx = (x - 0.5) / size * 2 - 1
			local wz = (y - 0.5) / size * 2 - 1

			local dx2 = wx - newCX
			local dz2 = wz - newCZ
			local dist = dx2 * dx2 + dz2 * dz2 -- squared distance; avoids a sqrt per cell

			if dist < radius * radius then
				local i = self:idx(x, y)
				-- extra speed-scaled "impulse" term, separate from strength,
				-- so fast movement also stiffens the immediate splash response
				local impulse = 0.02 + speed * 0.08
				impulse = math.clamp(impulse, 0.01, 0.06)
				-- Gaussian falloff (not linear/cosine like addDrop) gives a
				-- softer, more "body pushing water" feel than a sharp-edged drop
				local sigma = radius * 0.18
				local falloff = math.exp(-dist / (2 * sigma * sigma))
				local h = strength * falloff
				A[i][1] += h * 0.4 -- height nudged gently...
				A[i][2] += h * 1.2 -- ...but velocity gets a bigger kick, so the
				-- disturbance visibly propagates outward next step
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
-- Bridges the abstract Water simulation grid to an actual EditableMesh the
-- player can see. Kept as a separate module so the simulation resolution
-- (Water.size) and the render mesh resolution (CFG.GRID) can differ freely —
-- see Renderer:applyWater's resampling logic.
local Renderer = {}
Renderer.__index = Renderer

--[=[
    Builds an EditableMesh grid and stores vertex/uv/normal ids for updates.

    Vertex/UV/normal ids are cached per-cell up front because EditableMesh
    requires referencing existing ids to update them later — rebuilding the
    mesh topology every frame would be far more expensive than just moving
    existing vertices.

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

	-- lay out a flat grid of vertices centered on the origin, with normals
	-- initialized pointing straight up (they get overwritten every frame
	-- once the simulation starts, this is just a safe starting pose)
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

	-- triangulate each grid cell into 2 triangles; each vertex needs its own
	-- UV/normal reference per face (rather than sharing one global id) since
	-- EditableMesh normals/UVs are attached per-face-corner, not per-vertex
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

	-- both the visible ocean and its reflection copy share the exact same
	-- generated mesh asset, so the reflection always stays perfectly in sync
	-- with the real surface without needing a second simulation
	local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	meshPart:ApplyMesh(mp)
	ReflectionPart:ApplyMesh(mp)

	return self
end

--[=[
    Push the current Water simulation state into the EditableMesh.

    Resamples from the simulation grid (water.size) into the render grid
    (self.n) via nearest-neighbor lookup, so the two resolutions can be
    tuned independently — e.g. running a coarse, cheap simulation while
    still rendering a denser, smoother-looking mesh.

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
			-- map this render-grid cell onto the nearest simulation-grid cell
			local sx = math.clamp(math.round((gx - 1) / (n - 1) * (gSize - 1)) + 1, 1, gSize)
			local sy = math.clamp(math.round((gy - 1) / (n - 1) * (gSize - 1)) + 1, 1, gSize)
			local cell = A[water:idx(sx, sy)]

			local wx = ((gx - 1) / (n - 1) - 0.5) * wSize
			local wz = ((gy - 1) / (n - 1) - 0.5) * wSize
			em:SetPosition(self.vertIds[gy][gx], Vector3.new(wx, cell[1] * hScale, wz))

			-- rebuild the Y component of the normal from X/Z rather than
			-- storing it: since the vector must be unit length, Y is fully
			-- determined by X and Z, so storing it separately would just be
			-- redundant data that could drift out of sync
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
-- Separated from Water/Renderer because it deals purely with translating
-- "where is the player's body in world space" into the simulation's
-- normalized coordinate space — a concern neither of the other two modules
-- should need to know about.
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
	-- prevNX/prevNZ double as "was the player over the water last frame?" —
	-- nil means "not currently tracked", which update() uses to distinguish
	-- a fresh entry onto the water (addDrop) from continuous movement (moveSphere)
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
	-- convert to the mesh's local space first so the water plane can be
	-- moved/rotated in the world without breaking the mapping
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
	-- a simple XZ bounding-box check against the mesh's local half-extents;
	-- deliberately ignores Y so a player swimming under/over the surface
	-- (not just exactly at it) still counts as "over water"
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
		-- clamp slightly inside [-1,1] rather than exactly to it, so moveSphere's
		-- radius check near the very edge doesn't sample outside the grid
		nx = math.clamp(nx, -0.98, 0.98)
		nz = math.clamp(nz, -0.98, 0.98)

		if self.prevNX then
			-- already tracking: only push a disturbance if the player actually
			-- moved a meaningful amount, to avoid wasting a full-grid pass
			-- (moveSphere) on sub-pixel jitter every single frame
			local dx = nx - self.prevNX
			local dz = nz - self.prevNZ
			local moveMag = dx * dx + dz * dz
			if moveMag > 2e-6 then
				water:moveSphere(self.prevNX, self.prevNZ, nx, nz, radius)
			end
		else
			-- first frame over the water: no previous position to drag from,
			-- so simulate a "splash" entry with a one-off drop instead
			local u = nx * 0.5 + 0.5
			local v = nz * 0.5 + 0.5
			water:addDrop(u, v, CFG.DROP_RADIUS * 2.5, CFG.DROP_STR * 2)
		end

		self.prevNX = nx
		self.prevNZ = nz
		self.wasOnWater = true
	else
		-- player just left the water this frame: add a small negative drop
		-- (a dip rather than a bump) at their last known position, so exiting
		-- the water reads as the surface "closing" behind them
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
-- Runs entirely client-side (LocalScript): the wave simulation is cosmetic
-- and doesn't need to be authoritative/replicated, so keeping it local avoids
-- burdening the server and avoids network replication lag on the ripples.
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

	-- seed the ocean with a mix of positive/negative drops at startup so it
	-- already has some texture/motion the instant it becomes visible, rather
	-- than starting perfectly flat and taking a moment to look "alive"
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
		-- reset tracking state on respawn so the new character doesn't
		-- inherit a stale previous position from the old one and cause
		-- a spurious "teleport" disturbance
		tracker.prevNX = nil
		tracker.prevNZ = nil
		tracker.wasOnWater = true
	end)

	-- exposed as a global so other scripts (e.g. a boat, a projectile impact)
	-- can trigger a splash in world coordinates without needing a reference
	-- to the internal Water instance directly
	_G.OceanDrop = function(worldX: number, worldZ: number, rad: number?, str: number?)
		local loc = meshPart.CFrame:PointToObjectSpace(Vector3.new(worldX, 0, worldZ))
		local half = CFG.WORLD_SIZE * 0.5
		local u = loc.X / (half * 2) + 0.5
		local v = loc.Z / (half * 2) + 0.5
		water:addDrop(u, v, rad or CFG.DROP_RADIUS, str or CFG.DROP_STR)
	end

	-- fixed-timestep accumulator: Heartbeat's dt varies with frame rate, but
	-- the wave equation needs a constant dt to stay numerically stable, so we
	-- accumulate real time and only step the simulation in fixed UPDATE_RATE
	-- chunks (possibly multiple steps in one frame if the game is lagging)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		tracker:update(hrp) -- player disturbance sampled every frame, not just every sim step
		while acc >= CFG.UPDATE_RATE do
			water:stepSimulation()
			water:updateNormals()
			acc = acc - CFG.UPDATE_RATE
		end
		-- mesh is updated every render frame regardless of sim step count,
		-- so visuals stay smooth even if the simulation itself is stepping
		-- less often than the frame rate
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
