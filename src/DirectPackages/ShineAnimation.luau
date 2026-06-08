local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local WIDTH, HEIGHT = 64, 64
local SIZE = Vector2.new(WIDTH, HEIGHT)
local TARGET_FPS = 15

local SHINE_INTERVAL = 3.5 -- seconds between each sweep cycle
local BAKED_FRAME_COUNT = math.max(2, math.round(SHINE_INTERVAL * TARGET_FPS))
local SHINE_BAND_WIDTH = 0.18 -- fraction of the diagonal the bright band occupies (0..1)
local SHINE_PEAK = 1.0 -- max brightness of the band (0..1)
local SHINE_ANGLE_DEG = 30 -- sweep direction in degrees (0 = left→right, 45 = diagonal)
local SHINE_FADE_IN = 0.18 -- fraction of cycle spent fading in
local SHINE_FADE_OUT = 0.22 -- fraction of cycle spent fading out
local SHINE_COLOR = Color3.fromRGB(255, 255, 255)
local SHINE_BACKGROUND_COLOR = Color3.fromRGB(255, 160, 70)
local SHINE_BACKGROUND_ALPHA = 0.52
local SHINE_EMISSIVE_STRENGTH = 4.0

local BYTES_PP = 4
local TOTAL_BYTES = WIDTH * HEIGHT * BYTES_PP
local FRAME_TIME = 1 / TARGET_FPS
local SHINE_BACKGROUND_ALPHA_BYTE = SHINE_BACKGROUND_ALPHA * 255

local SHINE_COS = math.cos(math.rad(SHINE_ANGLE_DEG))
local SHINE_SIN = math.sin(math.rad(SHINE_ANGLE_DEG))
local DIAG = math.sqrt(WIDTH * WIDTH + HEIGHT * HEIGHT)

export type ShineAnimation = {
	bakedColorFrames: { buffer },
	bakedEmissiveFrames: { buffer },
	cacheParts: { MeshPart },
	connection: RBXScriptConnection?,
	editable: EditableImage?,
	emissiveEditable: EditableImage?,
	accumulator: number,
	frameIndex: number,
}

local ShineAnimation = {}
ShineAnimation.__index = ShineAnimation

-- ─── helpers ──────────────────────────────────────────────────────────────────

local function projection(x: number, y: number): number
	local cx = x - WIDTH * 0.5
	local cy = y - HEIGHT * 0.5
	return (cx * SHINE_COS + cy * SHINE_SIN) / DIAG + 0.5
end

local function bandIntensity(proj: number, cycleT: number): number
	local bandHalf = SHINE_BAND_WIDTH * 0.5
	local bandCenter = cycleT * (1 + SHINE_BAND_WIDTH) - bandHalf

	local dist = math.abs(proj - bandCenter)
	if dist >= bandHalf then
		return 0
	end

	-- Cosine taper within the band
	local bandT = 1 - (dist / bandHalf)
	local bandShape = 0.5 - 0.5 * math.cos(bandT * math.pi)

	-- Fade in / out envelope over the full cycle
	local envelope
	if cycleT < SHINE_FADE_IN then
		envelope = cycleT / SHINE_FADE_IN
	elseif cycleT > (1 - SHINE_FADE_OUT) then
		envelope = (1 - cycleT) / SHINE_FADE_OUT
	else
		envelope = 1
	end
	envelope = envelope * envelope * (3 - 2 * envelope) -- smoothstep

	return bandShape * envelope * SHINE_PEAK
end

local function setPixel(buf: buffer, x: number, y: number, r: number, g: number, b: number, a: number)
	local idx = (y * WIDTH + x) * BYTES_PP
	buffer.writeu8(buf, idx + 0, math.clamp(math.floor(r), 0, 255))
	buffer.writeu8(buf, idx + 1, math.clamp(math.floor(g), 0, 255))
	buffer.writeu8(buf, idx + 2, math.clamp(math.floor(b), 0, 255))
	buffer.writeu8(buf, idx + 3, math.clamp(math.floor(a), 0, 255))
end

-- ─── constructor ──────────────────────────────────────────────────────────────

function ShineAnimation.new(parts: { MeshPart }?): ShineAnimation
	return setmetatable({
		bakedColorFrames = {},
		bakedEmissiveFrames = {},
		cacheParts = parts or {},
		connection = nil,
		editable = nil,
		emissiveEditable = nil,
		accumulator = 0,
		frameIndex = 1,
	}, ShineAnimation) :: any
end

-- ─── public API ───────────────────────────────────────────────────────────────

function ShineAnimation:Init()
	self.editable = AssetService:CreateEditableImage({ Size = SIZE })
	self.emissiveEditable = AssetService:CreateEditableImage({ Size = SIZE })
	self:_BakeFrames()
	self:_WriteFrame(self.frameIndex)

	for _, part in ipairs(self.cacheParts) do
		self:_ApplyToPart(part)
	end
end

function ShineAnimation:Insert(part: MeshPart)
	table.insert(self.cacheParts, part)
	self:_ApplyToPart(part)
end

function ShineAnimation:Start()
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

function ShineAnimation:Stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

function ShineAnimation:Destroy()
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
	table.clear(self.cacheParts)
end

-- ─── private ──────────────────────────────────────────────────────────────────

function ShineAnimation:_BakeFrames()
	table.clear(self.bakedColorFrames)
	table.clear(self.bakedEmissiveFrames)

	-- Projection is constant per-pixel, compute once
	local projMap = table.create(WIDTH * HEIGHT)
	for y = 0, HEIGHT - 1 do
		for x = 0, WIDTH - 1 do
			projMap[y * WIDTH + x + 1] = projection(x, y)
		end
	end

	for frame = 1, BAKED_FRAME_COUNT do
		local cycleT = (frame - 1) / (BAKED_FRAME_COUNT - 1)

		local colorBuffer = buffer.create(TOTAL_BYTES)
		local emissiveBuffer = buffer.create(TOTAL_BYTES)

		for y = 0, HEIGHT - 1 do
			for x = 0, WIDTH - 1 do
				local intensity = bandIntensity(projMap[y * WIDTH + x + 1], cycleT)
		local shineValue = intensity * 255
				local colorAlpha = SHINE_BACKGROUND_ALPHA_BYTE + intensity * (255 - SHINE_BACKGROUND_ALPHA_BYTE)

				setPixel(
					colorBuffer,
					x,
					y,
					SHINE_BACKGROUND_COLOR.R * 255,
					SHINE_BACKGROUND_COLOR.G * 255,
					SHINE_BACKGROUND_COLOR.B * 255,
					colorAlpha
				)
				setPixel(emissiveBuffer, x, y, shineValue, shineValue, shineValue, 255)
			end
		end

		table.insert(self.bakedColorFrames, colorBuffer)
		table.insert(self.bakedEmissiveFrames, emissiveBuffer)
	end
end

function ShineAnimation:_WriteFrame(frameIndex: number)
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

function ShineAnimation:_ApplyToPart(part: MeshPart)
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
	surface.EmissiveStrength = SHINE_EMISSIVE_STRENGTH
	surface.EmissiveTint = SHINE_COLOR
	surface.Parent = part
end

return ShineAnimation
