--!strict

local WaterSurfaceColor = require(script.Parent.Parent.WaterSurfaceColor)
local WaterBuffer = require(script.Parent.Parent.WaterBuffer)

type InternalOceanTile = any

return function(deps: any)
	local SURFACE_IMAGE_PIXEL_BYTES = deps.SURFACE_IMAGE_PIXEL_BYTES
	local SURFACE_VERTEX_COLOR_BYTES = deps.SURFACE_VERTEX_COLOR_BYTES
	local BAKE_YIELD_CELL_BUDGET = deps.BAKE_YIELD_CELL_BUDGET
	local NORMAL_DETAIL_BAKE_VERSION = deps.NORMAL_DETAIL_BAKE_VERSION
	local smoothstep = deps.smoothstep
	local gridIndex = deps.gridIndex
	local getAxisCell = deps.getAxisCell
	local sampleValueNoise = deps.sampleValueNoise
	local sampleVoronoiEdge = deps.sampleVoronoiEdge
	local sampleWaterDepthAlpha = deps.sampleWaterDepthAlpha
	local sampleShoreFoamAlpha = deps.sampleShoreFoamAlpha
	local composeSurfaceSample = deps.composeSurfaceSample
	local resolveFoamOnlyAlpha = deps.resolveFoamOnlyAlpha
	local getWaveLoopKey = deps.getWaveLoopKey
	local hasCompleteWaveLoop = deps.hasCompleteWaveLoop
	local getWaveLoopReadyFrameCount = deps.getWaveLoopReadyFrameCount
	local getWaveLoopFrame = deps.getWaveLoopFrame
	local readWaveLoopHeightFrame = deps.readWaveLoopHeightFrame
	local sampleBakedHeight = deps.sampleBakedHeight
	local sampleBakedHeightAtTime = deps.sampleBakedHeightAtTime
	local usesPaintVertices = deps.usesPaintVertices
	local usesSurfaceAppearanceTexture = deps.usesSurfaceAppearanceTexture
	local usesWaterNormalMap = deps.usesWaterNormalMap
	local getSurfaceImageResolution = deps.getSurfaceImageResolution
	local getSurfaceNormalResolution = deps.getSurfaceNormalResolution
	local getSurfaceNormalFrameCount = deps.getSurfaceNormalFrameCount
	local ensureSurfaceVertexColors = deps.ensureSurfaceVertexColors
	local ensureSurfaceUVs = deps.ensureSurfaceUVs
	local ensureSurfaceAppearance = deps.ensureSurfaceAppearance
	local createSurfaceColorConfig = deps.createSurfaceColorConfig
	local resetSurfaceBake = deps.resetSurfaceBake
	local writeRenderSurfaceColor = deps.writeRenderSurfaceColor
	local queueSurfaceTexturePixels = deps.queueSurfaceTexturePixels
	local queueSurfaceNormalPixels = deps.queueSurfaceNormalPixels
	local usesFresnelAlpha = deps.usesFresnelAlpha
	local applyFresnelAlpha = deps.applyFresnelAlpha

	local function surfaceImagePixelOffset(resolution: number, x: number, y: number): number
		return (y * resolution + x) * SURFACE_IMAGE_PIXEL_BYTES
	end

	local function surfaceTextureFrameOffset(frameIndex: number, resolution: number): number
		return frameIndex * resolution * resolution * SURFACE_IMAGE_PIXEL_BYTES
	end

	local function surfaceVertexColorOffset(frameIndex: number, vertexIndex: number, vertexCount: number): number
		return (frameIndex * vertexCount + (vertexIndex - 1)) * SURFACE_VERTEX_COLOR_BYTES
	end

	local function writeColorPixel(pixels: buffer, offset: number, color: Color3, alpha: number)
		buffer.writeu8(pixels, offset, math.clamp(math.floor(color.R * 255 + 0.5), 0, 255))
		buffer.writeu8(pixels, offset + 1, math.clamp(math.floor(color.G * 255 + 0.5), 0, 255))
		buffer.writeu8(pixels, offset + 2, math.clamp(math.floor(color.B * 255 + 0.5), 0, 255))
		buffer.writeu8(pixels, offset + 3, math.clamp(math.floor(alpha * 255 + 0.5), 0, 255))
	end

	local function writeNormalPixel(pixels: buffer, offset: number, normalLocal: Vector3)
		local normal = if normalLocal.Magnitude > 0.001 then normalLocal.Unit else Vector3.yAxis
		local softened = Vector3.new(normal.X * 0.58, normal.Y + 0.18, normal.Z * 0.58)

		normal = if softened.Magnitude > 0.001 then softened.Unit else Vector3.yAxis

		buffer.writeu8(pixels, offset, math.clamp(math.floor((normal.X * 0.5 + 0.5) * 255 + 0.5), 0, 255))
		buffer.writeu8(pixels, offset + 1, math.clamp(math.floor((-normal.Z * 0.5 + 0.5) * 255 + 0.5), 0, 255))
		buffer.writeu8(pixels, offset + 2, math.clamp(math.floor((normal.Y * 0.5 + 0.5) * 255 + 0.5), 0, 255))
		buffer.writeu8(pixels, offset + 3, 255)
	end

	local function sampleWaterNormalDetailHeight(tile: InternalOceanTile, localX: number, localZ: number, time: number): number
		local config = tile._Config
		local scale = math.max(config.WaterNormalScale, 0.5)
		local loopDuration = math.max(tile._WaveLoopDuration, config.WaveLoopDuration, 0.25)
		local phase = ((time % loopDuration) / loopDuration) * math.pi * 2
		local speed = math.max(config.WaterNormalSpeed, 0)
		local seed = config.FoamNoiseSeed
		local driftX = (math.cos(phase) * 0.34 + math.sin(phase * 2.0) * 0.09) * scale * speed
		local driftZ = (math.sin(phase) * 0.34 + math.cos(phase * 1.7) * 0.09) * scale * speed
		local sampleX = localX + driftX
		local sampleZ = localZ + driftZ
		local warp = sampleValueNoise(sampleX, sampleZ, scale * 2.65, seed + 1201)
		local warpX = (warp - 0.5) * scale * 0.72 + math.cos(phase + warp * math.pi * 2) * scale * 0.08
		local warpZ = (0.5 - warp) * scale * 0.62 + math.sin(phase * 0.8 + warp * math.pi * 2) * scale * 0.08
		local broadA = sampleValueNoise(sampleX + warpX, sampleZ + warpZ, scale * 3.15, seed + 1217)
		local broadB = sampleValueNoise(sampleX * 0.86 - warpZ * 0.28, sampleZ * 0.92 + warpX * 0.24, scale * 1.72, seed + 1231)
		local cloud = sampleValueNoise(sampleX - warpX * 0.38, sampleZ + warpZ * 0.42, scale * 1.18, seed + 1249)
		local roundedCloud = smoothstep(0.14, 0.9, 1 - math.abs(cloud - 0.5) * 2)
		local softCells = sampleVoronoiEdge(
			sampleX + broadA * scale * 0.42,
			sampleZ - broadB * scale * 0.42,
			scale * 2.35,
			seed + 1261
		)
		local fineNoise = sampleValueNoise(sampleX + phase * 0.17, sampleZ - phase * 0.13, scale * 0.92, seed + 1277)
		local height = (broadA - 0.5) * 0.54
			+ (broadB - 0.5) * 0.3
			+ (roundedCloud - 0.5) * 0.26
			+ (smoothstep(0.26, 0.88, softCells) - 0.5) * 0.1
			+ (fineNoise - 0.5) * 0.08

		return height * scale * 0.011 * math.max(config.WaterNormalStrength, 0)
	end

	local function sampleSurfaceHeightForNormal(
		tile: InternalOceanTile,
		localX: number,
		localZ: number,
		time: number,
		waterBuffer: WaterBuffer.WaterBuffer?,
		detailGain: number
	): number
		local height = sampleBakedHeight(tile, localX, localZ, time)

		if waterBuffer ~= nil and waterBuffer:HasActivity() then
			height += waterBuffer:SampleHeight(localX, localZ)
		end

		if detailGain > 0 then
			height += sampleWaterNormalDetailHeight(tile, localX, localZ, time) * detailGain
		end

		return height
	end

	local function sampleSurfaceNormalLocal(
		tile: InternalOceanTile,
		localX: number,
		localZ: number,
		time: number,
		waterBuffer: WaterBuffer.WaterBuffer?,
		sampleDistance: number?,
		detailGain: number?
	): Vector3
		local size = tile.SourcePart.Size
		local distance = math.max(
			sampleDistance or math.max(tile._Config.VertexSpacing * 0.5, math.min(size.X, size.Z) / 128),
			0.25
		)
		local detail = detailGain or 0

		local function localHeight(x: number, z: number): number
			return sampleSurfaceHeightForNormal(tile, x, z, time, waterBuffer, detail)
		end

		local x0 = localX - distance
		local x1 = localX + distance
		local z0 = localZ - distance
		local z1 = localZ + distance
		local px0 = Vector3.new(x0, localHeight(x0, localZ), localZ)
		local px1 = Vector3.new(x1, localHeight(x1, localZ), localZ)
		local pz0 = Vector3.new(localX, localHeight(localX, z0), z0)
		local pz1 = Vector3.new(localX, localHeight(localX, z1), z1)
		local normalLocal = (pz1 - pz0):Cross(px1 - px0)

		if normalLocal.Magnitude <= 0.001 then
			return Vector3.yAxis
		end

		return normalLocal.Unit
	end

	local function sampleSurfaceFresnelAlpha(
		tile: InternalOceanTile,
		localPosition: Vector3,
		normalLocal: Vector3,
		cameraLocal: Vector3
	): number
		if not usesFresnelAlpha(tile._Config) then
			return 1
		end

		local viewDirection = cameraLocal - localPosition

		if viewDirection.Magnitude <= 0.001 or normalLocal.Magnitude <= 0.001 then
			return 1
		end

		local dot = math.abs(normalLocal.Unit:Dot(viewDirection.Unit))

		return math.clamp(1 - dot, 0, 1)
	end

	local function getDiscreteWaveLoopFrame(tile: InternalOceanTile, time: number, frameCount: number?): number
		local frames = math.max(frameCount or tile._WaveLoopFrames, 1)
		local framePosition = ((time % tile._WaveLoopDuration) / tile._WaveLoopDuration) * frames

		return math.floor(framePosition + 0.5) % frames
	end

	local function sampleBakedHeightFrame(
		tile: InternalOceanTile,
		heights: buffer,
		frameIndex: number,
		vertexCount: number,
		localX: number,
		localZ: number
	): number
		local resolutionX = tile._ResolutionX
		local resolutionZ = tile._ResolutionZ
		local x0, x1, tx = getAxisCell(tile._GridXCoordinates, resolutionX, localX)
		local z0, z1, tz = getAxisCell(tile._GridZCoordinates, resolutionZ, localZ)
		local d00 = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, gridIndex(resolutionX, x0, z0))
		local d10 = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, gridIndex(resolutionX, x1, z0))
		local d01 = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, gridIndex(resolutionX, x0, z1))
		local d11 = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, gridIndex(resolutionX, x1, z1))
		local a = d00 + (d10 - d00) * tx
		local b = d01 + (d11 - d01) * tx

		return a + (b - a) * tz
	end

	local function getSurfaceBakeKey(tile: InternalOceanTile): string
		local config = tile._Config

		return `{getWaveLoopKey(config)}:{config.SurfaceColorMode}:{config.WaterColorBack.R}:{config.WaterColorBack.G}:{config.WaterColorBack.B}:{config.WaterColorTop.R}:{config.WaterColorTop.G}:{config.WaterColorTop.B}:{config.WaterColorGain}:{config.WaterAlphaGain}:{config.WaterVertexAlpha}:{config.FoamColor.R}:{config.FoamColor.G}:{config.FoamColor.B}:{config.CrestFoamAlphaBack}:{config.CrestFoamAlphaTop}:{config.CrestFoamAlphaGain}:{config.WaveFoamAlphaBack}:{config.WaveFoamAlphaTop}:{config.WaveFoamAlphaGain}:{config.ShoreFoamStrength}:{config.FoamTrailStrength}:{config.FoamTrailLength}:{config.FoamTrailFeather}:{config.ShallowDepth}:{config.LakeDepth}:{config.OceanDepth}:{config.FoamNoiseInfluence}:{config.FoamNoiseSize}:{config.FoamNoiseSeed}:{config.FoamTextureStudsPerTile}:{config.CausticsEnabled}:{config.CausticsColor.R}:{config.CausticsColor.G}:{config.CausticsColor.B}:{config.CausticsStrength}:{config.ShallowCausticsStrength}:{config.DeepCausticsStrength}:{config.CausticsScale}:{config.CausticsSpeed}:{config.CausticsDepthFade}:{config.CausticsVoronoiStrength}:{getSurfaceImageResolution(config)}:{#tile._Vertices}:{tile._WaveLoopMinHeight}:{tile._WaveLoopMaxHeight}`
	end

	local function writeBakedVertexFrameColor(
		tile: InternalOceanTile,
		colors: buffer,
		surfaceColorConfig: WaterSurfaceColor.SurfaceColorConfig,
		heights: buffer,
		frameIndex: number,
		vertexIndex: number,
		vertexCount: number,
		includeFoam: boolean
	)
		local vertex = tile._Vertices[vertexIndex]

		if vertex == nil then
			return
		end

		local foamTime = (frameIndex / math.max(tile._WaveLoopFrames, 1)) * tile._WaveLoopDuration
		local localX = vertex.baseLocal.X
		local localZ = vertex.baseLocal.Z
		local height = readWaveLoopHeightFrame(heights, frameIndex, vertexCount, vertexIndex)
		local normalizedHeight = WaterSurfaceColor.NormalizeHeight(height, tile._WaveLoopMinHeight, tile._WaveLoopMaxHeight)
		local depthAlpha = sampleWaterDepthAlpha(tile, localX, localZ)
		local offset = surfaceVertexColorOffset(frameIndex, vertexIndex, vertexCount)

		if includeFoam then
			local shoreFoamAlpha = sampleShoreFoamAlpha(tile, localX, localZ, foamTime)
			local sample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
			local finalColor, finalAlpha = composeSurfaceSample(tile, sample, depthAlpha, localX, localZ, foamTime)

			writeColorPixel(colors, offset, finalColor, finalAlpha)
		else
			local waterSample = WaterSurfaceColor.SampleWater(surfaceColorConfig, normalizedHeight, depthAlpha)

			writeColorPixel(colors, offset, waterSample.Color, waterSample.Alpha)
		end
	end

	local function writeBakedTextureFramePixel(
		tile: InternalOceanTile,
		pixels: buffer,
		surfaceColorConfig: WaterSurfaceColor.SurfaceColorConfig,
		heights: buffer,
		frameIndex: number,
		vertexCount: number,
		resolution: number,
		x: number,
		y: number,
		foamOnly: boolean
	)
		local size = tile.SourcePart.Size
		local u = if resolution > 1 then x / (resolution - 1) else 0
		local v = if resolution > 1 then y / (resolution - 1) else 0
		local localX = (u - 0.5) * size.X
		local localZ = (0.5 - v) * size.Z
		local height = sampleBakedHeightFrame(tile, heights, frameIndex, vertexCount, localX, localZ)
		local foamTime = (frameIndex / math.max(tile._WaveLoopFrames, 1)) * tile._WaveLoopDuration
		local normalizedHeight = WaterSurfaceColor.NormalizeHeight(height, tile._WaveLoopMinHeight, tile._WaveLoopMaxHeight)
		local depthAlpha = sampleWaterDepthAlpha(tile, localX, localZ)
		local offset = surfaceTextureFrameOffset(frameIndex, resolution) + surfaceImagePixelOffset(resolution, x, y)
		local shoreFoamAlpha = sampleShoreFoamAlpha(tile, localX, localZ, foamTime)

		if foamOnly then
			local sample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
			local foamAlpha = resolveFoamOnlyAlpha(tile, sample, depthAlpha, localX, localZ, foamTime)

			writeColorPixel(pixels, offset, sample.FoamColor, foamAlpha)
		else
			local sample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
			local finalColor, finalAlpha = composeSurfaceSample(tile, sample, depthAlpha, localX, localZ, foamTime)

			writeColorPixel(pixels, offset, finalColor, finalAlpha)
		end
	end

	local function getSurfaceNormalBakeKey(tile: InternalOceanTile): string
		local config = tile._Config

		return `{NORMAL_DETAIL_BAKE_VERSION}:{getWaveLoopKey(config)}:{config.WaterNormalResolution}:{config.WaterNormalStrength}:{config.WaterNormalScale}:{config.WaterNormalSpeed}:{config.WaterNormalUpdateInterval}:{getSurfaceNormalFrameCount(config)}:{getSurfaceNormalResolution(config)}:{#tile._Vertices}:{tile.SourcePart.Size.X}:{tile.SourcePart.Size.Z}`
	end

	local function sampleBakedSurfaceNormalLocal(
		tile: InternalOceanTile,
		heights: buffer,
		localX: number,
		localZ: number,
		time: number,
		sampleDistance: number
	): Vector3
		local function localHeight(x: number, z: number): number
			return sampleBakedHeightAtTime(tile, heights, x, z, time)
				+ sampleWaterNormalDetailHeight(tile, x, z, time)
		end

		local x0 = localX - sampleDistance
		local x1 = localX + sampleDistance
		local z0 = localZ - sampleDistance
		local z1 = localZ + sampleDistance
		local px0 = Vector3.new(x0, localHeight(x0, localZ), localZ)
		local px1 = Vector3.new(x1, localHeight(x1, localZ), localZ)
		local pz0 = Vector3.new(localX, localHeight(localX, z0), z0)
		local pz1 = Vector3.new(localX, localHeight(localX, z1), z1)
		local normalLocal = (pz1 - pz0):Cross(px1 - px0)

		if normalLocal.Magnitude <= 0.001 then
			return Vector3.yAxis
		end

		return normalLocal.Unit
	end

	local function writeBakedNormalFramePixel(
		tile: InternalOceanTile,
		pixels: buffer,
		heights: buffer,
		frameIndex: number,
		frameCount: number,
		resolution: number,
		x: number,
		y: number,
		sampleDistance: number
	)
		local size = tile.SourcePart.Size
		local u = if resolution > 1 then x / (resolution - 1) else 0
		local v = if resolution > 1 then y / (resolution - 1) else 0
		local localX = (u - 0.5) * size.X
		local localZ = (0.5 - v) * size.Z
		local frameTime = (frameIndex / math.max(frameCount, 1)) * tile._WaveLoopDuration
		local normalLocal = sampleBakedSurfaceNormalLocal(tile, heights, localX, localZ, frameTime, sampleDistance)
		local offset = surfaceTextureFrameOffset(frameIndex, resolution) + surfaceImagePixelOffset(resolution, x, y)

		writeNormalPixel(pixels, offset, normalLocal)
	end

	local function isSurfaceBakeCurrent(
		tile: InternalOceanTile,
		bakeId: number,
		key: string,
		heights: buffer
	): boolean
		return not tile._Destroyed
			and tile._SurfaceBakeId == bakeId
			and tile._SurfaceBakeKey == key
			and tile._WaveLoopHeights == heights
	end

	local function isSurfaceNormalBakeCurrent(
		tile: InternalOceanTile,
		bakeId: number,
		key: string,
		heights: buffer
	): boolean
		return not tile._Destroyed
			and tile._SurfaceNormalBakeId == bakeId
			and tile._SurfaceNormalBakeKey == key
			and tile._WaveLoopHeights == heights
	end

	local function bakeSurfaceNormalFrames(tile: InternalOceanTile, key: string, bakeId: number): boolean
		local heights = tile._WaveLoopHeights

		if heights == nil then
			return false
		end

		local config = tile._Config
		local frames = getSurfaceNormalFrameCount(config)
		local resolution = getSurfaceNormalResolution(config)
		local pixels = buffer.create(resolution * resolution * frames * SURFACE_IMAGE_PIXEL_BYTES)
		local size = tile.SourcePart.Size
		local stepX = size.X / math.max(resolution - 1, 1)
		local stepZ = size.Z / math.max(resolution - 1, 1)
		local sampleDistance = math.max(math.min(stepX, stepZ) * 0.65, 0.25)
		local processedSinceYield = 0

		if not isSurfaceNormalBakeCurrent(tile, bakeId, key, heights) then
			return false
		end

		tile._SurfaceNormalFramePixels = pixels
		tile._SurfaceNormalFrameCount = 0
		tile._SurfaceNormalFrameResolution = resolution
		tile._SurfaceNormalRuntimePixels = nil
		tile._SurfaceNormalLastFrameIndex = -1
		tile._SurfaceNormalBakeKey = key

		for frameIndex = 0, frames - 1 do
			if not isSurfaceNormalBakeCurrent(tile, bakeId, key, heights) then
				return false
			end

			for y = 0, resolution - 1 do
				for x = 0, resolution - 1 do
					writeBakedNormalFramePixel(
						tile,
						pixels,
						heights,
						frameIndex,
						frames,
						resolution,
						x,
						y,
						sampleDistance
					)

					processedSinceYield += 1

					if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
						processedSinceYield = 0
						task.wait()

						if not isSurfaceNormalBakeCurrent(tile, bakeId, key, heights) then
							return false
						end
					end
				end
			end

			tile._SurfaceNormalFrameCount = frameIndex + 1
			tile._SurfaceNormalLastFrameIndex = -1

			if frameIndex < frames - 1 then
				processedSinceYield = 0
				task.wait()

				if not isSurfaceNormalBakeCurrent(tile, bakeId, key, heights) then
					return false
				end
			end
		end

		return true
	end

	local function bakeSurfaceFrames(tile: InternalOceanTile, key: string, bakeId: number): boolean
		local heights = tile._WaveLoopHeights

		if heights == nil then
			return false
		end

		local config = tile._Config
		local frames = math.max(tile._WaveLoopFrames, 1)
		local vertexCount = #tile._Vertices
		local surfaceColorConfig = createSurfaceColorConfig(config)
		local bakeVertexColors = usesPaintVertices(config)
		local bakeTexture = usesSurfaceAppearanceTexture(config)
		local vertexColors = if bakeVertexColors
			then buffer.create(vertexCount * frames * SURFACE_VERTEX_COLOR_BYTES)
			else nil
		local resolution = if bakeTexture then getSurfaceImageResolution(config) else 0
		local texturePixels = if bakeTexture
			then buffer.create(resolution * resolution * frames * SURFACE_IMAGE_PIXEL_BYTES)
			else nil
		local includeVertexFoam = config.SurfaceColorMode == "PaintVertices"
		local textureFoamOnly = config.SurfaceColorMode == "FoamSurfaceAppearance"
		local processedSinceYield = 0

		if not isSurfaceBakeCurrent(tile, bakeId, key, heights) then
			return false
		end

		tile._SurfaceVertexFrameColors = vertexColors
		tile._SurfaceVertexFrameCount = 0
		tile._SurfaceVertexLastFrameIndex = -1
		tile._SurfaceTextureFramePixels = texturePixels
		tile._SurfaceTextureFrameCount = 0
		tile._SurfaceTextureFrameResolution = resolution
		tile._SurfaceTextureRuntimePixels = nil
		tile._SurfaceTextureLastFrameIndex = -1
		tile._SurfaceBakeKey = key

		for frameIndex = 0, frames - 1 do
			if not isSurfaceBakeCurrent(tile, bakeId, key, heights) then
				return false
			end

			if vertexColors ~= nil then
				for vertexIndex = 1, vertexCount do
					writeBakedVertexFrameColor(
						tile,
						vertexColors,
						surfaceColorConfig,
						heights,
						frameIndex,
						vertexIndex,
						vertexCount,
						includeVertexFoam
					)

					processedSinceYield += 1

					if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
						processedSinceYield = 0
						task.wait()

						if not isSurfaceBakeCurrent(tile, bakeId, key, heights) then
							return false
						end
					end
				end
			end

			if texturePixels ~= nil then
				for y = 0, resolution - 1 do
					for x = 0, resolution - 1 do
						writeBakedTextureFramePixel(
							tile,
							texturePixels,
							surfaceColorConfig,
							heights,
							frameIndex,
							vertexCount,
							resolution,
							x,
							y,
							textureFoamOnly
						)

						processedSinceYield += 1

						if processedSinceYield >= BAKE_YIELD_CELL_BUDGET then
							processedSinceYield = 0
							task.wait()

							if not isSurfaceBakeCurrent(tile, bakeId, key, heights) then
								return false
							end
						end
					end
				end
			end

			local readyFrameCount = frameIndex + 1

			if vertexColors ~= nil then
				tile._SurfaceVertexFrameCount = readyFrameCount
				tile._SurfaceVertexLastFrameIndex = -1
			end

			if texturePixels ~= nil then
				tile._SurfaceTextureFrameCount = readyFrameCount
				tile._SurfaceTextureLastFrameIndex = -1
			end

			if frameIndex < frames - 1 then
				processedSinceYield = 0
				task.wait()

				if not isSurfaceBakeCurrent(tile, bakeId, key, heights) then
					return false
				end
			end
		end

		return true
	end

	local function ensureSurfaceFrameBake(tile: InternalOceanTile): boolean
		local config = tile._Config

		if not config.SurfaceColorBake then
			return false
		end

		if not usesPaintVertices(config) and not usesSurfaceAppearanceTexture(config) then
			return false
		end

		if tile._WaveLoopHeights == nil then
			return false
		end

		if not hasCompleteWaveLoop(tile, getWaveLoopKey(config)) then
			return false
		end

		local key = getSurfaceBakeKey(tile)
		local needsVertexColors = usesPaintVertices(config)
		local needsTexture = usesSurfaceAppearanceTexture(config)
		local hasVertexColors = not needsVertexColors or tile._SurfaceVertexFrameColors ~= nil
		local hasTexture = not needsTexture
			or (
				tile._SurfaceTextureFramePixels ~= nil
				and tile._SurfaceTextureFrameResolution == getSurfaceImageResolution(config)
			)
		local hasReadyVertexColors = not needsVertexColors or tile._SurfaceVertexFrameCount > 0
		local hasReadyTexture = not needsTexture or tile._SurfaceTextureFrameCount > 0
		local targetFrames = math.max(tile._WaveLoopFrames, 1)
		local hasCompleteVertexColors = not needsVertexColors or tile._SurfaceVertexFrameCount >= targetFrames
		local hasCompleteTexture = not needsTexture or tile._SurfaceTextureFrameCount >= targetFrames

		if
			tile._SurfaceBakeKey == key
			and hasVertexColors
			and hasTexture
			and hasReadyVertexColors
			and hasReadyTexture
			and (tile._SurfaceBakeBaking or (hasCompleteVertexColors and hasCompleteTexture))
		then
			return true
		end

		if tile._SurfaceBakeBaking then
			return false
		end

		if needsVertexColors and not ensureSurfaceVertexColors(tile) then
			return false
		end

		if needsTexture and (not ensureSurfaceUVs(tile) or not ensureSurfaceAppearance(tile)) then
			return false
		end

		tile._SurfaceBakeId += 1
		local bakeId = tile._SurfaceBakeId
		tile._SurfaceBakeKey = key
		tile._SurfaceBakeBaking = true

		task.spawn(function()
			local baked = false
			local ok, err = pcall(function()
				baked = bakeSurfaceFrames(tile, key, bakeId)
			end)

			if tile._SurfaceBakeId ~= bakeId then
				return
			end

			tile._SurfaceBakeBaking = false

			if not ok then
				resetSurfaceBake(tile)
				warn("[WaterSystem] Surface RGBA bake failed: " .. tostring(err))
			elseif not baked and not tile._Destroyed and tile._SurfaceBakeKey == key then
				tile._SurfaceVertexFrameCount = math.clamp(tile._SurfaceVertexFrameCount, 0, targetFrames)
				tile._SurfaceTextureFrameCount = math.clamp(tile._SurfaceTextureFrameCount, 0, targetFrames)
			end
		end)

		return false
	end

	local function applyBakedSurfaceVertexColors(
		tile: InternalOceanTile,
		time: number,
		cameraLocal: Vector3,
		waterBuffer: WaterBuffer.WaterBuffer?
	): boolean
		local colors = tile._SurfaceVertexFrameColors

		if colors == nil or tile._SurfaceVertexFrameCount <= 0 then
			return false
		end

		if not ensureSurfaceVertexColors(tile) then
			return false
		end

		local frameIndex = getDiscreteWaveLoopFrame(tile, time, tile._SurfaceVertexFrameCount)

		if tile._SurfaceVertexLastFrameIndex == frameIndex and not usesFresnelAlpha(tile._Config) then
			return true
		end

		local vertexCount = #tile._Vertices

		for vertexIndex in ipairs(tile._SurfaceColorIds) do
			local vertex = tile._Vertices[vertexIndex]
			local offset = surfaceVertexColorOffset(frameIndex, vertexIndex, vertexCount)
			local r = buffer.readu8(colors, offset)
			local g = buffer.readu8(colors, offset + 1)
			local b = buffer.readu8(colors, offset + 2)
			local a = buffer.readu8(colors, offset + 3) / 255
			local finalAlpha = a

			if vertex ~= nil and vertex.surfaceEnabled and usesFresnelAlpha(tile._Config) then
				local baseLocal = vertex.baseLocal
				local height = sampleSurfaceHeightForNormal(tile, baseLocal.X, baseLocal.Z, time, waterBuffer, 0.18)
				local normalLocal = sampleSurfaceNormalLocal(tile, baseLocal.X, baseLocal.Z, time, waterBuffer, nil, 0.18)
				local fresnelAlpha = sampleSurfaceFresnelAlpha(
					tile,
					Vector3.new(baseLocal.X, height, baseLocal.Z),
					normalLocal,
					cameraLocal
				)

				finalAlpha = applyFresnelAlpha(tile._Config, a, fresnelAlpha)
			end

			writeRenderSurfaceColor(tile, vertexIndex, Color3.fromRGB(r, g, b), finalAlpha)
		end

		tile._SurfaceVertexLastFrameIndex = frameIndex
		return true
	end

	local function applyBakedSurfaceAppearanceTexture(tile: InternalOceanTile, time: number): boolean
		if not ensureSurfaceAppearance(tile) then
			return false
		end

		local image = tile._SurfaceImage
		local frames = tile._SurfaceTextureFramePixels

		if image == nil or frames == nil or tile._SurfaceTextureFrameCount <= 0 then
			return false
		end

		local resolution = tile._SurfaceTextureFrameResolution
		local frameIndex = getDiscreteWaveLoopFrame(tile, time, tile._SurfaceTextureFrameCount)

		if tile._SurfaceTextureLastFrameIndex == frameIndex then
			return true
		end

		local frameBytes = resolution * resolution * SURFACE_IMAGE_PIXEL_BYTES

		if tile._SurfaceTextureRuntimePixels == nil then
			tile._SurfaceTextureRuntimePixels = buffer.create(frameBytes)
		end

		local pixels = tile._SurfaceTextureRuntimePixels

		if pixels == nil then
			return false
		end

		buffer.copy(pixels, 0, frames, surfaceTextureFrameOffset(frameIndex, resolution), frameBytes)
		queueSurfaceTexturePixels(tile, pixels, resolution)

		tile._SurfaceTextureLastFrameIndex = frameIndex
		tile._SurfaceTextureLastUpdateTime = time
		return true
	end

	local function updateSurfaceAppearanceTexture(tile: InternalOceanTile, time: number, waterBuffer: WaterBuffer.WaterBuffer?)
		if not ensureSurfaceAppearance(tile) then
			return
		end

		local image = tile._SurfaceImage

		if image == nil then
			return
		end

		local interval = math.max(tile._Config.FoamTextureUpdateInterval, 0)

		if interval > 0 and time - tile._SurfaceTextureLastUpdateTime < interval then
			return
		end

		tile._SurfaceTextureLastUpdateTime = time

		local resolution = math.max(tile._SurfaceImageResolution, 1)
		local pixels = buffer.create(resolution * resolution * SURFACE_IMAGE_PIXEL_BYTES)
		local size = tile.SourcePart.Size
		local surfaceColorConfig = createSurfaceColorConfig(tile._Config)
		local foamOnly = tile._Config.SurfaceColorMode == "FoamSurfaceAppearance"

		for y = 0, resolution - 1 do
			local v = if resolution > 1 then y / (resolution - 1) else 0
			local localZ = (0.5 - v) * size.Z

			for x = 0, resolution - 1 do
				local u = if resolution > 1 then x / (resolution - 1) else 0
				local localX = (u - 0.5) * size.X
				local height = sampleBakedHeight(tile, localX, localZ, time)

				if not tile._Config.SurfaceColorBake and waterBuffer ~= nil and waterBuffer:HasActivity() then
					height += waterBuffer:SampleHeight(localX, localZ)
				end

				local normalizedHeight = WaterSurfaceColor.NormalizeHeight(
					height,
					tile._WaveLoopMinHeight,
					tile._WaveLoopMaxHeight
				)
				local depthAlpha = sampleWaterDepthAlpha(tile, localX, localZ)
				local offset = surfaceImagePixelOffset(resolution, x, y)
				local shoreFoamAlpha = sampleShoreFoamAlpha(tile, localX, localZ, time)

				if foamOnly then
					local sample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
					local foamAlpha = resolveFoamOnlyAlpha(tile, sample, depthAlpha, localX, localZ, time)

					writeColorPixel(pixels, offset, sample.FoamColor, foamAlpha)
				else
					local sample = WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
					local finalColor, finalAlpha = composeSurfaceSample(tile, sample, depthAlpha, localX, localZ, time)

					writeColorPixel(pixels, offset, finalColor, finalAlpha)
				end
			end
		end

		queueSurfaceTexturePixels(tile, pixels, resolution)
	end

	local function ensureSurfaceNormalFrameBake(tile: InternalOceanTile): boolean
		if not usesWaterNormalMap(tile._Config) or not tile._SurfaceNormalSupported then
			return false
		end

		if not ensureSurfaceUVs(tile) or not ensureSurfaceAppearance(tile) then
			return false
		end

		if tile._WaveLoopHeights == nil then
			return false
		end

		if not hasCompleteWaveLoop(tile, getWaveLoopKey(tile._Config)) then
			return false
		end

		local key = getSurfaceNormalBakeKey(tile)
		local hasNormalFrames = tile._SurfaceNormalFramePixels ~= nil
			and tile._SurfaceNormalFrameResolution == getSurfaceNormalResolution(tile._Config)
			and tile._SurfaceNormalFrameCount > 0
		local targetFrames = getSurfaceNormalFrameCount(tile._Config)

		if
			tile._SurfaceNormalBakeKey == key
			and hasNormalFrames
			and (tile._SurfaceNormalBakeBaking or tile._SurfaceNormalFrameCount >= targetFrames)
		then
			return true
		end

		if tile._SurfaceNormalBakeBaking then
			return false
		end

		tile._SurfaceNormalBakeId += 1
		local bakeId = tile._SurfaceNormalBakeId
		tile._SurfaceNormalBakeKey = key
		tile._SurfaceNormalBakeBaking = true

		task.spawn(function()
			local baked = false
			local ok, err = pcall(function()
				baked = bakeSurfaceNormalFrames(tile, key, bakeId)
			end)

			if tile._SurfaceNormalBakeId ~= bakeId then
				return
			end

			tile._SurfaceNormalBakeBaking = false

			if not ok then
				tile._SurfaceNormalBakeId += 1
				tile._SurfaceNormalFramePixels = nil
				tile._SurfaceNormalFrameCount = 0
				tile._SurfaceNormalFrameResolution = 0
				tile._SurfaceNormalRuntimePixels = nil
				tile._SurfaceNormalLastFrameIndex = -1
				tile._SurfaceNormalBakeKey = ""
				warn("[WaterSystem] Surface normal RGB bake failed: " .. tostring(err))
			elseif not baked and not tile._Destroyed and tile._SurfaceNormalBakeKey == key then
				tile._SurfaceNormalFrameCount = math.clamp(tile._SurfaceNormalFrameCount, 0, targetFrames)
			end
		end)

		return false
	end

	local function getSurfaceNormalFrame(tile: InternalOceanTile, time: number): number
		local frames = math.max(tile._SurfaceNormalFrameCount, 1)
		local framePosition = ((time % tile._WaveLoopDuration) / tile._WaveLoopDuration) * frames

		return math.floor(framePosition + 0.5) % frames
	end

	local function applyBakedSurfaceNormalMap(tile: InternalOceanTile, time: number): boolean
		if not ensureSurfaceNormalFrameBake(tile) then
			return false
		end

		local image = tile._SurfaceNormalImage
		local frames = tile._SurfaceNormalFramePixels

		if image == nil or frames == nil or tile._SurfaceNormalFrameCount <= 0 then
			return false
		end

		local resolution = tile._SurfaceNormalFrameResolution
		local frameIndex = getSurfaceNormalFrame(tile, time)

		if tile._SurfaceNormalLastFrameIndex == frameIndex then
			return true
		end

		local frameBytes = resolution * resolution * SURFACE_IMAGE_PIXEL_BYTES

		if tile._SurfaceNormalRuntimePixels == nil then
			tile._SurfaceNormalRuntimePixels = buffer.create(frameBytes)
		end

		local pixels = tile._SurfaceNormalRuntimePixels

		if pixels == nil then
			return false
		end

		buffer.copy(pixels, 0, frames, surfaceTextureFrameOffset(frameIndex, resolution), frameBytes)
		queueSurfaceNormalPixels(tile, pixels, resolution)

		tile._SurfaceNormalLastFrameIndex = frameIndex
		tile._SurfaceNormalLastUpdateTime = time
		return true
	end


	return {
		surfaceImagePixelOffset = surfaceImagePixelOffset,
		surfaceTextureFrameOffset = surfaceTextureFrameOffset,
		surfaceVertexColorOffset = surfaceVertexColorOffset,
		writeColorPixel = writeColorPixel,
		writeNormalPixel = writeNormalPixel,
		sampleWaterNormalDetailHeight = sampleWaterNormalDetailHeight,
		sampleSurfaceHeightForNormal = sampleSurfaceHeightForNormal,
		sampleSurfaceNormalLocal = sampleSurfaceNormalLocal,
		sampleSurfaceFresnelAlpha = sampleSurfaceFresnelAlpha,
		getDiscreteWaveLoopFrame = getDiscreteWaveLoopFrame,
		sampleBakedHeightFrame = sampleBakedHeightFrame,
		getSurfaceBakeKey = getSurfaceBakeKey,
		writeBakedVertexFrameColor = writeBakedVertexFrameColor,
		writeBakedTextureFramePixel = writeBakedTextureFramePixel,
		getSurfaceNormalBakeKey = getSurfaceNormalBakeKey,
		sampleBakedSurfaceNormalLocal = sampleBakedSurfaceNormalLocal,
		writeBakedNormalFramePixel = writeBakedNormalFramePixel,
		isSurfaceBakeCurrent = isSurfaceBakeCurrent,
		isSurfaceNormalBakeCurrent = isSurfaceNormalBakeCurrent,
		bakeSurfaceNormalFrames = bakeSurfaceNormalFrames,
		bakeSurfaceFrames = bakeSurfaceFrames,
		ensureSurfaceFrameBake = ensureSurfaceFrameBake,
		applyBakedSurfaceVertexColors = applyBakedSurfaceVertexColors,
		applyBakedSurfaceAppearanceTexture = applyBakedSurfaceAppearanceTexture,
		updateSurfaceAppearanceTexture = updateSurfaceAppearanceTexture,
		ensureSurfaceNormalFrameBake = ensureSurfaceNormalFrameBake,
		getSurfaceNormalFrame = getSurfaceNormalFrame,
		applyBakedSurfaceNormalMap = applyBakedSurfaceNormalMap,
	}
end
