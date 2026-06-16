--!strict

export type CascadeConfig = {
	TileLength: Vector2?,
	DisplacementScale: number?,
	NormalScale: number?,
	WindSpeed: number?,
	WindDirection: number?,
	FetchLength: number?,
	Swell: number?,
	Spread: number?,
	Detail: number?,
	Whitecap: number?,
	FoamAmount: number?,
	ComponentCount: number?,
	Seed: number?,
}

export type SpectrumOptions = {
	ComponentCount: number?,
	HeightScale: number?,
	Choppiness: number?,
	TimeScale: number?,
	Seed: number?,
}

export type WaveSample = {
	displacement: Vector3,
	height: number,
	normal: Vector3,
	foam: number,
	foamAmount: number,
	slope: number,
}

export type BakedSpectrum = {
	ComponentBuffer: buffer,
	CascadeBuffer: buffer,
	ComponentCount: number,
	CascadeCount: number,
}

export type WaveSpectrum = {
	ComponentBuffer: buffer,
	CascadeBuffer: buffer,
	ComponentCount: number,
	CascadeCount: number,
	HeightScale: number,
	Choppiness: number,
	TimeScale: number,
	Sample: (self: WaveSpectrum, worldPosition: Vector3, time: number) -> WaveSample,
	SampleLod: (self: WaveSpectrum, worldPosition: Vector3, time: number, detailFactor: number) -> WaveSample,
	SampleWeighted: (
		self: WaveSpectrum,
		worldPosition: Vector3,
		time: number,
		detailFactor: number,
		cascadeWeights: { number }?
	) -> WaveSample,
	SampleWeighted3: (
		self: WaveSpectrum,
		worldPosition: Vector3,
		time: number,
		detailFactor: number,
		oceanWeight: number,
		lakeWeight: number,
		shallowWeight: number
	) -> WaveSample,
	SampleBakedWeighted3XZ: (
		self: WaveSpectrum,
		x: number,
		z: number,
		time: number,
		detailFactor: number,
		oceanWeight: number,
		lakeWeight: number,
		shallowWeight: number
	) -> (number, number, number, number),
	GetHeight: (self: WaveSpectrum, worldPosition: Vector3, time: number, steps: number?) -> number,
}

type Cascade = {
	tileLength: Vector2,
	displacementScale: number,
	normalScale: number,
	windSpeed: number,
	windDirection: number,
	fetchLength: number,
	swell: number,
	spread: number,
	detail: number,
	whitecap: number,
	foamAmount: number,
}

local WaveSpectrumClass = {}
WaveSpectrumClass.__index = WaveSpectrumClass

local G = 9.81
local DEPTH = 20
local TAU = math.pi * 2
local EPSILON = 1e-6
local GERSTNER_WAVE_COUNT = 8

local COMPONENT_STRIDE = 7
local COMPONENT_BYTES = COMPONENT_STRIDE * 4
local COMPONENT_DIRECTION_X = 0
local COMPONENT_DIRECTION_Z = 1
local COMPONENT_K = 2
local COMPONENT_OMEGA = 3
local COMPONENT_AMPLITUDE = 4
local COMPONENT_CHOP = 5
local COMPONENT_PHASE = 6

local CASCADE_STRIDE = 5
local CASCADE_BYTES = CASCADE_STRIDE * 4
local CASCADE_COMPONENT_START = 0
local CASCADE_COMPONENT_COUNT = 1
local CASCADE_NORMAL_SCALE = 2
local CASCADE_WHITECAP = 3
local CASCADE_FOAM_AMOUNT = 4

local WEIGHT_STRIDE = 6
local WEIGHT_BYTES = WEIGHT_STRIDE * 4
local WEIGHT_DIRECTION_X = 0
local WEIGHT_DIRECTION_Z = 1
local WEIGHT_K = 2
local WEIGHT_OMEGA = 3
local WEIGHT_PHASE = 4
local WEIGHT_VALUE = 5

local DEFAULT_CASCADE = {
	TileLength = Vector2.new(50, 50),
	DisplacementScale = 1,
	NormalScale = 1,
	WindSpeed = 20,
	WindDirection = 0,
	FetchLength = 550,
	Swell = 0.8,
	Spread = 0.2,
	Detail = 1,
	Whitecap = 0.5,
	FoamAmount = 5,
	ComponentCount = nil,
	Seed = nil,
}

local function componentOffset(index: number, field: number): number
	return index * COMPONENT_BYTES + field * 4
end

local function cascadeOffset(index: number, field: number): number
	return index * CASCADE_BYTES + field * 4
end

local function weightOffset(index: number, field: number): number
	return index * WEIGHT_BYTES + field * 4
end

local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function hash01(seed: number, index: number, salt: number): number
	local value = math.sin(seed * 12.9898 + index * 78.233 + salt * 37.719) * 43758.5453123
	return value - math.floor(value)
end

local function gaussian(seed: number, index: number): number
	local u1 = math.max(hash01(seed, index, 1), EPSILON)
	local u2 = hash01(seed, index, 2)
	return math.sqrt(-2 * math.log(u1)) * math.cos(TAU * u2)
end

local function dispersionRelation(k: number): number
	return math.sqrt(G * k * math.tanh(k * DEPTH))
end

local function dispersionDerivative(k: number): number
	local a = k * DEPTH
	local b = math.tanh(a)
	local dispersion = math.max(dispersionRelation(k), EPSILON)

	return 0.5 * G * (b + a * (1 - b * b)) / dispersion
end

local function jonswapAlpha(windSpeed: number, fetchLengthMeters: number): number
	return 0.076 * ((windSpeed * windSpeed) / (fetchLengthMeters * G)) ^ 0.22
end

local function jonswapPeakAngularFrequency(windSpeed: number, fetchLengthMeters: number): number
	return 22 * ((G * G) / (windSpeed * fetchLengthMeters)) ^ (1 / 3)
end

local function longuetHigginsNormalization(s: number): number
	local root = math.sqrt(math.max(s, EPSILON))

	if s < 0.4 then
		return (0.5 / math.pi) + s * (0.220636 + s * (-0.109 + s * 0.09))
	end

	return (root * 0.5 + (1 / root) * 0.0625) / math.sqrt(math.pi)
end

local function longuetHigginsFunction(s: number, theta: number): number
	return longuetHigginsNormalization(s) * math.abs(math.cos(theta * 0.5)) ^ (2 * s)
end

local function hasselmannDirectionalSpread(
	omega: number,
	peakOmega: number,
	windSpeed: number,
	theta: number,
	swell: number
): number
	local p = omega / peakOmega
	local s

	if omega <= peakOmega then
		s = 6.97 * math.abs(p) ^ 4.06
	else
		s = 9.77 * math.abs(p) ^ (-2.33 - 1.45 * (windSpeed * peakOmega / G - 1.17))
	end

	local swellShape = 16 * math.tanh(peakOmega / math.max(omega, EPSILON)) * swell * swell
	return longuetHigginsFunction(s + swellShape, theta)
end

local function tmaSpectrum(omega: number, peakOmega: number, alpha: number): number
	local beta = 1.25
	local gamma = 3.3
	local sigma = if omega <= peakOmega then 0.07 else 0.09
	local r = math.exp(-((omega - peakOmega) * (omega - peakOmega)) / (2 * sigma * sigma * peakOmega * peakOmega))
	local jonswap = (alpha * G * G) / math.max(omega ^ 5, EPSILON)
		* math.exp(-beta * (peakOmega / math.max(omega, EPSILON)) ^ 4)
		* gamma ^ r

	local omegaDepth = math.min(omega * math.sqrt(DEPTH / G), 2)
	local depthAttenuation

	if omegaDepth <= 1 then
		depthAttenuation = 0.5 * omegaDepth * omegaDepth
	else
		depthAttenuation = 1 - 0.5 * (2 - omegaDepth) * (2 - omegaDepth)
	end

	return jonswap * depthAttenuation
end

local function directionalSpectrum(k: number, angleOffset: number, cascade: Cascade): number
	local fetchMeters = math.max(cascade.fetchLength, 0.0001) * 1000
	local windSpeed = math.max(cascade.windSpeed, 0.0001)
	local alpha = jonswapAlpha(windSpeed, fetchMeters)
	local peakOmega = jonswapPeakAngularFrequency(windSpeed, fetchMeters)
	local omega = dispersionRelation(k)
	local spectrum = tmaSpectrum(omega, peakOmega, alpha)
	local flatSpread = 0.5 / math.pi
	local directional = hasselmannDirectionalSpread(omega, peakOmega, windSpeed, angleOffset, cascade.swell)
	local spread = mix(flatSpread, directional, 1 - cascade.spread)
	local detailAttenuation = math.exp(-((1 - cascade.detail) * (1 - cascade.detail)) * k * k)

	return math.max(spectrum * spread * detailAttenuation, 0)
end

local function spectralAmplitude(k: number, angleOffset: number, cascade: Cascade): number
	local dkX = TAU / cascade.tileLength.X
	local dkY = TAU / cascade.tileLength.Y
	local omegaNorm = dispersionDerivative(k) / math.max(k, EPSILON) * dkX * dkY
	local density = directionalSpectrum(k, angleOffset, cascade)

	return math.sqrt(math.max(2 * density * omegaNorm, 0))
end

local function readCascadeValue<T>(config: CascadeConfig, key: string, fallback: T): T
	local value = (config :: any)[key]

	if value == nil then
		return fallback
	end

	return value
end

local function gerstnerCountForCascade(index: number, cascadeCount: number): number
	local activeCascadeCount = math.min(cascadeCount, GERSTNER_WAVE_COUNT)

	if index > activeCascadeCount then
		return 0
	end

	if activeCascadeCount == 1 then
		return GERSTNER_WAVE_COUNT
	end

	local primaryCount = math.min(4, GERSTNER_WAVE_COUNT - (activeCascadeCount - 1))
	local remaining = GERSTNER_WAVE_COUNT - primaryCount
	local remainingCascades = activeCascadeCount - 1

	if index == 1 then
		return primaryCount
	end

	local baseCount = math.floor(remaining / remainingCascades)
	local remainder = remaining % remainingCascades

	return baseCount + (if index - 1 <= remainder then 1 else 0)
end

local function resolveCascade(config: CascadeConfig): Cascade
	return {
		tileLength = readCascadeValue(config, "TileLength", DEFAULT_CASCADE.TileLength),
		displacementScale = readCascadeValue(config, "DisplacementScale", DEFAULT_CASCADE.DisplacementScale),
		normalScale = readCascadeValue(config, "NormalScale", DEFAULT_CASCADE.NormalScale),
		windSpeed = readCascadeValue(config, "WindSpeed", DEFAULT_CASCADE.WindSpeed),
		windDirection = readCascadeValue(config, "WindDirection", DEFAULT_CASCADE.WindDirection),
		fetchLength = readCascadeValue(config, "FetchLength", DEFAULT_CASCADE.FetchLength),
		swell = math.clamp(readCascadeValue(config, "Swell", DEFAULT_CASCADE.Swell), 0, 2),
		spread = math.clamp(readCascadeValue(config, "Spread", DEFAULT_CASCADE.Spread), 0, 1),
		detail = math.clamp(readCascadeValue(config, "Detail", DEFAULT_CASCADE.Detail), 0, 1),
		whitecap = math.clamp(readCascadeValue(config, "Whitecap", DEFAULT_CASCADE.Whitecap), 0, 2),
		foamAmount = math.clamp(readCascadeValue(config, "FoamAmount", DEFAULT_CASCADE.FoamAmount), 0, 10),
	}
end

local function bakeCascade(
	config: CascadeConfig,
	index: number,
	options: SpectrumOptions,
	componentCount: number,
	componentStart: number,
	componentBuffer: buffer,
	cascadeBuffer: buffer
): number
	local cascade = resolveCascade(config)

	buffer.writef32(cascadeBuffer, cascadeOffset(index - 1, CASCADE_COMPONENT_START), componentStart)
	buffer.writef32(cascadeBuffer, cascadeOffset(index - 1, CASCADE_COMPONENT_COUNT), componentCount)
	buffer.writef32(cascadeBuffer, cascadeOffset(index - 1, CASCADE_NORMAL_SCALE), cascade.normalScale)
	buffer.writef32(cascadeBuffer, cascadeOffset(index - 1, CASCADE_WHITECAP), cascade.whitecap)
	buffer.writef32(cascadeBuffer, cascadeOffset(index - 1, CASCADE_FOAM_AMOUNT), cascade.foamAmount)

	if componentCount <= 0 then
		return componentStart
	end

	local seed = readCascadeValue(config, "Seed", (options.Seed or 1234) + index * 101)
	local minTileLength = math.max(math.min(cascade.tileLength.X, cascade.tileLength.Y), 1)
	local minWavelength = math.max(2.5, minTileLength * 0.08)
	local maxWavelength = math.max(minWavelength + 0.1, minTileLength * 1.15)
	local windAngle = math.rad(cascade.windDirection)
	local angleWidth = mix(math.pi * 0.14, math.pi * 0.88, cascade.spread)
		+ (1 - math.clamp(cascade.swell, 0, 1)) * math.pi * 0.16
	local weightBuffer = buffer.create(componentCount * WEIGHT_BYTES)
	local totalWeight = 0

	for componentIndex = 0, componentCount - 1 do
		local t = (componentIndex + 0.5) / componentCount
		local jitter = hash01(seed, componentIndex + 1, 3)
		local wavelengthT = math.clamp(t ^ 1.35 + (jitter - 0.5) * 0.18, 0, 1)
		local wavelength = math.exp(mix(math.log(maxWavelength), math.log(minWavelength), wavelengthT))
		local k = TAU / wavelength
		local fan = if componentCount == 1 then 0 else ((componentIndex / (componentCount - 1)) * 2 - 1)
		local angleOffset = fan * angleWidth + (hash01(seed, componentIndex + 1, 4) - 0.5) * angleWidth * 0.22
		local angle = windAngle + angleOffset
		local directionX = math.cos(angle)
		local directionZ = math.sin(angle)
		local omega = dispersionRelation(k)
		local rawWeight = spectralAmplitude(k, angleOffset, cascade) * (0.68 + math.abs(gaussian(seed, componentIndex + 1)) * 0.32)

		if rawWeight <= EPSILON then
			rawWeight = (1 - t) * 0.36 + 0.06
		end

		buffer.writef32(weightBuffer, weightOffset(componentIndex, WEIGHT_DIRECTION_X), directionX)
		buffer.writef32(weightBuffer, weightOffset(componentIndex, WEIGHT_DIRECTION_Z), directionZ)
		buffer.writef32(weightBuffer, weightOffset(componentIndex, WEIGHT_K), k)
		buffer.writef32(weightBuffer, weightOffset(componentIndex, WEIGHT_OMEGA), omega)
		buffer.writef32(
			weightBuffer,
			weightOffset(componentIndex, WEIGHT_PHASE),
			TAU * hash01(seed, componentIndex + 1, 5) + omega * (120 + math.pi * (index - 1))
		)
		buffer.writef32(weightBuffer, weightOffset(componentIndex, WEIGHT_VALUE), rawWeight)

		totalWeight += rawWeight
	end

	local tileScale = math.clamp(((cascade.tileLength.X + cascade.tileLength.Y) * 0.5) / 50, 0.25, 2.8)
	local windScale = math.clamp(0.35 + cascade.windSpeed * 0.045, 0.35, 3)
	local targetAmplitude = (options.HeightScale or 1) * cascade.displacementScale * windScale * tileScale
	local steepness = math.clamp((options.Choppiness or 1) * (0.42 + cascade.swell * 0.13) * (1.05 - cascade.spread * 0.2), 0, 0.95)

	for componentIndex = 0, componentCount - 1 do
		local normalizedWeight = buffer.readf32(weightBuffer, weightOffset(componentIndex, WEIGHT_VALUE)) / math.max(totalWeight, EPSILON)
		local amplitude = targetAmplitude * normalizedWeight
		local k = buffer.readf32(weightBuffer, weightOffset(componentIndex, WEIGHT_K))
		local t = (componentIndex + 0.5) / componentCount
		local longWaveSoftness = mix(0.48, 0.82, t)
		local chop = math.min(amplitude * steepness * longWaveSoftness, 0.58 / math.max(k, EPSILON))
		local outputIndex = componentStart + componentIndex

		buffer.writef32(componentBuffer, componentOffset(outputIndex, COMPONENT_DIRECTION_X), buffer.readf32(weightBuffer, weightOffset(componentIndex, WEIGHT_DIRECTION_X)))
		buffer.writef32(componentBuffer, componentOffset(outputIndex, COMPONENT_DIRECTION_Z), buffer.readf32(weightBuffer, weightOffset(componentIndex, WEIGHT_DIRECTION_Z)))
		buffer.writef32(componentBuffer, componentOffset(outputIndex, COMPONENT_K), k)
		buffer.writef32(componentBuffer, componentOffset(outputIndex, COMPONENT_OMEGA), buffer.readf32(weightBuffer, weightOffset(componentIndex, WEIGHT_OMEGA)))
		buffer.writef32(componentBuffer, componentOffset(outputIndex, COMPONENT_AMPLITUDE), amplitude)
		buffer.writef32(componentBuffer, componentOffset(outputIndex, COMPONENT_CHOP), chop)
		buffer.writef32(componentBuffer, componentOffset(outputIndex, COMPONENT_PHASE), buffer.readf32(weightBuffer, weightOffset(componentIndex, WEIGHT_PHASE)))
	end

	return componentStart + componentCount
end

local function getCascadeWeight(
	cascadeIndex: number,
	cascadeWeights: { number }?,
	oceanWeight: number?,
	lakeWeight: number?,
	shallowWeight: number?
): number
	if cascadeWeights ~= nil then
		return math.clamp(cascadeWeights[cascadeIndex + 1] or 1, 0, 1)
	end

	if oceanWeight == nil then
		return 1
	end

	if cascadeIndex == 0 then
		return math.clamp(oceanWeight, 0, 1)
	elseif cascadeIndex == 1 then
		return math.clamp(lakeWeight or 0, 0, 1)
	elseif cascadeIndex == 2 then
		return math.clamp(shallowWeight or 0, 0, 1)
	end

	return 0
end

local function sampleSpectrum(
	self: WaveSpectrum,
	worldPosition: Vector3,
	time: number,
	detailFactor: number,
	cascadeWeights: { number }?,
	oceanWeight: number?,
	lakeWeight: number?,
	shallowWeight: number?
): WaveSample
	local detail = math.clamp(detailFactor, 0, 1)

	if detail <= 0 then
		return {
			displacement = Vector3.zero,
			height = 0,
			normal = Vector3.yAxis,
			foam = 0,
			foamAmount = 0,
			slope = 0,
		}
	end

	local x = worldPosition.X
	local z = worldPosition.Z
	local height = 0
	local horizontalX = 0
	local horizontalZ = 0
	local gradientX = 0
	local gradientZ = 0
	local foamImpulse = 0
	local foamAmount = 0
	local componentBuffer = self.ComponentBuffer
	local cascadeBuffer = self.CascadeBuffer

	for cascadeIndex = 0, self.CascadeCount - 1 do
		local cascadeWeight = getCascadeWeight(cascadeIndex, cascadeWeights, oceanWeight, lakeWeight, shallowWeight)

		if cascadeWeight <= 0.001 then
			continue
		end

		local componentStart = math.round(buffer.readf32(cascadeBuffer, cascadeOffset(cascadeIndex, CASCADE_COMPONENT_START)))
		local componentCount = math.round(buffer.readf32(cascadeBuffer, cascadeOffset(cascadeIndex, CASCADE_COMPONENT_COUNT)))
		local activeComponentCount = componentCount

		if detail < 0.999 then
			activeComponentCount = math.clamp(math.ceil(componentCount * detail), 1, componentCount)
		end

		local normalScale = buffer.readf32(cascadeBuffer, cascadeOffset(cascadeIndex, CASCADE_NORMAL_SCALE))
		local whitecap = buffer.readf32(cascadeBuffer, cascadeOffset(cascadeIndex, CASCADE_WHITECAP))
		local cascadeFoamAmount = buffer.readf32(cascadeBuffer, cascadeOffset(cascadeIndex, CASCADE_FOAM_AMOUNT))
		local componentCoverage = activeComponentCount / math.max(componentCount, 1)
		local dhyDx = 0
		local dhyDz = 0
		local dhxDx = 0
		local dhzDz = 0
		local dhzDx = 0

		for localIndex = 0, activeComponentCount - 1 do
			local componentIndex = componentStart + localIndex
			local directionX = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_DIRECTION_X))
			local directionZ = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_DIRECTION_Z))
			local k = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_K))
			local omega = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_OMEGA))
			local amplitude = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_AMPLITUDE)) * cascadeWeight
			local chop = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_CHOP)) * cascadeWeight
			local phase = (x * directionX + z * directionZ) * k
				- omega * time * self.TimeScale
				+ buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_PHASE))
			local sinPhase = math.sin(phase)
			local cosPhase = math.cos(phase)
			local roundedHeight = sinPhase * (0.88 + 0.12 * math.abs(sinPhase))
			local slope = cosPhase * amplitude * k * (0.88 + 0.24 * math.abs(sinPhase))
			local horizontalSlope = -sinPhase * chop * k

			height += roundedHeight * amplitude
			horizontalX += directionX * cosPhase * chop
			horizontalZ += directionZ * cosPhase * chop

			dhyDx += directionX * slope
			dhyDz += directionZ * slope
			dhxDx += directionX * directionX * horizontalSlope
			dhzDz += directionZ * directionZ * horizontalSlope
			dhzDx += directionX * directionZ * horizontalSlope
		end

		local jacobian = (1 + dhxDx) * (1 + dhzDz) - dhzDx * dhzDx
		foamImpulse += math.max(0, whitecap - jacobian)
		foamAmount += cascadeFoamAmount * componentCoverage * cascadeWeight

		gradientX += (dhyDx / (1 + math.abs(dhxDx))) * normalScale
		gradientZ += (dhyDz / (1 + math.abs(dhzDz))) * normalScale
	end

	local cascadeCount = math.max(self.CascadeCount, 1)
	local slope = math.sqrt(gradientX * gradientX + gradientZ * gradientZ)
	local normal = Vector3.new(-gradientX, 1, -gradientZ).Unit

	return {
		displacement = Vector3.new(horizontalX, height, horizontalZ),
		height = height,
		normal = normal,
		foam = math.clamp(foamImpulse / cascadeCount, 0, 1),
		foamAmount = foamAmount / cascadeCount,
		slope = slope,
	}
end

local function sampleSpectrumBakedWeighted3XZ(
	self: WaveSpectrum,
	x: number,
	z: number,
	time: number,
	detailFactor: number,
	oceanWeight: number,
	lakeWeight: number,
	shallowWeight: number
): (number, number, number, number)
	local detail = math.clamp(detailFactor, 0, 1)

	if detail <= 0 then
		return 0, 0, 0, 0
	end

	local height = 0
	local horizontalX = 0
	local horizontalZ = 0
	local foamImpulse = 0
	local componentBuffer = self.ComponentBuffer
	local cascadeBuffer = self.CascadeBuffer

	for cascadeIndex = 0, self.CascadeCount - 1 do
		local cascadeWeight = getCascadeWeight(cascadeIndex, nil, oceanWeight, lakeWeight, shallowWeight)

		if cascadeWeight <= 0.001 then
			continue
		end

		local componentStart = math.round(buffer.readf32(cascadeBuffer, cascadeOffset(cascadeIndex, CASCADE_COMPONENT_START)))
		local componentCount = math.round(buffer.readf32(cascadeBuffer, cascadeOffset(cascadeIndex, CASCADE_COMPONENT_COUNT)))
		local activeComponentCount = componentCount

		if detail < 0.999 then
			activeComponentCount = math.clamp(math.ceil(componentCount * detail), 1, componentCount)
		end

		local whitecap = buffer.readf32(cascadeBuffer, cascadeOffset(cascadeIndex, CASCADE_WHITECAP))
		local dhxDx = 0
		local dhzDz = 0
		local dhzDx = 0

		for localIndex = 0, activeComponentCount - 1 do
			local componentIndex = componentStart + localIndex
			local directionX = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_DIRECTION_X))
			local directionZ = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_DIRECTION_Z))
			local k = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_K))
			local omega = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_OMEGA))
			local amplitude = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_AMPLITUDE)) * cascadeWeight
			local chop = buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_CHOP)) * cascadeWeight
			local phase = (x * directionX + z * directionZ) * k
				- omega * time * self.TimeScale
				+ buffer.readf32(componentBuffer, componentOffset(componentIndex, COMPONENT_PHASE))
			local sinPhase = math.sin(phase)
			local cosPhase = math.cos(phase)
			local roundedHeight = sinPhase * (0.88 + 0.12 * math.abs(sinPhase))
			local horizontalSlope = -sinPhase * chop * k

			height += roundedHeight * amplitude
			horizontalX += directionX * cosPhase * chop
			horizontalZ += directionZ * cosPhase * chop

			dhxDx += directionX * directionX * horizontalSlope
			dhzDz += directionZ * directionZ * horizontalSlope
			dhzDx += directionX * directionZ * horizontalSlope
		end

		local jacobian = (1 + dhxDx) * (1 + dhzDz) - dhzDx * dhzDx
		foamImpulse += math.max(0, whitecap - jacobian)
	end

	return horizontalX, height, horizontalZ, math.clamp(foamImpulse / math.max(self.CascadeCount, 1), 0, 1)
end

function WaveSpectrumClass:Sample(worldPosition: Vector3, time: number): WaveSample
	return sampleSpectrum(self, worldPosition, time, 1, nil)
end

function WaveSpectrumClass:SampleLod(worldPosition: Vector3, time: number, detailFactor: number): WaveSample
	return sampleSpectrum(self, worldPosition, time, detailFactor, nil)
end

function WaveSpectrumClass:SampleWeighted(
	worldPosition: Vector3,
	time: number,
	detailFactor: number,
	cascadeWeights: { number }?
): WaveSample
	return sampleSpectrum(self, worldPosition, time, detailFactor, cascadeWeights)
end

function WaveSpectrumClass:SampleWeighted3(
	worldPosition: Vector3,
	time: number,
	detailFactor: number,
	oceanWeight: number,
	lakeWeight: number,
	shallowWeight: number
): WaveSample
	return sampleSpectrum(self, worldPosition, time, detailFactor, nil, oceanWeight, lakeWeight, shallowWeight)
end

function WaveSpectrumClass:SampleBakedWeighted3XZ(
	x: number,
	z: number,
	time: number,
	detailFactor: number,
	oceanWeight: number,
	lakeWeight: number,
	shallowWeight: number
): (number, number, number, number)
	return sampleSpectrumBakedWeighted3XZ(self, x, z, time, detailFactor, oceanWeight, lakeWeight, shallowWeight)
end

function WaveSpectrumClass:GetHeight(worldPosition: Vector3, time: number, steps: number?): number
	local iterationCount = steps or 3
	local originalXZ = Vector2.new(worldPosition.X, worldPosition.Z)
	local samplePosition = originalXZ
	local sample = self:Sample(worldPosition, time)

	for _ = 1, iterationCount do
		sample = self:Sample(Vector3.new(samplePosition.X, worldPosition.Y, samplePosition.Y), time)
		samplePosition = originalXZ - Vector2.new(sample.displacement.X, sample.displacement.Z)
	end

	return sample.height
end

local WaveSpectrum = {}

function WaveSpectrum.Bake(cascades: { CascadeConfig }?, options: SpectrumOptions?): BakedSpectrum
	local resolvedOptions = options or {}
	local resolvedCascades = cascades

	if resolvedCascades == nil or #resolvedCascades == 0 then
		resolvedCascades = { DEFAULT_CASCADE }
	end

	local cascadeCount = #resolvedCascades
	local componentCounts = table.create(cascadeCount)
	local totalComponentCount = 0

	for index = 1, cascadeCount do
		local componentCount = gerstnerCountForCascade(index, cascadeCount)
		componentCounts[index] = componentCount
		totalComponentCount += componentCount
	end

	local componentBuffer = buffer.create(math.max(totalComponentCount, 1) * COMPONENT_BYTES)
	local cascadeBuffer = buffer.create(math.max(cascadeCount, 1) * CASCADE_BYTES)
	local componentStart = 0

	for index, cascade in ipairs(resolvedCascades) do
		componentStart = bakeCascade(
			cascade,
			index,
			resolvedOptions,
			componentCounts[index],
			componentStart,
			componentBuffer,
			cascadeBuffer
		)
	end

	return {
		ComponentBuffer = componentBuffer,
		CascadeBuffer = cascadeBuffer,
		ComponentCount = totalComponentCount,
		CascadeCount = cascadeCount,
	}
end

function WaveSpectrum.fromBake(bake: BakedSpectrum, options: SpectrumOptions?): WaveSpectrum
	local resolvedOptions = options or {}

	return setmetatable({
		ComponentBuffer = bake.ComponentBuffer,
		CascadeBuffer = bake.CascadeBuffer,
		ComponentCount = bake.ComponentCount,
		CascadeCount = bake.CascadeCount,
		HeightScale = resolvedOptions.HeightScale or 1,
		Choppiness = resolvedOptions.Choppiness or 1,
		TimeScale = resolvedOptions.TimeScale or 1,
	}, WaveSpectrumClass) :: any
end

function WaveSpectrum.new(cascades: { CascadeConfig }?, options: SpectrumOptions?): WaveSpectrum
	return WaveSpectrum.fromBake(WaveSpectrum.Bake(cascades, options), options)
end

return WaveSpectrum
