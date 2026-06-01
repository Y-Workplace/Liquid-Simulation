task.wait(5)

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

-- 🔧 CONFIGURAÇÕES -----------------------------
local WIDTH, HEIGHT = 64, 64
local SIZE = Vector2.new(WIDTH, HEIGHT)
local targetFPS = 15
local animationSpeed = 0.3
local reflectionSpeed = 0.5
local reflectionInterval = 3.0
local reflectionWidth = 0.05
local reflectionColor = Color3.fromRGB(255, 255, 255)
local reflectionIntensity = 0.8
local bakedFrameCount = 180
local noiseScale = 1 -- maior = mais detalhes
local pigmentThreshold = 0.3
local pigmentStrength = 0.8
local bakedColorFrames = {}
local bakedNoiseFrames = {}
local cacheNotes = {}
------------------------------------------------

-- 🧨 DISSOLVE -----------------------------
local dissolving = false
local dissolveProgress = 0
local dissolveSpeed = 0.5 -- ajusta timing da nota

local edgeWidth = 0.05
local edgeColor = Color3.fromRGB(255, 255, 0)
local edgeIntensity = 1
------------------------------------------

local function fbm(x, y, t)
	local total = 0
	local amplitude = 0.5
	local frequency = 1

	for _ = 1, 3 do
		total += math.noise(x * frequency, y * frequency, t) * amplitude
		frequency *= 2
		amplitude *= 0.5
	end

	return total
end

-- Cria EditableImage
local editable = AssetService:CreateEditableImage({Size = SIZE})

for _, Note in script.Parent.Notes:GetChildren() do
	Note.TextureContent = Content.fromObject(editable)

	local detector = Note:FindFirstChildOfClass("ClickDetector")
	table.insert(cacheNotes, Note)
	if detector then
		detector.MouseClick:Connect(function()
			Note.Transparency = 0.02
			dissolving = true
			dissolveProgress = 0
		end)
	end
end

-- Utilidades de buffer
local BYTES_PP = 4
local totalBytes = WIDTH * HEIGHT * BYTES_PP
local pixelBuffer = buffer.create(totalBytes)

local function setPixel(buf, x, y, r, g, b, a)
	local idx = (y * WIDTH + x) * BYTES_PP
	buffer.writeu8(buf, idx + 0, r)
	buffer.writeu8(buf, idx + 1, g)
	buffer.writeu8(buf, idx + 2, b)
	buffer.writeu8(buf, idx + 3, a)
end

local function applyDissolve(baseBuffer, noiseBuffer, threshold)
	local softness = 0.05

	for y = 0, HEIGHT - 1 do
		for x = 0, WIDTH - 1 do
			local idx = (y * WIDTH + x) * BYTES_PP

			local baseR = buffer.readu8(baseBuffer, idx)
			local baseG = buffer.readu8(baseBuffer, idx + 1)
			local baseB = buffer.readu8(baseBuffer, idx + 2)

			local noise = buffer.readu8(noiseBuffer, idx) / 255

			-- 🎯 curva (ESSENCIAL)
			-- noise = noise ^ 0.5

			local alpha = 255
			local glow = 0

			if noise < threshold - softness then
				alpha = 0

			elseif noise < threshold then
				local t = (noise - (threshold - softness)) / softness
				alpha = t * 255

				-- glow só nasce aqui (transição real)
				glow = 1 - t

			elseif noise < threshold + edgeWidth then
				local t = (noise - threshold) / edgeWidth

				-- glow fraco na borda externa
				glow = (1 - t) * 0.5
			end

			if glow > 0 then
				baseR = math.clamp(baseR + edgeColor.R * 255 * glow * edgeIntensity, 0, 255)
				baseG = math.clamp(baseG + edgeColor.G * 255 * glow * edgeIntensity, 0, 255)
				baseB = math.clamp(baseB + edgeColor.B * 255 * glow * edgeIntensity, 0, 255)
			end

			setPixel(pixelBuffer, x, y, baseR, baseG, baseB, alpha)
		end
	end
end

-- 🎨 Cores
local colorA = Color3.fromRGB(180, 70, 10)
local colorB = Color3.fromRGB(255, 160, 70)

-- 🧊 Gera textura tileable
for frame = 1, bakedFrameCount do
	local t = (frame / bakedFrameCount) * math.pi * 2
	local frameBuffer = buffer.create(totalBytes)
	local noiseBuffer = buffer.create(totalBytes)

	for y = 0, HEIGHT - 1 do
		for x = 0, WIDTH - 1 do
			local u = x / (WIDTH - 1)
			local v = y / (HEIGHT - 1)

			-- gera noise contínuo no espaço 4D (x,y + tempo)
			local n = fbm(u * noiseScale, v * noiseScale, math.sin(t))

			n = math.clamp((n + 1) * 0.5, 0, 1)

			local noiseByte = math.floor(n * 255)
			setPixel(noiseBuffer, x, y, noiseByte, noiseByte, noiseByte, 255)

			local mix = math.clamp((n - pigmentThreshold) / (1 - pigmentThreshold), 0, 1)

			local r = colorA.R + (colorB.R - colorA.R) * mix
			local g = colorA.G + (colorB.G - colorA.G) * mix
			local b = colorA.B + (colorB.B - colorA.B) * mix

			setPixel(frameBuffer, x, y, r * 255, g * 255, b * 255, 255)
		end
	end

	table.insert(bakedColorFrames, frameBuffer)
	table.insert(bakedNoiseFrames, noiseBuffer)
end

-- ☀️ Reflexo suave -------------------------------
local reflectionTimer = 0
local reflectionActive = false
local reflectionProgress = 0
local nextReflectionTime = math.random() * reflectionInterval + 1

local function applyReflection(bufferRef, progress)
	local width = reflectionWidth
	local center = progress * WIDTH
	local rR, rG, rB = reflectionColor.R * 255, reflectionColor.G * 255, reflectionColor.B * 255

	-- 🕊️ Transição de entrada/saída (fade-in/out no início e fim do reflexo)
	local appearFade = math.clamp(math.sin(math.pi * math.clamp(progress, 0, 1)), 0, 1)

	for y = 0, HEIGHT - 1 do
		for x = 0, WIDTH - 1 do
			local distance = math.abs(x - center) / (WIDTH * width)
			local idx = (y * WIDTH + x) * BYTES_PP

			local baseR = buffer.readu8(bufferRef, idx)
			local baseG = buffer.readu8(bufferRef, idx + 1)
			local baseB = buffer.readu8(bufferRef, idx + 2)

			if distance < 1 then
				-- 💫 Fade lateral: transparente nas bordas do reflexo
				local edgeFade = math.cos(distance * math.pi) * 0.5 + 0.5
				local totalFade = edgeFade * appearFade

				baseR = math.clamp(baseR + rR * reflectionIntensity * totalFade, 0, 255)
				baseG = math.clamp(baseG + rG * reflectionIntensity * totalFade, 0, 255)
				baseB = math.clamp(baseB + rB * reflectionIntensity * totalFade, 0, 255)
			end

			setPixel(pixelBuffer, x, y, baseR, baseG, baseB, 255)
		end
	end
end

-- 🎞️ Loop de render ------------------------------
local time = 0
local accumulator = 0
local frameTime = 1 / targetFPS
local frameIndex = 1

RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	time += dt * animationSpeed

	if reflectionActive then
		reflectionProgress += dt * reflectionSpeed
		if reflectionProgress >= 1 then
			reflectionActive = false
			nextReflectionTime = time + (math.random() * reflectionInterval + 2)
		end
	elseif time >= nextReflectionTime then
		reflectionActive = true
		reflectionProgress = 0
	end

	if accumulator >= frameTime then
		accumulator -= frameTime
		frameIndex = (frameIndex % bakedFrameCount) + 1
		local baseFrame = bakedColorFrames[frameIndex]
		local noiseFrame = bakedNoiseFrames[frameIndex]

		-- 🧨 DISSOLVE MODE
		if dissolving then
			dissolveProgress += math.min(dt * dissolveSpeed, 0.02)

			local t = dissolveProgress

			-- curva
			local shaped = t * t * t

			-- quantização
			local steps = 24
			local quantized = math.floor(shaped * steps) / steps

			-- jitter
			local jitter = math.noise(time * 6) * 0.015

			local finalThreshold = quantized + jitter

			applyDissolve(baseFrame, noiseFrame, finalThreshold)
			editable:WritePixelsBuffer(Vector2.new(0, 0), SIZE, pixelBuffer)

			if dissolveProgress >= 1 then
				dissolving = false

				for _, note in ipairs(cacheNotes) do
					note.Transparency = 0
				end
			end

			-- ✨ NORMAL MODE
		else
			if reflectionActive then
				applyReflection(baseFrame, reflectionProgress)
				editable:WritePixelsBuffer(Vector2.new(0, 0), SIZE, pixelBuffer)
			else
				editable:WritePixelsBuffer(Vector2.new(0, 0), SIZE, baseFrame)
			end
		end
	end
end)
