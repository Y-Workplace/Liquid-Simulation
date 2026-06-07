local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local WIDTH, HEIGHT = 64, 64
local SIZE = Vector2.new(WIDTH, HEIGHT)
local TARGET_FPS = 15
local BAKED_FRAME_COUNT = 180
local NOISE_SCALE = 0.1
local PIGMENT_THRESHOLD = 0.3

local COLOR_A = Color3.fromRGB(180, 70, 10)
local COLOR_B = Color3.fromRGB(255, 160, 70)

local BYTES_PP = 4
local TOTAL_BYTES = WIDTH * HEIGHT * BYTES_PP
local FRAME_TIME = 1 / TARGET_FPS
local TAU = math.pi * 2
local ANIMATION_RADIUS = 1.5

export type NoteAnimation = {
	bakedColorFrames: { buffer },
	cacheNotes: { MeshPart },
	connection: RBXScriptConnection?,
	editable: EditableImage?,
	accumulator: number,
	frameIndex: number,
}

local NoteAnimation = {}
NoteAnimation.__index = NoteAnimation

local function tileableNoise(
	x: number,
	y: number,
	width: number,
	height: number,
	scale: number,
	offsetX: number,
	offsetY: number
): number
	-- Torus sampling keeps the baked image seamless when UVs repeat.
	local u = x / width
	local v = y / height
	local angleU = u * TAU
	local angleV = v * TAU
	local nx = math.cos(angleU) * scale
	local ny = math.sin(angleU) * scale
	local nz = math.cos(angleV) * scale
	local nw = math.sin(angleV) * scale

	return math.noise(nx + offsetX, ny, nz + nw + offsetY)
end

local function fbm(x: number, y: number, t: number): number
	local total = 0
	local amplitude = 0.5
	local frequency = 1
	local offsetX = math.cos(t) * ANIMATION_RADIUS
	local offsetY = math.sin(t) * ANIMATION_RADIUS

	for _ = 1, 3 do
		total += tileableNoise(x, y, WIDTH, HEIGHT, NOISE_SCALE * frequency, offsetX, offsetY)
			* amplitude
		frequency *= 2
		amplitude *= 0.5
	end

	return total
end

local function setPixel(buf: buffer, x: number, y: number, r: number, g: number, b: number, a: number)
	local idx = (y * WIDTH + x) * BYTES_PP

	buffer.writeu8(buf, idx + 0, math.clamp(math.floor(r), 0, 255))
	buffer.writeu8(buf, idx + 1, math.clamp(math.floor(g), 0, 255))
	buffer.writeu8(buf, idx + 2, math.clamp(math.floor(b), 0, 255))
	buffer.writeu8(buf, idx + 3, math.clamp(math.floor(a), 0, 255))
end

function NoteAnimation.new(notes: { MeshPart }?): NoteAnimation
	local self: NoteAnimation = setmetatable({
		bakedColorFrames = {},
		cacheNotes = notes or {},
		connection = nil,
		editable = nil,
		accumulator = 0,
		frameIndex = 1,
	}, NoteAnimation) :: any

	return self
end

function NoteAnimation:Init()
	self.editable = AssetService:CreateEditableImage({ Size = SIZE })
	self:_BakeFrames()

	for _, note in ipairs(self.cacheNotes) do
		self:_ApplyToNote(note)
	end
end

function NoteAnimation:Insert(note: MeshPart)
	table.insert(self.cacheNotes, note)
	self:_ApplyToNote(note)
end

function NoteAnimation:Start()
	if not self.editable then
		self:Init()
	end

	self:Stop()

	self.connection = RunService.RenderStepped:Connect(function(dt)
		local editable = self.editable
		if not editable then
			return
		end

		self.accumulator += dt

		if self.accumulator < FRAME_TIME then
			return
		end

		self.accumulator -= FRAME_TIME
		self.frameIndex = (self.frameIndex % BAKED_FRAME_COUNT) + 1

		local baseFrame = self.bakedColorFrames[self.frameIndex]
		if baseFrame then
			editable:WritePixelsBuffer(Vector2.new(0, 0), SIZE, baseFrame)
		end
	end)
end

function NoteAnimation:Stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

function NoteAnimation:Destroy()
	self:Stop()

	if self.editable then
		self.editable:Destroy()
		self.editable = nil
	end

	table.clear(self.bakedColorFrames)
	table.clear(self.cacheNotes)
end

function NoteAnimation:_BakeFrames()
	table.clear(self.bakedColorFrames)

	for frame = 1, BAKED_FRAME_COUNT do
		local t = ((frame - 1) / BAKED_FRAME_COUNT) * TAU
		local frameBuffer = buffer.create(TOTAL_BYTES)

		for y = 0, HEIGHT - 1 do
			for x = 0, WIDTH - 1 do
				local n = fbm(x, y, t)

				n = math.clamp((n + 1) * 0.5, 0, 1)

				local mix = math.clamp((n - PIGMENT_THRESHOLD) / (1 - PIGMENT_THRESHOLD), 0, 1)
				local r = COLOR_A.R + (COLOR_B.R - COLOR_A.R) * mix
				local g = COLOR_A.G + (COLOR_B.G - COLOR_A.G) * mix
				local b = COLOR_A.B + (COLOR_B.B - COLOR_A.B) * mix

				setPixel(frameBuffer, x, y, r * 255, g * 255, b * 255, 255)
			end
		end

		table.insert(self.bakedColorFrames, frameBuffer)
	end
end

function NoteAnimation:_ApplyToNote(note: MeshPart)
	local editable = self.editable
	if not editable then
		return
	end

	local surface = AssetService:CreateSurfaceAppearanceAsync({
		ColorMap = Content.fromObject(editable),
	})

	surface.Parent = note
end

return NoteAnimation
