--!strict

local AssetService = game:GetService("AssetService")
local WaterSurfaceColor = require(script.Parent.Parent.WaterSurfaceColor)

type TileConfig = any
type FaceState = any
type InternalOceanTile = any

return function(deps: any)
	local NORMAL_LOOP_MAX_FRAMES = deps.NORMAL_LOOP_MAX_FRAMES
	local SURFACE_IMAGE_PIXEL_BYTES = deps.SURFACE_IMAGE_PIXEL_BYTES
	local SURFACE_VERTEX_COLOR_BYTES = deps.SURFACE_VERTEX_COLOR_BYTES
	local RENDER_VERTEX_POSITION_BYTES = deps.RENDER_VERTEX_POSITION_BYTES
	local RENDER_VERTEX_INDEX_BYTES = deps.RENDER_VERTEX_INDEX_BYTES
	local SURFACE_METALNESS_VALUE = deps.SURFACE_METALNESS_VALUE
	local SURFACE_ROUGHNESS_VALUE = deps.SURFACE_ROUGHNESS_VALUE
	local lerpNumber = deps.lerpNumber
	local sampleShoreFoamAlpha = deps.sampleShoreFoamAlpha
	local composeSurfaceSample = deps.composeSurfaceSample

	-- Global guard to avoid spamming warnings when the editable-image pool is globally exhausted
	local globalEditableImagePoolWarned = false

	local function warnSurfaceColorUnsupported(tile: InternalOceanTile, err: any)
		if tile._SurfaceColorWarningShown then
			return
		end

		tile._SurfaceColorWarningShown = true
		warn("[WaterSystem] Surface color resource unavailable; falling back where possible: " .. tostring(err))
		warn(debug.traceback())
	end

	local function usesSurfaceAppearanceTexture(config: TileConfig): boolean
		return config.SurfaceColorMode == "SurfaceAppearance" or config.SurfaceColorMode == "FoamSurfaceAppearance"
	end

	local function usesWaterNormalMap(config: TileConfig): boolean
		return config.WaterNormalEnabled and config.WaterNormalStrength > 0 and config.WaterNormalResolution >= 16
	end

	local function usesRenderSurfaceAppearance(config: TileConfig): boolean
		return usesSurfaceAppearanceTexture(config)
			or config.SurfaceColorMode == "PaintVertices"
			or usesWaterNormalMap(config)
	end

	local function usesPaintVertices(config: TileConfig): boolean
		return config.SurfaceColorMode == "PaintVertices" or config.SurfaceColorMode == "FoamSurfaceAppearance"
	end

	local function shouldUseWhiteMeshColor(
		config: TileConfig,
		hasVertexColors: boolean,
		hasSurfaceAppearance: boolean
	): boolean
		if config.SurfaceColorMode == "SurfaceAppearance" then
			return hasSurfaceAppearance
		end

		return hasVertexColors
	end

	local function getSurfaceImageResolution(config: TileConfig): number
		return math.clamp(math.round(config.FoamTextureResolution), 16, 1024)
	end

	local function getSurfaceNormalResolution(config: TileConfig): number
		return math.clamp(math.round(config.WaterNormalResolution), 16, 512)
	end

	local function getSurfaceNormalFrameCount(config: TileConfig): number
		local duration = math.max(config.WaveLoopDuration, 0.25)
		local interval = math.max(config.WaterNormalUpdateInterval, 1 / 30)
		local intervalFrames = math.ceil(duration / interval)
		local waveFrames = math.clamp(math.round(config.WaveLoopFrames), 2, NORMAL_LOOP_MAX_FRAMES)

		return math.clamp(math.max(intervalFrames, waveFrames), 2, NORMAL_LOOP_MAX_FRAMES)
	end

	local function usesFresnelAlpha(config: TileConfig): boolean
		return config.FresnelEnabled and config.FresnelStrength > 0
	end

	local function applyFresnelAlpha(config: TileConfig, alpha: number, fresnelAlpha: number?): number
		if fresnelAlpha == nil or not usesFresnelAlpha(config) then
			return alpha
		end

		local shapedFresnel = math.clamp(fresnelAlpha, 0, 1) ^ math.max(config.FresnelPower, 0.05)
		local multiplier = lerpNumber(1, shapedFresnel, math.clamp(config.FresnelStrength, 0, 1))

		return math.clamp(alpha * multiplier, 0, 1)
	end

	local function addSurfaceColor(tile: InternalOceanTile, color: Color3, alpha: number): number?
		local editableMesh: any = tile.EditableMesh
		if not editableMesh or not tile._SurfaceColorSupported then
			return nil
		end

		local colorId = editableMesh:AddColor(color, alpha)

		if type(colorId) ~= "number" then
			tile._SurfaceColorSupported = false
			warnSurfaceColorUnsupported(tile, colorId)
			return nil
		end

		return colorId
	end

	local function addSurfaceUV(tile: InternalOceanTile, uv: Vector2): number?
		local editableMesh: any = tile.EditableMesh
		if not editableMesh or not tile._SurfaceUVSupported then
			return nil
		end

		local uvId = editableMesh:AddUV(uv)

		if type(uvId) ~= "number" then
			tile._SurfaceUVSupported = false
			warnSurfaceColorUnsupported(tile, uvId)
			return nil
		end

		return uvId
	end

	local function trySetSurfaceFaceColors(tile: InternalOceanTile, face: FaceState): boolean
		local colorA = tile._SurfaceColorIds[face.a]
		local colorB = tile._SurfaceColorIds[face.b]
		local colorC = tile._SurfaceColorIds[face.c]

		if colorA == nil or colorB == nil or colorC == nil then
			return false
		end

		local editableMesh: any = tile.EditableMesh
		if not editableMesh or not tile._SurfaceColorSupported then
			return false
		end

		editableMesh:SetFaceColors(face.id, { colorA, colorB, colorC })
		return true
	end

	local function trySetSurfaceFaceUVs(tile: InternalOceanTile, face: FaceState): boolean
		local uvA = tile._SurfaceUVIds[face.a]
		local uvB = tile._SurfaceUVIds[face.b]
		local uvC = tile._SurfaceUVIds[face.c]

		if uvA == nil or uvB == nil or uvC == nil then
			return false
		end

		local editableMesh: any = tile.EditableMesh
		if not editableMesh or not tile._SurfaceUVSupported then
			return false
		end

		editableMesh:SetFaceUVs(face.id, { uvA, uvB, uvC })
		return true
	end

	local function trySetSurfaceColor(tile: InternalOceanTile, colorId: number, color: Color3, alpha: number): boolean
		local editableMesh: any = tile.EditableMesh
		if not editableMesh or not tile._SurfaceColorSupported then
			return false
		end

		editableMesh:SetColor(colorId, color)
		editableMesh:SetColorAlpha(colorId, alpha)
		return true
	end

	local function ensureRenderVertexBuffers(tile: InternalOceanTile)
		local vertexCount = #tile._Vertices

		if tile._RenderVertexPositions == nil then
			tile._RenderVertexPositions = buffer.create(math.max(vertexCount, 1) * RENDER_VERTEX_POSITION_BYTES)
		end

		if tile._RenderVertexDirtyIndices == nil then
			tile._RenderVertexDirtyIndices = buffer.create(math.max(vertexCount, 1) * RENDER_VERTEX_INDEX_BYTES)
		end
	end

	local function beginRenderVertexFrame(tile: InternalOceanTile)
		ensureRenderVertexBuffers(tile)
		tile._RenderVertexDirtyCount = 0
	end

	local function writeRenderVertexPosition(tile: InternalOceanTile, vertexIndex: number, position: Vector3)
		ensureRenderVertexBuffers(tile)

		local positions = tile._RenderVertexPositions
		local indices = tile._RenderVertexDirtyIndices

		if positions == nil or indices == nil then
			return
		end

		local vertexOffset = (vertexIndex - 1) * RENDER_VERTEX_POSITION_BYTES
		local dirtyOffset = tile._RenderVertexDirtyCount * RENDER_VERTEX_INDEX_BYTES

		buffer.writef32(positions, vertexOffset, position.X)
		buffer.writef32(positions, vertexOffset + 4, position.Y)
		buffer.writef32(positions, vertexOffset + 8, position.Z)
		buffer.writeu16(indices, dirtyOffset, vertexIndex)
		tile._RenderVertexDirtyCount += 1
	end

	local function ensureRenderSurfaceColorBuffer(tile: InternalOceanTile)
		local vertexCount = #tile._Vertices

		if tile._RenderSurfaceColorPixels == nil then
			tile._RenderSurfaceColorPixels = buffer.create(math.max(vertexCount, 1) * SURFACE_VERTEX_COLOR_BYTES)
		end
	end

	local function writeRenderSurfaceColor(tile: InternalOceanTile, vertexIndex: number, color: Color3, alpha: number)
		ensureRenderSurfaceColorBuffer(tile)

		local colors = tile._RenderSurfaceColorPixels

		if colors == nil then
			return
		end

		local offset = (vertexIndex - 1) * SURFACE_VERTEX_COLOR_BYTES

		buffer.writeu8(colors, offset, math.clamp(math.floor(color.R * 255 + 0.5), 0, 255))
		buffer.writeu8(colors, offset + 1, math.clamp(math.floor(color.G * 255 + 0.5), 0, 255))
		buffer.writeu8(colors, offset + 2, math.clamp(math.floor(color.B * 255 + 0.5), 0, 255))
		buffer.writeu8(colors, offset + 3, math.clamp(math.floor(alpha * 255 + 0.5), 0, 255))
		tile._RenderSurfaceColorDirty = true
	end

	local function queueSurfaceTexturePixels(tile: InternalOceanTile, pixels: buffer, resolution: number)
		tile._RenderSurfaceTexturePixels = pixels
		tile._RenderSurfaceTextureResolution = resolution
		tile._RenderSurfaceTextureDirty = true
	end

	local function queueSurfaceNormalPixels(tile: InternalOceanTile, pixels: buffer, resolution: number)
		tile._RenderSurfaceNormalPixels = pixels
		tile._RenderSurfaceNormalResolution = resolution
		tile._RenderSurfaceNormalDirty = true
	end

	local function destroySurfaceAppearance(tile: InternalOceanTile)
		if tile._SurfaceAppearance ~= nil then
			tile._SurfaceAppearance:Destroy()
			tile._SurfaceAppearance = nil
		end

		if tile._SurfaceImage ~= nil then
			pcall(function()
				tile._SurfaceImage:Destroy()
			end)
			tile._SurfaceImage = nil
		end

		if tile._SurfaceNormalImage ~= nil then
			pcall(function()
				tile._SurfaceNormalImage:Destroy()
			end)
			tile._SurfaceNormalImage = nil
		end

		if tile._SurfaceMetalnessImage ~= nil then
			pcall(function()
				tile._SurfaceMetalnessImage:Destroy()
			end)
			tile._SurfaceMetalnessImage = nil
		end

		if tile._SurfaceRoughnessImage ~= nil then
			pcall(function()
				tile._SurfaceRoughnessImage:Destroy()
			end)
			tile._SurfaceRoughnessImage = nil
		end

		tile._SurfaceImageResolution = 0
		tile._SurfaceNormalImageResolution = 0
		tile._SurfaceNormalLastUpdateTime = -math.huge
		tile._SurfaceNormalLastFrameIndex = -1
		tile._SurfaceNormalRuntimePixels = nil
		tile._SurfaceTextureLastUpdateTime = -math.huge
		tile._SurfaceTextureLastFrameIndex = -1
		tile._SurfaceTextureRuntimePixels = nil
		tile._RenderSurfaceTextureDirty = false
		tile._RenderSurfaceNormalDirty = false
	end

	local function resetSurfaceBake(tile: InternalOceanTile)
		tile._SurfaceBakeId += 1
		tile._SurfaceTextureFramePixels = nil
		tile._SurfaceTextureFrameCount = 0
		tile._SurfaceTextureFrameResolution = 0
		tile._SurfaceTextureRuntimePixels = nil
		tile._SurfaceTextureLastFrameIndex = -1
		tile._SurfaceVertexFrameColors = nil
		tile._SurfaceVertexFrameCount = 0
		tile._SurfaceVertexLastFrameIndex = -1
		tile._SurfaceBakeKey = ""
		tile._SurfaceBakeBaking = false
		tile._SurfaceNormalBakeId += 1
		tile._SurfaceNormalFramePixels = nil
		tile._SurfaceNormalFrameCount = 0
		tile._SurfaceNormalFrameResolution = 0
		tile._SurfaceNormalRuntimePixels = nil
		tile._SurfaceNormalLastFrameIndex = -1
		tile._SurfaceNormalBakeKey = ""
		tile._SurfaceNormalBakeBaking = false
		tile._RenderSurfaceColorDirty = false
		tile._RenderSurfaceTextureDirty = false
		tile._RenderSurfaceNormalDirty = false
	end

	local function resetWaveLoop(tile: InternalOceanTile)
		tile._WaveLoopBakeId += 1
		tile._WaveLoopPositions = nil
		tile._WaveLoopHeights = nil
		tile._WaveLoopFrames = 0
		tile._WaveLoopReadyFrames = 0
		tile._WaveLoopFrameStride = 0
		tile._WaveLoopDuration = math.max(tile._Config.WaveLoopDuration, 0.25)
		tile._WaveLoopMinHeight = 0
		tile._WaveLoopMaxHeight = 0
		tile._WaveLoopKey = ""
		tile._WaveLoopBaking = false
		resetSurfaceBake(tile)
	end

	local function ensureSurfaceUVs(tile: InternalOceanTile): boolean
		if not tile._SurfaceUVSupported then
			return false
		end

		if #tile._SurfaceUVIds == #tile._Vertices then
			return true
		end

		table.clear(tile._SurfaceUVIds)

		local sizeX = math.max(tile.SourcePart.Size.X, 0.001)
		local sizeZ = math.max(tile.SourcePart.Size.Z, 0.001)

		for vertexIndex, vertex in ipairs(tile._Vertices) do
			local u = math.clamp(vertex.baseLocal.X / sizeX + 0.5, 0, 1)
			local v = math.clamp(0.5 - vertex.baseLocal.Z / sizeZ, 0, 1)
			local uvId = addSurfaceUV(tile, Vector2.new(u, v))

			if uvId == nil then
				return false
			end

			tile._SurfaceUVIds[vertexIndex] = uvId
		end

		for _, face in ipairs(tile._Faces) do
			if not trySetSurfaceFaceUVs(tile, face) then
				return false
			end
		end

		return true
	end

	local function createSolidSurfaceImage(value: number): EditableImage?
		local img, imgErr = deps.createEditableImage(true)

		if img == nil then
			return nil
		end

		local image = img :: EditableImage
		local byteValue = math.clamp(math.floor(value * 255 + 0.5), 0, 255)
		local pixels = buffer.create(SURFACE_IMAGE_PIXEL_BYTES)

		buffer.writeu8(pixels, 0, byteValue)
		buffer.writeu8(pixels, 1, byteValue)
		buffer.writeu8(pixels, 2, byteValue)
		buffer.writeu8(pixels, 3, 255)

		-- Write pixels; if this errors, treat as failed image creation.
		local okWrite, writeErr = pcall(function()
			image:WritePixelsBuffer(Vector2.zero, Vector2.new(1, 1), pixels)
		end)

		if not okWrite then
			pcall(function()
				image:Destroy()
			end)
			return nil
		end

		return image
	end

	local function ensureSurfaceAppearance(tile: InternalOceanTile): boolean
		if not usesRenderSurfaceAppearance(tile._Config) then
			destroySurfaceAppearance(tile)
			return false
		end

		if not tile._SurfaceAppearanceSupported then
			return false
		end

		local needsColorMap = usesSurfaceAppearanceTexture(tile._Config)
		local needsNormalMap = usesWaterNormalMap(tile._Config) and tile._SurfaceNormalSupported
		local colorResolution = if needsColorMap then getSurfaceImageResolution(tile._Config) else 0
		local normalResolution = if needsNormalMap then getSurfaceNormalResolution(tile._Config) else 0
		local colorReady = not needsColorMap
			or (tile._SurfaceImage ~= nil and tile._SurfaceImageResolution == colorResolution)
		local normalReady = not needsNormalMap
			or (tile._SurfaceNormalImage ~= nil and tile._SurfaceNormalImageResolution == normalResolution)
		local unusedImagesCleared = (needsColorMap or tile._SurfaceImage == nil)
			and (needsNormalMap or tile._SurfaceNormalImage == nil)

		if tile._SurfaceAppearance ~= nil and colorReady and normalReady and unusedImagesCleared then
			return true
		end

		destroySurfaceAppearance(tile)

		if not needsColorMap and not needsNormalMap then
			local ok, surfaceOrError = pcall(function()
				return Instance.new("SurfaceAppearance")
			end)

			if not ok or surfaceOrError == nil then
				warnSurfaceColorUnsupported(tile, surfaceOrError)
				return false
			end

			local surface = surfaceOrError :: SurfaceAppearance

			surface.Name = "WaterSurfacePipeline"
			surface.Parent = tile.MeshPart
			tile._SurfaceAppearance = surface
			return true
		end

		local image: EditableImage? = nil
		local normalImage: EditableImage? = nil
		local metalnessImage: EditableImage? = nil
		local roughnessImage: EditableImage? = nil

		if needsColorMap then
			-- If pool already observed as exhausted globally, don't attempt per-tile allocations
			if deps.isEditableImagePoolExhausted and deps.isEditableImagePoolExhausted() then
				if not globalEditableImagePoolWarned then
					warn("[WaterSystem] EditableImage pool globally exhausted; skipping color maps until pool frees up")
					globalEditableImagePoolWarned = true
				end
				image = nil
				needsColorMap = false
			else
				local img, imgErr = deps.createEditableImage(true)
				if img == nil then
					-- allocation failed; treat like no color map for this tile
					image = nil
					needsColorMap = false
				else
					image = img :: EditableImage
				end
			end
		end

		if needsNormalMap then
			if deps.isEditableImagePoolExhausted and deps.isEditableImagePoolExhausted() then
				-- No pool capacity, disable normal map for now
				if not globalEditableImagePoolWarned then
					warn(
						"[WaterSystem] EditableImage pool globally exhausted; skipping normal maps until pool frees up"
					)
					globalEditableImagePoolWarned = true
				end
				needsNormalMap = false
			else
				local img, imgErr = deps.createEditableImage(true)
				if img == nil then
					tile._SurfaceNormalSupported = false
					needsNormalMap = false
				else
					normalImage = img :: EditableImage
				end
			end
		end

		if image ~= nil or normalImage ~= nil then
			metalnessImage = createSolidSurfaceImage(SURFACE_METALNESS_VALUE)
			roughnessImage = createSolidSurfaceImage(SURFACE_ROUGHNESS_VALUE)
		end

		local createOptions: any = {}

		if image ~= nil then
			createOptions.ColorMap = Content.fromObject(image)
		end

		if normalImage ~= nil then
			createOptions.NormalMap = Content.fromObject(normalImage)
		end

		if metalnessImage ~= nil then
			createOptions.MetalnessMap = Content.fromObject(metalnessImage)
		end

		if roughnessImage ~= nil then
			createOptions.RoughnessMap = Content.fromObject(roughnessImage)
		end

		local surfaceOk: boolean = false
		local surfaceOrError: any = nil

		if image ~= nil or normalImage ~= nil or metalnessImage ~= nil or roughnessImage ~= nil then
			surfaceOk, surfaceOrError = pcall(function()
				return AssetService:CreateSurfaceAppearanceAsync(createOptions)
			end)
		else
			surfaceOk, surfaceOrError = pcall(function()
				return Instance.new("SurfaceAppearance")
			end)
		end

		if (not surfaceOk or surfaceOrError == nil) and (metalnessImage ~= nil or roughnessImage ~= nil) then
			pcall(function()
				if metalnessImage ~= nil then
					metalnessImage:Destroy()
				end

				if roughnessImage ~= nil then
					roughnessImage:Destroy()
				end
			end)
			metalnessImage = nil
			roughnessImage = nil
			createOptions.MetalnessMap = nil
			createOptions.RoughnessMap = nil

			if image ~= nil or normalImage ~= nil then
				surfaceOk, surfaceOrError = pcall(function()
					return AssetService:CreateSurfaceAppearanceAsync(createOptions)
				end)
			else
				surfaceOk, surfaceOrError = pcall(function()
					return Instance.new("SurfaceAppearance")
				end)
			end
		end

		if (not surfaceOk or surfaceOrError == nil) and normalImage ~= nil then
			tile._SurfaceNormalSupported = false
			pcall(function()
				(normalImage :: EditableImage):Destroy()
			end)
			normalImage = nil
			createOptions.NormalMap = nil
			warnSurfaceColorUnsupported(tile, surfaceOrError)

			if image ~= nil or metalnessImage ~= nil or roughnessImage ~= nil then
				surfaceOk, surfaceOrError = pcall(function()
					return AssetService:CreateSurfaceAppearanceAsync(createOptions)
				end)
			else
				surfaceOk, surfaceOrError = pcall(function()
					return Instance.new("SurfaceAppearance")
				end)
			end
		end

		if not surfaceOk or surfaceOrError == nil then
			tile._SurfaceAppearanceSupported = false
			pcall(function()
				if image ~= nil then
					image:Destroy()
				end

				if normalImage ~= nil then
					normalImage:Destroy()
				end

				if metalnessImage ~= nil then
					metalnessImage:Destroy()
				end

				if roughnessImage ~= nil then
					roughnessImage:Destroy()
				end
			end)
			warnSurfaceColorUnsupported(tile, surfaceOrError)
			return false
		end

		local surface = surfaceOrError :: SurfaceAppearance

		if image ~= nil and normalImage ~= nil then
			surface.Name = "WaterSurfacePipeline"
		elseif normalImage ~= nil then
			surface.Name = "WaterSurfaceNormal"
		elseif image ~= nil then
			surface.Name = "WaterSurfaceColor"
		else
			surface.Name = "WaterSurfacePipeline"
		end

		surface.Parent = tile.MeshPart
		tile._SurfaceImage = image
		tile._SurfaceImageResolution = if image ~= nil then colorResolution else 0
		tile._SurfaceNormalImage = normalImage
		tile._SurfaceNormalImageResolution = if normalImage ~= nil then normalResolution else 0
		tile._SurfaceMetalnessImage = metalnessImage
		tile._SurfaceRoughnessImage = roughnessImage
		tile._SurfaceAppearance = surface
		tile._SurfaceTextureLastUpdateTime = -math.huge
		tile._SurfaceNormalLastUpdateTime = -math.huge

		return true
	end

	local function createSurfaceColorConfig(config: TileConfig): WaterSurfaceColor.SurfaceColorConfig
		return WaterSurfaceColor.BuildConfig({
			SurfaceColorBake = config.SurfaceColorBake,
			SurfaceColorMode = config.SurfaceColorMode,
			WaterColorBack = config.WaterColorBack,
			WaterColorTop = config.WaterColorTop,
			WaterColorGain = config.WaterColorGain,
			WaterAlphaGain = config.WaterAlphaGain,
			WaterVertexAlpha = config.WaterVertexAlpha,
			FoamColor = config.FoamColor,
			CrestFoamAlphaBack = config.CrestFoamAlphaBack,
			CrestFoamAlphaTop = config.CrestFoamAlphaTop,
			CrestFoamAlphaGain = config.CrestFoamAlphaGain,
			WaveFoamAlphaBack = config.WaveFoamAlphaBack,
			WaveFoamAlphaTop = config.WaveFoamAlphaTop,
			WaveFoamAlphaGain = config.WaveFoamAlphaGain,
		})
	end

	local function ensureSurfaceVertexColors(tile: InternalOceanTile): boolean
		if not tile._SurfaceColorSupported then
			return false
		end

		if #tile._SurfaceColorIds == #tile._Vertices then
			return true
		end

		table.clear(tile._SurfaceColorIds)

		for vertexIndex = 1, #tile._Vertices do
			local colorId = addSurfaceColor(tile, tile._Config.WaterColorBack, 0)

			if colorId == nil then
				return false
			end

			tile._SurfaceColorIds[vertexIndex] = colorId
		end

		for _, face in ipairs(tile._Faces) do
			if not trySetSurfaceFaceColors(tile, face) then
				return false
			end
		end

		return true
	end

	local function paintSurfaceVertex(
		tile: InternalOceanTile,
		surfaceColorConfig: WaterSurfaceColor.SurfaceColorConfig,
		vertexIndex: number,
		height: number,
		includeFoam: boolean,
		depthAlpha: number,
		localX: number,
		localZ: number,
		foamTime: number,
		fresnelAlpha: number?
	)
		if not tile._SurfaceColorSupported then
			return
		end

		local colorId = tile._SurfaceColorIds[vertexIndex]

		if colorId == nil then
			return
		end

		local normalizedHeight =
			WaterSurfaceColor.NormalizeHeight(height, tile._WaveLoopMinHeight, tile._WaveLoopMaxHeight)
		if includeFoam then
			local shoreFoamAlpha = sampleShoreFoamAlpha(tile, localX, localZ, foamTime)
			local fullSample =
				WaterSurfaceColor.Sample(surfaceColorConfig, normalizedHeight, shoreFoamAlpha, depthAlpha)
			local finalColor, finalAlpha = composeSurfaceSample(tile, fullSample, depthAlpha, localX, localZ, foamTime)

			writeRenderSurfaceColor(
				tile,
				vertexIndex,
				finalColor,
				applyFresnelAlpha(tile._Config, finalAlpha, fresnelAlpha)
			)
		else
			local waterSample = WaterSurfaceColor.SampleWater(surfaceColorConfig, normalizedHeight, depthAlpha)
			writeRenderSurfaceColor(
				tile,
				vertexIndex,
				waterSample.Color,
				applyFresnelAlpha(tile._Config, waterSample.Alpha, fresnelAlpha)
			)
		end
	end

	return {
		warnSurfaceColorUnsupported = warnSurfaceColorUnsupported,
		usesSurfaceAppearanceTexture = usesSurfaceAppearanceTexture,
		usesWaterNormalMap = usesWaterNormalMap,
		usesRenderSurfaceAppearance = usesRenderSurfaceAppearance,
		usesPaintVertices = usesPaintVertices,
		shouldUseWhiteMeshColor = shouldUseWhiteMeshColor,
		getSurfaceImageResolution = getSurfaceImageResolution,
		getSurfaceNormalResolution = getSurfaceNormalResolution,
		getSurfaceNormalFrameCount = getSurfaceNormalFrameCount,
		usesFresnelAlpha = usesFresnelAlpha,
		applyFresnelAlpha = applyFresnelAlpha,
		addSurfaceColor = addSurfaceColor,
		addSurfaceUV = addSurfaceUV,
		trySetSurfaceFaceColors = trySetSurfaceFaceColors,
		trySetSurfaceFaceUVs = trySetSurfaceFaceUVs,
		trySetSurfaceColor = trySetSurfaceColor,
		beginRenderVertexFrame = beginRenderVertexFrame,
		writeRenderVertexPosition = writeRenderVertexPosition,
		ensureRenderSurfaceColorBuffer = ensureRenderSurfaceColorBuffer,
		writeRenderSurfaceColor = writeRenderSurfaceColor,
		queueSurfaceTexturePixels = queueSurfaceTexturePixels,
		queueSurfaceNormalPixels = queueSurfaceNormalPixels,
		destroySurfaceAppearance = destroySurfaceAppearance,
		resetSurfaceBake = resetSurfaceBake,
		resetWaveLoop = resetWaveLoop,
		ensureSurfaceUVs = ensureSurfaceUVs,
		ensureSurfaceAppearance = ensureSurfaceAppearance,
		createSurfaceColorConfig = createSurfaceColorConfig,
		ensureSurfaceVertexColors = ensureSurfaceVertexColors,
		paintSurfaceVertex = paintSurfaceVertex,
	}
end
