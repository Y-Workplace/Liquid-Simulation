--!strict

local WaterSurfaceColor = require(script.Parent.Parent.WaterSurfaceColor)
local WaterDepthMap = require(script.Parent.Parent.WaterDepthMap)
local WaterObstacleMap = require(script.Parent.Parent.WaterObstacleMap)

type TileConfig = any
type InternalOceanTile = any

return function(deps: any)
	local smoothstep = deps.smoothstep
	local lerpNumber = deps.lerpNumber
	local lerpColor = deps.lerpColor
	local hashNoise = deps.hashNoise

	local sampleFoamBreakup: (InternalOceanTile, number, number) -> number
	local sampleShoreFoamAlpha: (InternalOceanTile, number, number, number?) -> number = function(_tile, _localX, _localZ, _foamTime)
		return 0
	end
	local composeSurfaceSample: (
		InternalOceanTile,
		WaterSurfaceColor.SurfaceSample,
		number,
		number,
		number,
		number?
	) -> (Color3, number) = function(_tile, sample, _depthAlpha, _localX, _localZ, _foamTime)
		return sample.FinalColor, sample.FinalAlpha
	end

	local function sampleDepth(depthMap: WaterDepthMap.WaterDepthMap?, config: TileConfig, localX: number, localZ: number): number
		if depthMap == nil then
			return config.FallbackDepth
		end

		return depthMap:SampleDepth(localX, localZ)
	end

	local function sampleWaterDepthAlpha(tile: InternalOceanTile, localX: number, localZ: number): number
		local config = tile._Config
		local oceanDepth = math.max(config.OceanDepth, math.max(config.LakeDepth, config.ShallowDepth + 0.001) + 0.001)
		local depth = sampleDepth(tile._DepthMap, config, localX, localZ)

		return smoothstep(config.ShallowDepth, oceanDepth, depth)
	end

	local function sampleDepthWeights(tile: InternalOceanTile, localX: number, localZ: number): (number, number, number, number)
		local config = tile._Config
		local depth = sampleDepth(tile._DepthMap, config, localX, localZ)
		local lakeDepth = math.max(config.LakeDepth, config.ShallowDepth + 0.001)
		local oceanDepth = math.max(config.OceanDepth, lakeDepth + 0.001)
		local shallowToLake = smoothstep(config.ShallowDepth, lakeDepth, depth)
		local lakeToOcean = smoothstep(lakeDepth, oceanDepth, depth)
		local shallowWeight = 1 - shallowToLake
		local oceanWeight = lakeToOcean
		local lakeWeight = shallowToLake * (1 - lakeToOcean)

		return depth, oceanWeight, lakeWeight, shallowWeight
	end

	local function sampleDepthGradient(tile: InternalOceanTile, localX: number, localZ: number): Vector2
		local depthMap = tile._DepthMap

		if depthMap == nil then
			return Vector2.zero
		end

		local cellSize = math.max(math.min(depthMap.SizeX, depthMap.SizeZ) / math.max(depthMap.Resolution, 1), 1)
		local step = math.max(tile._Config.VertexSpacing * 3, cellSize * 0.65, 1)
		local config = tile._Config
		local dx = sampleDepth(depthMap, config, localX + step, localZ)
			- sampleDepth(depthMap, config, localX - step, localZ)
		local dz = sampleDepth(depthMap, config, localX, localZ + step)
			- sampleDepth(depthMap, config, localX, localZ - step)
		local diagonalWeight = 0.5

		dx += (
			sampleDepth(depthMap, config, localX + step, localZ + step)
			+ sampleDepth(depthMap, config, localX + step, localZ - step)
			- sampleDepth(depthMap, config, localX - step, localZ + step)
			- sampleDepth(depthMap, config, localX - step, localZ - step)
		) * diagonalWeight
		dz += (
			sampleDepth(depthMap, config, localX + step, localZ + step)
			+ sampleDepth(depthMap, config, localX - step, localZ + step)
			- sampleDepth(depthMap, config, localX + step, localZ - step)
			- sampleDepth(depthMap, config, localX - step, localZ - step)
		) * diagonalWeight

		local gradient = Vector2.new(dx, dz)

		if gradient.Magnitude <= 1e-4 then
			return Vector2.zero
		end

		return gradient / math.max(step * 3, 1)
	end

	local function sampleValueNoise(localX: number, localZ: number, scale: number, seed: number): number
		local sampleX = localX / math.max(scale, 0.001)
		local sampleZ = localZ / math.max(scale, 0.001)
		local x0 = math.floor(sampleX)
		local z0 = math.floor(sampleZ)
		local tx = smoothstep(0, 1, sampleX - x0)
		local tz = smoothstep(0, 1, sampleZ - z0)
		local n00 = hashNoise(x0, z0, seed)
		local n10 = hashNoise(x0 + 1, z0, seed)
		local n01 = hashNoise(x0, z0 + 1, seed)
		local n11 = hashNoise(x0 + 1, z0 + 1, seed)
		local nx0 = lerpNumber(n00, n10, tx)
		local nx1 = lerpNumber(n01, n11, tx)

		return lerpNumber(nx0, nx1, tz)
	end

	local function sampleVoronoiEdge(localX: number, localZ: number, scale: number, seed: number): number
		local sampleX = localX / math.max(scale, 0.001)
		local sampleZ = localZ / math.max(scale, 0.001)
		local cellX = math.floor(sampleX)
		local cellZ = math.floor(sampleZ)
		local nearest = math.huge
		local secondNearest = math.huge

		for dz = -1, 1 do
			for dx = -1, 1 do
				local x = cellX + dx
				local z = cellZ + dz
				local pointX = x + hashNoise(x, z, seed)
				local pointZ = z + hashNoise(x, z, seed + 19)
				local distanceX = pointX - sampleX
				local distanceZ = pointZ - sampleZ
				local distance = distanceX * distanceX + distanceZ * distanceZ

				if distance < nearest then
					secondNearest = nearest
					nearest = distance
				elseif distance < secondNearest then
					secondNearest = distance
				end
			end
		end

		return math.clamp(1 - smoothstep(0.015, 0.18, secondNearest - nearest), 0, 1)
	end

	local function sampleCaustics(tile: InternalOceanTile, depthAlpha: number, localX: number, localZ: number, time: number?): number
		local config = tile._Config

		if not config.CausticsEnabled or config.CausticsStrength <= 0 then
			return 0
		end

		local t = (time or 0) * config.CausticsSpeed
		local scale = math.max(config.CausticsScale, 0.5)
		local shallowAlpha = 1 - math.clamp(depthAlpha / math.max(config.CausticsDepthFade, 0.001), 0, 1)
		local shallowVisibility = shallowAlpha * shallowAlpha * (3 - 2 * shallowAlpha)
		local deepVisibility = math.clamp(depthAlpha, 0, 1)
		local waveA = math.sin((localX + t * 9.1) / scale * 6.283 + math.sin((localZ - t * 4.7) / scale * 4.2))
		local waveB = math.sin((localZ - t * 7.4) / (scale * 0.76) * 6.283 + math.sin((localX + t * 3.9) / scale * 3.8))
		local waveC = math.sin((localX + localZ + t * 5.2) / (scale * 1.18) * 6.283)
		local shallowLines = smoothstep(0.58, 0.96, (waveA + waveB + waveC) / 3 * 0.5 + 0.5)
		local softNoiseA = sampleValueNoise(localX + t * 4.2, localZ - t * 2.1, scale * 2.8, config.FoamNoiseSeed + 701)
		local softNoiseB = sampleValueNoise(localX - t * 2.6, localZ + t * 3.3, scale * 5.2, config.FoamNoiseSeed + 907)
		local deepNoise = softNoiseA * 0.64 + softNoiseB * 0.36
		local voronoi = sampleVoronoiEdge(localX + t * 2.8, localZ - t * 1.6, scale * 2.2, config.FoamNoiseSeed + 811)
		local deepPattern = deepNoise * (1 - config.CausticsVoronoiStrength)
			+ voronoi * math.clamp(config.CausticsVoronoiStrength, 0, 1)
		local shallowCaustics = shallowLines * config.ShallowCausticsStrength * shallowVisibility
		local deepCaustics = smoothstep(0.52, 0.92, deepPattern) * config.DeepCausticsStrength * deepVisibility

		return math.clamp((shallowCaustics + deepCaustics) * config.CausticsStrength, 0, 1)
	end

	local function sampleSurfFoamLace(
		tile: InternalOceanTile,
		localX: number,
		localZ: number,
		alongShore: number,
		acrossShore: number,
		time: number
	): number
		local config = tile._Config
		local textureScale = math.max(config.FoamTextureStudsPerTile, 3)
		local seed = config.FoamNoiseSeed
		local driftAlong = alongShore + time * 2.1
		local driftAcross = acrossShore - time * 1.15
		local broadNoise = sampleValueNoise(driftAlong, driftAcross, textureScale * 1.25, seed + 211)
		local scallopNoise = sampleValueNoise(
			driftAlong + broadNoise * textureScale * 0.65,
			driftAcross * 0.7 - time * 1.8,
			textureScale * 0.72,
			seed + 307
		)
		local brokenNoise = sampleValueNoise(
			localX - time * 1.6 + scallopNoise * textureScale * 0.35,
			localZ + time * 1.1 - broadNoise * textureScale * 0.35,
			textureScale * 0.36,
			seed + 419
		)
		local bandWarp = (broadNoise - 0.5) * textureScale * 0.9 + (scallopNoise - 0.5) * textureScale * 0.45
		local narrowPhase = ((acrossShore + bandWarp) / math.max(textureScale * 0.34, 0.001) - time * 0.22)
			* math.pi
			* 2
		local softPhase = (
			(acrossShore + bandWarp * 0.72 + alongShore * 0.035) / math.max(textureScale * 0.62, 0.001)
			- time * 0.14
		)
			* math.pi
			* 2
		local narrowBand = smoothstep(0.56, 0.96, math.sin(narrowPhase) * 0.5 + 0.5)
		local softBand = smoothstep(0.64, 0.98, math.sin(softPhase) * 0.5 + 0.5)
		local bandRidges = math.max(narrowBand, softBand * 0.72)
		local laceCells = sampleVoronoiEdge(
			localX + broadNoise * 5 + time * 1.2,
			localZ - scallopNoise * 4 - time * 0.8,
			textureScale * 0.42,
			seed + 521
		)
		local fineCells = sampleVoronoiEdge(
			localX * 1.46 - time * 1.8,
			localZ * 1.18 + time * 1.1,
			textureScale * 0.24,
			seed + 613
		)
		local holes = 1 - smoothstep(0.52, 0.92, brokenNoise)
		local filaments = smoothstep(0.45, 0.9, 1 - math.abs(scallopNoise - 0.5) * 2)

		return math.clamp(
			math.max(bandRidges * holes, laceCells * smoothstep(0.18, 0.78, broadNoise), fineCells * 0.48, filaments * holes * 0.5),
			0,
			1
		)
	end

	local function sampleTransitionFoam(tile: InternalOceanTile, localX: number, localZ: number, foamTime: number?): (number, number)
		if tile._DepthMap == nil then
			return 0, 0
		end

		local config = tile._Config
		local time = foamTime or 0
		local depth, oceanWeight, lakeWeight, shallowWeight = sampleDepthWeights(tile, localX, localZ)
		local shallowAlpha = 1 - sampleWaterDepthAlpha(tile, localX, localZ)
		local depthGradient = sampleDepthGradient(tile, localX, localZ)
		local gradientMagnitude = depthGradient.Magnitude
		local slopeAlpha = smoothstep(0.015, 0.18, gradientMagnitude)

		if shallowAlpha <= 0.002 then
			return 0, 0
		end

		local shoreNormalX = 0
		local shoreNormalZ = 1

		if gradientMagnitude > 0.0001 then
			shoreNormalX = depthGradient.X / gradientMagnitude
			shoreNormalZ = depthGradient.Y / gradientMagnitude
		end

		local shoreTangentX = -shoreNormalZ
		local shoreTangentZ = shoreNormalX
		local alongShore = localX * shoreTangentX + localZ * shoreTangentZ
		local acrossShore = localX * shoreNormalX + localZ * shoreNormalZ
		local baseWorld = tile.BaseCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
		local coastOceanWeight = math.clamp(oceanWeight + shallowWeight, 0, 1)
		local _incomingDx, incomingHeight, _incomingDz, incomingFoam =
			tile._Spectrum:SampleBakedWeighted3XZ(baseWorld.X, baseWorld.Z, time, 1, 1, 0, 0)
		local _localDx, localHeight, _localDz, localFoam =
			tile._Spectrum:SampleBakedWeighted3XZ(baseWorld.X, baseWorld.Z, time, 1, coastOceanWeight, lakeWeight, 0)
		local trailLag = math.clamp(config.FoamTrailLength, 0.1, 5)
		local _trailDxA, incomingTrailA, _trailDzA, incomingTrailFoamA =
			tile._Spectrum:SampleBakedWeighted3XZ(baseWorld.X, baseWorld.Z, time - 0.34 * trailLag, 1, 1, 0, 0)
		local _trailDxB, incomingTrailB, _trailDzB, incomingTrailFoamB =
			tile._Spectrum:SampleBakedWeighted3XZ(baseWorld.X, baseWorld.Z, time - 0.68 * trailLag, 0.85, 1, 0, 0)
		local oceanDepth = math.max(config.OceanDepth, math.max(config.LakeDepth, config.ShallowDepth + 0.001) + 0.001)
		local deepFactor = smoothstep(config.ShallowDepth, oceanDepth, depth)
		local depthWaveScale = config.ShallowWaveScale + (config.DeepWaveScale - config.ShallowWaveScale) * deepFactor
		local compression = math.clamp((config.DeepWaveScale - depthWaveScale) / math.max(config.DeepWaveScale, 0.001), 0, 1)
		local transitionBand = smoothstep(0.005, 0.58, shallowAlpha)
		local earlyCompression = math.max(compression, shallowAlpha * 0.22)
		local surfBand = smoothstep(0.16, 0.84, shallowAlpha)
		local breakStrength = transitionBand * math.max(earlyCompression, surfBand * 0.36) * lerpNumber(0.58, 1, slopeAlpha)
		local shoreBand = smoothstep(0.42, 0.96, shallowAlpha)
		local dryEdge = smoothstep(0.82, 0.99, shallowAlpha)
		local surfLace = sampleSurfFoamLace(tile, localX, localZ, alongShore, acrossShore, time)
		local shoreLineNoise = sampleValueNoise(
			alongShore + time * 0.65,
			acrossShore * 0.35,
			math.max(config.FoamTextureStudsPerTile * 0.78, 1),
			config.FoamNoiseSeed + 733
		)
		local scallopedShoreLine = smoothstep(0.74 - shoreLineNoise * 0.18, 0.99, shallowAlpha)
		local trailFeather = math.clamp(config.FoamTrailFeather, 0, 1)
		local laceFade = smoothstep(0.08, lerpNumber(0.58, 0.86, trailFeather), shallowAlpha)
		local incomingScale = math.max(config.DeepWaveScale, 0.05)
		local localScale = math.max(depthWaveScale, 0.05)
		local crestByIncoming = smoothstep(0.1 * incomingScale, 0.62 * incomingScale, incomingHeight * incomingScale)
		local crestBySqueeze = smoothstep(0.03 * localScale, 0.42 * localScale, (incomingHeight - localHeight) * compression)
		local trailByIncomingA = smoothstep(0.05 * incomingScale, 0.48 * incomingScale, incomingTrailA * incomingScale)
		local trailByIncomingB = smoothstep(0.02 * incomingScale, 0.38 * incomingScale, incomingTrailB * incomingScale)
		local breakup = sampleFoamBreakup(tile, localX + time * 1.7, localZ - time * 0.45)
		local crest = math.max(incomingFoam * 1.15, localFoam * 0.82, crestByIncoming * 0.92, crestBySqueeze)
			* breakStrength
			* lerpNumber(0.72, 1, breakup)
		local shoreWash = math.max(crestByIncoming, trailByIncomingA, dryEdge * 0.54)
			* shoreBand
			* lerpNumber(0.5, 1, surfLace)
		local shoreLine = scallopedShoreLine * lerpNumber(0.76, 1, surfLace) * math.max(0.58, slopeAlpha)
		local trail = (incomingTrailFoamA * 0.9 + incomingTrailFoamB * 0.58 + trailByIncomingA * 0.34 + trailByIncomingB * 0.24)
			* transitionBand
			* math.max(earlyCompression, shallowWeight * 0.55)
			* lerpNumber(0.66, 1, breakup)
		local laceTrail = surfLace * laceFade * math.max(earlyCompression, shoreBand * 0.88) * (1 - dryEdge * 0.12)

		return math.clamp(math.max(crest, shoreWash * 0.96, shoreLine * 0.78), 0, 1),
			math.clamp(math.max(trail, laceTrail * 0.82), 0, 1)
	end

	sampleShoreFoamAlpha = function(tile: InternalOceanTile, localX: number, localZ: number, foamTime: number?): number
		local config = tile._Config

		if tile._DepthMap == nil or config.ShoreFoamStrength <= 0 then
			return 0
		end

		local crestFoam = sampleTransitionFoam(tile, localX, localZ, foamTime)

		return math.clamp(crestFoam * config.ShoreFoamStrength, 0, 1)
	end

	local function sampleFoamTrailAlpha(tile: InternalOceanTile, localX: number, localZ: number, foamTime: number?): number
		local config = tile._Config

		if tile._DepthMap == nil or config.FoamTrailStrength <= 0 then
			return 0
		end

		local crestFoam, waveTrail = sampleTransitionFoam(tile, localX, localZ, foamTime)
		local shallowAlpha = 1 - sampleWaterDepthAlpha(tile, localX, localZ)
		local shoreWash = smoothstep(0.02, lerpNumber(0.58, 0.88, math.clamp(config.FoamTrailFeather, 0, 1)), shallowAlpha)

		if shoreWash <= 0 then
			return 0
		end

		local trailBehindCrest = math.clamp(waveTrail * (1 - crestFoam * 0.35), 0, 1)

		return math.clamp(shoreWash * trailBehindCrest * config.FoamTrailStrength, 0, 1)
	end

	sampleFoamBreakup = function(tile: InternalOceanTile, localX: number, localZ: number): number
		local config = tile._Config
		local influence = math.clamp(config.FoamNoiseInfluence, 0, 1)

		if influence <= 0 then
			return 1
		end

		local maxSize = math.max(tile.SourcePart.Size.X, tile.SourcePart.Size.Z, 1)
		local noiseCellSize = math.max(maxSize / math.max(config.FoamNoiseSize, 1), 1)
		local scale = math.max(math.min(config.FoamTextureStudsPerTile, noiseCellSize), 0.5)
		local seed = config.FoamNoiseSeed
		local broadNoise = sampleValueNoise(localX, localZ, scale * 2.8, seed + 97)
		local cellNoise = sampleValueNoise(localX + broadNoise * scale, localZ - broadNoise * scale, scale * 1.25, seed + 131)
		local edgeNoise = sampleVoronoiEdge(localX, localZ, scale * 2.2, seed + 173)
		local cells = smoothstep(0.2, 0.84, 1 - math.abs(cellNoise - 0.5) * 2)
		local edges = smoothstep(0.46, 0.94, edgeNoise)
		local mask = 0.52 + math.max(cells * 0.7, edges) * 0.48

		return lerpNumber(1, mask, influence)
	end

	local function resolveFoamAlpha(
		tile: InternalOceanTile,
		foamAlpha: number,
		depthAlpha: number,
		localX: number,
		localZ: number
	): number
		if foamAlpha <= 0 then
			return 0
		end

		local shallowFade = lerpNumber(0.86, 1, math.clamp(depthAlpha, 0, 1))
		local breakup = lerpNumber(0.82, 1, sampleFoamBreakup(tile, localX, localZ))

		return math.clamp(foamAlpha * shallowFade * breakup, 0, 1)
	end

	composeSurfaceSample = function(
		tile: InternalOceanTile,
		sample: WaterSurfaceColor.SurfaceSample,
		depthAlpha: number,
		localX: number,
		localZ: number,
		foamTime: number?
	): (Color3, number)
		local crestAlpha = resolveFoamAlpha(tile, sample.CrestFoamAlpha, depthAlpha, localX, localZ)
		local waveAlpha = resolveFoamAlpha(tile, sample.WaveFoamAlpha, depthAlpha, localX, localZ)
		local breakAlpha = resolveFoamAlpha(tile, sample.ExtraFoamAlpha, depthAlpha, localX, localZ)
		local foamAlpha = math.max(crestAlpha, waveAlpha, breakAlpha)
		local trailAlpha = sampleFoamTrailAlpha(tile, localX, localZ, foamTime)
			* lerpNumber(0.76, 1, math.clamp(depthAlpha, 0, 1))
		trailAlpha = math.clamp(trailAlpha * (1 - crestAlpha * 0.28), 0, 1)
		local shallowTint = (1 - math.clamp(depthAlpha, 0, 1)) * (1 - math.max(foamAlpha, trailAlpha * 0.6) * 0.42)
		local waterColor = lerpColor(sample.WaterColor, tile._Config.WaterColorTop, math.clamp(shallowTint * 0.62, 0, 1))
		local causticsAlpha = sampleCaustics(tile, depthAlpha, localX, localZ, foamTime) * (1 - math.max(foamAlpha, trailAlpha) * 0.75)
		waterColor = lerpColor(waterColor, tile._Config.CausticsColor, causticsAlpha)
		local trailColor = lerpColor(waterColor, sample.FoamColor, trailAlpha * 0.64)
		local finalColor = lerpColor(trailColor, sample.FoamColor, foamAlpha)
		local finalAlpha = math.clamp(
			sample.WaterAlpha + (1 - sample.WaterAlpha) * (trailAlpha * 0.46 + foamAlpha * 0.82),
			0,
			1
		)

		return finalColor, finalAlpha
	end

	local function resolveFoamOnlyAlpha(
		tile: InternalOceanTile,
		sample: WaterSurfaceColor.SurfaceSample,
		depthAlpha: number,
		localX: number,
		localZ: number,
		foamTime: number?
	): number
		local crestAlpha = resolveFoamAlpha(tile, sample.CrestFoamAlpha, depthAlpha, localX, localZ)
		local waveAlpha = resolveFoamAlpha(tile, sample.WaveFoamAlpha, depthAlpha, localX, localZ)
		local breakAlpha = resolveFoamAlpha(tile, sample.ExtraFoamAlpha, depthAlpha, localX, localZ)
		local foamAlpha = math.max(crestAlpha, waveAlpha, breakAlpha)
		local trailAlpha = sampleFoamTrailAlpha(tile, localX, localZ, foamTime)
			* lerpNumber(0.76, 1, math.clamp(depthAlpha, 0, 1))

		return math.clamp(foamAlpha + trailAlpha * 0.62 * (1 - foamAlpha * 0.35), 0, 1)
	end

	local function sampleObstacleImpact(obstacleMap: WaterObstacleMap.WaterObstacleMap?, localX: number, localZ: number): number
		if obstacleMap == nil then
			return 0
		end

		return obstacleMap:GetFoamSeed(localX, localZ)
	end

	local function sampleObstacleAttenuation(
		obstacleMap: WaterObstacleMap.WaterObstacleMap?,
		localX: number,
		localZ: number,
		strength: number
	): number
		if obstacleMap == nil then
			return 1
		end

		return obstacleMap:GetWaveAttenuation(localX, localZ, strength)
	end

	return {
		sampleDepth = sampleDepth,
		sampleWaterDepthAlpha = sampleWaterDepthAlpha,
		sampleDepthWeights = sampleDepthWeights,
		sampleDepthGradient = sampleDepthGradient,
		sampleValueNoise = sampleValueNoise,
		sampleVoronoiEdge = sampleVoronoiEdge,
		sampleCaustics = sampleCaustics,
		sampleShoreFoamAlpha = sampleShoreFoamAlpha,
		sampleFoamBreakup = sampleFoamBreakup,
		composeSurfaceSample = composeSurfaceSample,
		resolveFoamOnlyAlpha = resolveFoamOnlyAlpha,
		sampleObstacleImpact = sampleObstacleImpact,
		sampleObstacleAttenuation = sampleObstacleAttenuation,
	}
end
