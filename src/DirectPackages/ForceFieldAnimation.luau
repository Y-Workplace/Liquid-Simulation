local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local WIDTH, HEIGHT = 64, 64
local SIZE = Vector2.new(WIDTH, HEIGHT)
local TARGET_FPS = 15
local BAKED_FRAME_COUNT = 180

local FORCEFIELD_COLOR = Color3.fromRGB(255, 160, 70)
local FORCEFIELD_WARP_SCALE = 1.5
local FORCEFIELD_CORE_INTENSITY = 25
local FORCEFIELD_BLOOM_SPREAD = 4.5
local FORCEFIELD_STRENGTH = 1
local FORCEFIELD_EMISSIVE_STRENGTH = 3.75
local FORCEFIELD_NOISE_SCALE = 0.2
local FORCEFIELD_TIME_RADIUS = 1.35

local BYTES_PP = 4
local TOTAL_BYTES = WIDTH * HEIGHT * BYTES_PP
local FRAME_TIME = 1 / TARGET_FPS
local TAU = math.pi * 2

export type ForceFieldAnimation = {
	bakedColorFrames: { buffer },
	bakedEmissiveFrames: { buffer },
	cacheNotes: { MeshPart },
	connection: RBXScriptConnection?,
	editable: EditableImage?,
	emissiveEditable: EditableImage?,
	accumulator: number,
	frameIndex: number,
}

local ForceFieldAnimation = {}
ForceFieldAnimation.__index = ForceFieldAnimation

local function tileableNoise(x: number, y: number, t: number, scale: number, seed: number): number
	local u = (x / WIDTH) % 1
	local v = (y / HEIGHT) % 1
	local angleU = u * TAU
	local angleV = v * TAU
	local timeX = math.cos(t + seed) * FORCEFIELD_TIME_RADIUS
	local timeY = math.sin(t + seed) * FORCEFIELD_TIME_RADIUS

	local nx = math.cos(angleU) * scale + timeX
	local ny = math.sin(angleU) * scale + seed
	local nz = (math.cos(angleV) + math.sin(angleV)) * scale + timeY

	return math.noise(nx, ny, nz)
end

local function forceFieldIntensity(x: number, y: number, t: number): number
	local warp1 = tileableNoise(x, y, t, FORCEFIELD_NOISE_SCALE, 0.0)
	local warp2 = tileableNoise(x + warp1 * WIDTH, y - warp1 * HEIGHT, t, FORCEFIELD_NOISE_SCALE, 1.5)

	local warpedX = x + warp2 * FORCEFIELD_WARP_SCALE * WIDTH
	local warpedY = y + warp1 * FORCEFIELD_WARP_SCALE * HEIGHT

	local ridge = math.abs(tileableNoise(warpedX, warpedY, t, FORCEFIELD_NOISE_SCALE, 3.0))
	local core = math.exp(-ridge * FORCEFIELD_CORE_INTENSITY)
	local glow = math.exp(-ridge * FORCEFIELD_BLOOM_SPREAD) * 0.55

	return math.clamp((core + glow) * FORCEFIELD_STRENGTH, 0, 1)
end

local function setPixel(buf: buffer, x: number, y: number, r: number, g: number, b: number, a: number)
	local idx = (y * WIDTH + x) * BYTES_PP

	buffer.writeu8(buf, idx + 0, math.clamp(math.floor(r), 0, 255))
	buffer.writeu8(buf, idx + 1, math.clamp(math.floor(g), 0, 255))
	buffer.writeu8(buf, idx + 2, math.clamp(math.floor(b), 0, 255))
	buffer.writeu8(buf, idx + 3, math.clamp(math.floor(a), 0, 255))
end

function ForceFieldAnimation.new(forcefield: { MeshPart }?): ForceFieldAnimation
	local self: ForceFieldAnimation = setmetatable({
		bakedColorFrames = {},
		bakedEmissiveFrames = {},
		cacheForceField = forcefield or {},
		connection = nil,
		editable = nil,
		emissiveEditable = nil,
		accumulator = 0,
		frameIndex = 1,
	}, ForceFieldAnimation) :: any

	return self
end

function ForceFieldAnimation:Init()
	self.editable = AssetService:CreateEditableImage({ Size = SIZE })
	self.emissiveEditable = AssetService:CreateEditableImage({ Size = SIZE })
	self:_BakeFrames()
	self:_WriteFrame(self.frameIndex)

	for _, forceField in ipairs(self.cacheForceField) do
		self:_ApplyToForceField(forceField)
	end
end

function ForceFieldAnimation:Insert(forceField: MeshPart)
	table.insert(self.cacheForceField, forceField)
	self:_ApplyToForceField(forceField)
end

function ForceFieldAnimation:Start()
	if not self.editable or not self.emissiveEditable then
		self:Init()
	end

	self:Stop()

	self.connection = RunService.RenderStepped:Connect(function(dt)
		if not self.editable or not self.emissiveEditable then
			return
		end

		self.accumulator += dt

		if self.accumulator < FRAME_TIME then
			return
		end

		self.accumulator -= FRAME_TIME
		self.frameIndex = (self.frameIndex % BAKED_FRAME_COUNT) + 1

		self:_WriteFrame(self.frameIndex)
	end)
end

function ForceFieldAnimation:Stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

function ForceFieldAnimation:Destroy()
	self:Stop()

	if self.editable then
		self.editable:Destroy()
		self.editable = nil
	end

	if self.emissiveEditable then
		self.emissiveEditable:Destroy()
		self.emissiveEditable = nil
	end

	table.clear(self.bakedColorFrames)
	table.clear(self.bakedEmissiveFrames)
	table.clear(self.cacheForceField)
end

function ForceFieldAnimation:_BakeFrames()
	table.clear(self.bakedColorFrames)
	table.clear(self.bakedEmissiveFrames)

	for frame = 1, BAKED_FRAME_COUNT do
		local t = ((frame - 1) / BAKED_FRAME_COUNT) * TAU
		local colorBuffer = buffer.create(TOTAL_BYTES)
		local emissiveBuffer = buffer.create(TOTAL_BYTES)

		for y = 0, HEIGHT - 1 do
			for x = 0, WIDTH - 1 do
				local forceField = forceFieldIntensity(x, y, t)
				local forceFieldAlpha = forceField * 255

				setPixel(
					colorBuffer,
					x,
					y,
					FORCEFIELD_COLOR.R * 255,
					FORCEFIELD_COLOR.G * 255,
					FORCEFIELD_COLOR.B * 255,
					forceFieldAlpha
				)
				setPixel(emissiveBuffer, x, y, forceFieldAlpha, forceFieldAlpha, forceFieldAlpha, 255)
			end
		end

		table.insert(self.bakedColorFrames, colorBuffer)
		table.insert(self.bakedEmissiveFrames, emissiveBuffer)
	end
end

function ForceFieldAnimation:_WriteFrame(frameIndex: number)
	local editable = self.editable
	local emissiveEditable = self.emissiveEditable
	if not editable or not emissiveEditable then
		return
	end

	local colorFrame = self.bakedColorFrames[frameIndex]
	local emissiveFrame = self.bakedEmissiveFrames[frameIndex]
	if not colorFrame or not emissiveFrame then
		return
	end

	editable:WritePixelsBuffer(Vector2.new(0, 0), SIZE, colorFrame)
	emissiveEditable:WritePixelsBuffer(Vector2.new(0, 0), SIZE, emissiveFrame)
end

function ForceFieldAnimation:_ApplyToForceField(forceField: MeshPart)
	local editable = self.editable
	local emissiveEditable = self.emissiveEditable
	if not editable or not emissiveEditable then
		return
	end

	local surface = AssetService:CreateSurfaceAppearanceAsync({
		ColorMap = Content.fromObject(editable),
		EmissiveMask = Content.fromObject(emissiveEditable),
	})

	surface.AlphaMode = Enum.AlphaMode.Transparency
	surface.EmissiveStrength = FORCEFIELD_EMISSIVE_STRENGTH
	surface.EmissiveTint = FORCEFIELD_COLOR
	surface.Parent = forceField
end

return ForceFieldAnimation
