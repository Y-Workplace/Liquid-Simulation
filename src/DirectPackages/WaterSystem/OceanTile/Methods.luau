--!strict

local WaterSurfaceColor = require(script.Parent.Parent.WaterSurfaceColor)
local WaveSpectrum = require(script.Parent.Parent.WaveSpectrum)

type TileConfig = any

return function(OceanTileClass: any, deps: any)
	local RENDER_VERTEX_POSITION_BYTES = deps.RENDER_VERTEX_POSITION_BYTES
	local RENDER_VERTEX_INDEX_BYTES = deps.RENDER_VERTEX_INDEX_BYTES
	local SURFACE_VERTEX_COLOR_BYTES = deps.SURFACE_VERTEX_COLOR_BYTES
	local RING_LOD_VERTEX_OFFSET = deps.RING_LOD_VERTEX_OFFSET
	local RING_LOD_LEVEL_OFFSET = deps.RING_LOD_LEVEL_OFFSET
	local RING_LEVEL_NEAR = deps.RING_LEVEL_NEAR
	local beginRenderVertexFrame = deps.beginRenderVertexFrame
	local writeRenderVertexPosition = deps.writeRenderVertexPosition
	local getBaseCFrame = deps.getBaseCFrame
	local distanceToSourcePart = deps.distanceToSourcePart
	local getLodDetail = deps.getLodDetail
	local ensureRingLodCache = deps.ensureRingLodCache
	local ensureWaveLoop = deps.ensureWaveLoop
	local getWaveLoopReadyFrameCount = deps.getWaveLoopReadyFrameCount
	local getWaveLoopFrame = deps.getWaveLoopFrame
	local readWaveLoopVertex = deps.readWaveLoopVertex
	local ringLodEntryOffset = deps.ringLodEntryOffset
	local getRingLodDetail = deps.getRingLodDetail
	local getRingDistanceFactor = deps.getRingDistanceFactor
	local sampleBakedHeight = deps.sampleBakedHeight
	local sampleWaterDepthAlpha = deps.sampleWaterDepthAlpha
	local sampleSurfaceNormalLocal = deps.sampleSurfaceNormalLocal
	local sampleSurfaceFresnelAlpha = deps.sampleSurfaceFresnelAlpha
	local ensureSurfaceFrameBake = deps.ensureSurfaceFrameBake
	local usesPaintVertices = deps.usesPaintVertices
	local ensureSurfaceVertexColors = deps.ensureSurfaceVertexColors
	local applyBakedSurfaceVertexColors = deps.applyBakedSurfaceVertexColors
	local createSurfaceColorConfig = deps.createSurfaceColorConfig
	local usesFresnelAlpha = deps.usesFresnelAlpha
	local paintSurfaceVertex = deps.paintSurfaceVertex
	local usesSurfaceAppearanceTexture = deps.usesSurfaceAppearanceTexture
	local applyBakedSurfaceAppearanceTexture = deps.applyBakedSurfaceAppearanceTexture
	local updateSurfaceAppearanceTexture = deps.updateSurfaceAppearanceTexture
	local applyBakedSurfaceNormalMap = deps.applyBakedSurfaceNormalMap
	local obstacleImpactVertexOffset = deps.obstacleImpactVertexOffset
	local sampleWaveLoop = deps.sampleWaveLoop
	local syncReflectionMeshPart = deps.syncReflectionMeshPart
	local trySetVertexPosition = deps.trySetVertexPosition
	local trySetSurfaceColor = deps.trySetSurfaceColor
	local warnSurfaceColorUnsupported = deps.warnSurfaceColorUnsupported
	local getWaveLoopKey = deps.getWaveLoopKey
	local getWaveLoopGeometryKey = deps.getWaveLoopGeometryKey
	local resetWaveLoop = deps.resetWaveLoop
	local resetSurfaceBake = deps.resetSurfaceBake
	local usesWaterNormalMap = deps.usesWaterNormalMap
	local ensureSurfaceUVs = deps.ensureSurfaceUVs
	local ensureSurfaceAppearance = deps.ensureSurfaceAppearance
	local shouldUseWhiteMeshColor = deps.shouldUseWhiteMeshColor
	local createWaterBuffer = deps.createWaterBuffer
	local configureSeaSpray = deps.configureSeaSpray
	local configureSplashParticles = deps.configureSplashParticles
	local isWorldPositionNearCamera = deps.isWorldPositionNearCamera
	local cframeWithUp = deps.cframeWithUp
	local getVolumeDepth = deps.getVolumeDepth
	local destroySurfaceAppearance = deps.destroySurfaceAppearance

	function OceanTileClass:_SetFlat()
		if self._IsFlat then
			return
		end

		beginRenderVertexFrame(self)

		for vertexIndex, vertex in ipairs(self._Vertices) do
			writeRenderVertexPosition(self, vertexIndex, vertex.baseLocal)
		end

		self._IsFlat = true
	end

	function OceanTileClass:WriteExternalState(_time: number, camera: Camera?, renderVisible: boolean?)
		if self._Destroyed or self._MeshInvalid then
			return
		end

		local baseCFrame = getBaseCFrame(self.SourcePart)

		self.BaseCFrame = baseCFrame

		if self._RenderTargetCFrame ~= baseCFrame then
			self._RenderTargetCFrame = baseCFrame
			self._RenderTransformDirty = true
		end

		local cameraPosition = if camera then camera.CFrame.Position else self.BaseCFrame.Position
		local cameraLocal = self.BaseCFrame:PointToObjectSpace(cameraPosition)
		local distance = distanceToSourcePart(self.SourcePart, cameraPosition)
		local detail = getLodDetail(self._Config, distance)
		local distanceFactor = 1

		if distance > self._Config.FadeStartDistance then
			distanceFactor = math.clamp(
				1 - ((distance - self._Config.FadeStartDistance) / math.max(self._Config.MaxDistance - self._Config.FadeStartDistance, 1)),
				0,
				1
			)
		end

		self._StageCameraLocal = cameraLocal
		self._StageDistance = distance
		self._StageDetail = detail
		self._StageDistanceFactor = distanceFactor
		self._StageRenderVisible = renderVisible ~= false
	end

	function OceanTileClass:StepLodBuffer()
		if self._Destroyed or self._MeshInvalid or self._StageDetail <= 0 then
			return
		end

		ensureRingLodCache(self, self._StageCameraLocal.X, self._StageCameraLocal.Z)
	end

	function OceanTileClass:StepWaveBuffer(time: number)
		if self._Destroyed or self._MeshInvalid then
			return
		end

		local detail = self._StageDetail

		if detail <= 0 then
			if self._WaterBuffer ~= nil and self._WaterBuffer:HasActivity() then
				self._WaterBuffer:Clear()
			end

			self:_SetFlat()
			return
		end

		local waterBuffer = self._WaterBuffer
		local physicsActive = waterBuffer ~= nil
			and self._StageDistance <= self._Config.PhysicsDistance
			and detail > 0.05

		local deltaTime = if self._LastUpdateTime >= 0 then math.clamp(time - self._LastUpdateTime, 0, 0.25) else 1 / 30
		self._LastUpdateTime = time

		if physicsActive and waterBuffer ~= nil then
			waterBuffer:StepSimulation(self._Config.InteractiveSimulationIterations)
			waterBuffer:UpdateNormals()
		elseif waterBuffer ~= nil and waterBuffer:HasActivity() then
			local fade = self._Config.InteractiveLodDissipation ^ math.max(deltaTime * 30, 1)

			waterBuffer:StepSimulation(1)
			waterBuffer:FadeActivity(fade)
		end

		if self._InteractionWakeFrames > 0 then
			self._InteractionWakeFrames = if physicsActive then self._InteractionWakeFrames - 1 else 0
		end

		if not self._StageRenderVisible then
			return
		end

		local positions: buffer? = nil
		local frameA = 0
		local frameB = 0
		local frameAlpha = 0
		local vertexCount = 1

		ensureWaveLoop(self)
		positions = self._WaveLoopPositions

		if positions ~= nil and getWaveLoopReadyFrameCount(self) > 0 then
			frameA, frameB, frameAlpha = getWaveLoopFrame(self, time)
			vertexCount = math.max(self._WaveLoopFrameStride, 1)
		else
			positions = nil
		end

		local interactiveBufferActive = physicsActive and waterBuffer ~= nil and waterBuffer:HasActivity()
		local ringIndices = self._RingLodIndices

		if ringIndices == nil then
			return
		end

		beginRenderVertexFrame(self)

		for entryIndex = 0, self._RingLodCount - 1 do
			local entryOffset = ringLodEntryOffset(entryIndex)
			local vertexIndex = buffer.readu16(ringIndices, entryOffset + RING_LOD_VERTEX_OFFSET)
			local lodLevel = buffer.readu16(ringIndices, entryOffset + RING_LOD_LEVEL_OFFSET)
			local vertex = self._Vertices[vertexIndex]

			if vertex == nil then
				continue
			end

			local vertexDetail = getRingLodDetail(self._Config, detail, lodLevel)
			local vertexDistanceFactor = getRingDistanceFactor(self._StageDistanceFactor, lodLevel)

			local dx = 0
			local dy = 0
			local dz = 0

			if positions ~= nil then
				dx, dy, dz = readWaveLoopVertex(
					positions,
					frameA,
					frameB,
					frameAlpha,
					vertexCount,
					vertexIndex
				)
			end

			local baseLocal = vertex.baseLocal
			local interactiveHeight = if interactiveBufferActive and waterBuffer ~= nil and vertex.surfaceEnabled and lodLevel == RING_LEVEL_NEAR
				then waterBuffer:SampleHeight(baseLocal.X, baseLocal.Z)
				else 0
			local vertexWaveScale = vertexDetail * vertexDistanceFactor

			writeRenderVertexPosition(
				self,
				vertexIndex,
				Vector3.new(
					baseLocal.X + dx * vertexWaveScale,
					baseLocal.Y + dy * vertexWaveScale + interactiveHeight * vertexDistanceFactor,
					baseLocal.Z + dz * vertexWaveScale
				)
			)
		end

		self._IsFlat = false
	end

	function OceanTileClass:StepSurfaceBuffer(time: number)
		if self._Destroyed or self._MeshInvalid or not self._StageRenderVisible or self._StageDetail <= 0 then
			return
		end

		ensureWaveLoop(self)

		local waterBuffer = self._WaterBuffer
		local physicsActive = waterBuffer ~= nil
			and self._StageDistance <= self._Config.PhysicsDistance
			and self._StageDetail > 0.05
		local interactiveBufferActive = physicsActive and waterBuffer ~= nil and waterBuffer:HasActivity()
		local surfaceAppearanceWaterBuffer = if interactiveBufferActive then waterBuffer else nil
		local surfaceBakeActive = self._Config.SurfaceColorBake and ensureSurfaceFrameBake(self)
		local surfaceBakeInProgress = self._Config.SurfaceColorBake and self._SurfaceBakeBaking
		local paintSurfaceColors = usesPaintVertices(self._Config) and ensureSurfaceVertexColors(self)
		local paintSurfaceFoam = self._Config.SurfaceColorMode == "PaintVertices"
		local surfaceColorConfig: WaterSurfaceColor.SurfaceColorConfig? = nil

		if paintSurfaceColors and surfaceBakeActive then
			if not applyBakedSurfaceVertexColors(self, time, self._StageCameraLocal, surfaceAppearanceWaterBuffer) then
				surfaceBakeActive = false
				surfaceColorConfig = createSurfaceColorConfig(self._Config)
			end
		elseif paintSurfaceColors then
			surfaceColorConfig = createSurfaceColorConfig(self._Config)
		end

		if paintSurfaceColors and not surfaceBakeActive and surfaceColorConfig ~= nil then
			local ringIndices = self._RingLodIndices

			if ringIndices ~= nil then
				for entryIndex = 0, self._RingLodCount - 1 do
					local entryOffset = ringLodEntryOffset(entryIndex)
					local vertexIndex = buffer.readu16(ringIndices, entryOffset + RING_LOD_VERTEX_OFFSET)
					local vertex = self._Vertices[vertexIndex]

					if vertex == nil then
						continue
					end

					local baseLocal = vertex.baseLocal
					local height = sampleBakedHeight(self, baseLocal.X, baseLocal.Z, time)
					local depthAlpha = sampleWaterDepthAlpha(self, baseLocal.X, baseLocal.Z)
					local fresnelAlpha: number? = nil

					if vertex.surfaceEnabled and usesFresnelAlpha(self._Config) then
						local normalLocal = sampleSurfaceNormalLocal(
							self,
							baseLocal.X,
							baseLocal.Z,
							time,
							surfaceAppearanceWaterBuffer,
							nil,
							0.18
						)

						fresnelAlpha = sampleSurfaceFresnelAlpha(
							self,
							Vector3.new(baseLocal.X, height, baseLocal.Z),
							normalLocal,
							self._StageCameraLocal
						)
					end

					paintSurfaceVertex(
						self,
						surfaceColorConfig :: WaterSurfaceColor.SurfaceColorConfig,
						vertexIndex,
						height,
						paintSurfaceFoam,
						depthAlpha,
						baseLocal.X,
						baseLocal.Z,
						time,
						fresnelAlpha
					)
				end
			end
		end

		if usesSurfaceAppearanceTexture(self._Config) then
			if not surfaceBakeActive or not applyBakedSurfaceAppearanceTexture(self, time) then
				if not surfaceBakeInProgress then
					updateSurfaceAppearanceTexture(self, time, surfaceAppearanceWaterBuffer)
				end
			end
		end

		applyBakedSurfaceNormalMap(self, time)
	end

	function OceanTileClass:StepEffectBuffer(time: number)
		if self._Destroyed or self._MeshInvalid then
			return
		end

		if self._SeaSprayEmitter then
			self._SeaSprayEmitter.Rate = 0
		end

		local waterBuffer = self._WaterBuffer
		local physicsActive = waterBuffer ~= nil
			and self._StageDistance <= self._Config.PhysicsDistance
			and self._StageDetail > 0.05
		local surfaceEffectsActive = self._StageDistance <= self._Config.FoamDistance and self._StageDetail > 0.35

		if self._Config.StaticObstacleSplashEnabled
			and self._SplashEmitter ~= nil
			and surfaceEffectsActive
			and physicsActive
			and self._ObstacleImpactVertexCount > 0
			and self._ObstacleImpactVertices ~= nil
			and time - self._LastObstacleSplashTime >= self._Config.StaticObstacleSplashInterval
			and self._StageDistance <= self._Config.PhysicsDistance * 1.75
		then
			self._LastObstacleSplashTime = time
			local obstacleVertices = self._ObstacleImpactVertices

			if obstacleVertices == nil then
				return
			end

			local obstacleIndex = (math.floor(time / math.max(self._Config.StaticObstacleSplashInterval, 0.01)) % self._ObstacleImpactVertexCount) + 1
			local vertexIndex = buffer.readu16(obstacleVertices, obstacleImpactVertexOffset(obstacleIndex))
			local vertex = self._Vertices[vertexIndex]

			if vertex ~= nil then
				local ringDistance = math.max(
					math.abs(vertex.baseLocal.X - self._StageCameraLocal.X),
					math.abs(vertex.baseLocal.Z - self._StageCameraLocal.Z)
				)

				if ringDistance <= self._Config.Lod0Radius then
					local bakedDelta = sampleWaveLoop(self, vertexIndex, time)
					local worldPosition =
						self.BaseCFrame:PointToWorldSpace(vertex.baseLocal + bakedDelta * self._StageDetail * self._StageDistanceFactor)

					self:EmitSplash(worldPosition, 0.34, 3.5)
				end
			end
		end
	end

	function OceanTileClass:ApplyRenderBuffer()
		if self._Destroyed or self._MeshInvalid then
			return
		end

		if self._RenderTransformDirty then
			self.MeshPart.CFrame = self._RenderTargetCFrame
			syncReflectionMeshPart(self)
			self._RenderTransformDirty = false
		end

		local positions = self._RenderVertexPositions
		local indices = self._RenderVertexDirtyIndices

		if positions ~= nil and indices ~= nil and self._RenderVertexDirtyCount > 0 then
			for dirtyIndex = 0, self._RenderVertexDirtyCount - 1 do
				local vertexIndex = buffer.readu16(indices, dirtyIndex * RENDER_VERTEX_INDEX_BYTES)
				local vertex = self._Vertices[vertexIndex]

				if vertex == nil then
					continue
				end

				local offset = (vertexIndex - 1) * RENDER_VERTEX_POSITION_BYTES

				if
					not trySetVertexPosition(
						self,
						vertex.id,
						Vector3.new(
							buffer.readf32(positions, offset),
							buffer.readf32(positions, offset + 4),
							buffer.readf32(positions, offset + 8)
						)
					)
				then
					return
				end
			end

			self._RenderVertexDirtyCount = 0
		end

		if self._RenderSurfaceColorDirty and self._RenderSurfaceColorPixels ~= nil then
			local colors = self._RenderSurfaceColorPixels

			for vertexIndex, colorId in ipairs(self._SurfaceColorIds) do
				local offset = (vertexIndex - 1) * SURFACE_VERTEX_COLOR_BYTES

				if
					not trySetSurfaceColor(
						self,
						colorId,
						Color3.fromRGB(
							buffer.readu8(colors, offset),
							buffer.readu8(colors, offset + 1),
							buffer.readu8(colors, offset + 2)
						),
						buffer.readu8(colors, offset + 3) / 255
					)
				then
					return
				end
			end

			self._RenderSurfaceColorDirty = false
		end

		if self._RenderSurfaceTextureDirty and self._SurfaceImage ~= nil and self._RenderSurfaceTexturePixels ~= nil then
			local resolution = self._RenderSurfaceTextureResolution
			local pixels = self._RenderSurfaceTexturePixels
			local image = self._SurfaceImage :: EditableImage
			local ok, err = pcall(function()
				image:WritePixelsBuffer(Vector2.zero, Vector2.new(resolution, resolution), pixels)
			end)

			if not ok then
				self._SurfaceAppearanceSupported = false
				warnSurfaceColorUnsupported(self, err)
				return
			end

			self._RenderSurfaceTextureDirty = false
		end

		if self._RenderSurfaceNormalDirty and self._SurfaceNormalImage ~= nil and self._RenderSurfaceNormalPixels ~= nil then
			local resolution = self._RenderSurfaceNormalResolution
			local pixels = self._RenderSurfaceNormalPixels
			local image = self._SurfaceNormalImage :: EditableImage
			local ok, err = pcall(function()
				image:WritePixelsBuffer(Vector2.zero, Vector2.new(resolution, resolution), pixels)
			end)

			if not ok then
				self._SurfaceNormalSupported = false
				warnSurfaceColorUnsupported(self, err)
				return
			end

			self._RenderSurfaceNormalDirty = false
		end
	end

	function OceanTileClass:Update(time: number, camera: Camera?, renderVisible: boolean?)
		self:WriteExternalState(time, camera, renderVisible)
		self:StepLodBuffer()
		self:StepWaveBuffer(time)
		self:StepSurfaceBuffer(time)
		self:StepEffectBuffer(time)
		self:ApplyRenderBuffer()
	end

	function OceanTileClass:SetSpectrum(spectrum: WaveSpectrum.WaveSpectrum)
		self._Spectrum = spectrum
		resetWaveLoop(self)
	end

	function OceanTileClass:SetConfig(config: TileConfig)
		local previousConfig = self._Config
		local previousWaveLoopKey = getWaveLoopKey(previousConfig)
		local keepWaveLoop = self._WaveLoopPositions ~= nil
			and self._WaveLoopHeights ~= nil
			and getWaveLoopGeometryKey(previousConfig) == getWaveLoopGeometryKey(config)
			and previousWaveLoopKey == getWaveLoopKey(config)

		self._Config = config

		if keepWaveLoop then
			self._WaveLoopKey = getWaveLoopKey(config)
		else
			resetWaveLoop(self)
		end

		if keepWaveLoop then
			resetSurfaceBake(self)
		end

		self._RingLodIndices = nil
		self._RingLodCount = 0
		self._RingLodKey = ""
		self._RingLodDirty = true
		self._ObstacleImpactVertices = nil
		self._ObstacleImpactVertexCount = 0

		if usesSurfaceAppearanceTexture(config) or usesWaterNormalMap(config) then
			ensureSurfaceUVs(self)
		end

		local hasVertexColors = usesPaintVertices(config) and ensureSurfaceVertexColors(self)
		local hasSurfaceAppearance = ensureSurfaceAppearance(self)

		if shouldUseWhiteMeshColor(config, hasVertexColors, hasSurfaceAppearance) then
			self.MeshPart.Color = Color3.new(1, 1, 1)
		else
			self.MeshPart.Color = config.WaterColorBack
		end

		self.MeshPart.Transparency = config.Transparency
		self.MeshPart.Reflectance = config.Reflectance
		syncReflectionMeshPart(self)

		if config.InteractiveWavesEnabled and self._WaterBuffer == nil then
			self._WaterBuffer = createWaterBuffer(self.SourcePart, config)
		elseif not config.InteractiveWavesEnabled then
			self._WaterBuffer = nil
		end

		configureSeaSpray(self)
		configureSplashParticles(self)
	end

	function OceanTileClass:AddDrop(worldPosition: Vector3, radius: number, strength: number)
		local waterBuffer = self._WaterBuffer

		if waterBuffer == nil or not isWorldPositionNearCamera(worldPosition, self._Config.PhysicsDistance) then
			return
		end

		local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)

		waterBuffer:AddDrop(localPosition.X, localPosition.Z, radius, strength)
		self._InteractionWakeFrames = math.max(self._InteractionWakeFrames, 72)

		if math.abs(strength) >= 0.12 then
			self:EmitSplash(worldPosition, math.abs(strength), radius)
		end
	end

	function OceanTileClass:AddFoam(_worldPosition: Vector3, _radius: number, _amount: number)
	end

	function OceanTileClass:MoveSphere(oldWorldCenter: Vector3, newWorldCenter: Vector3, radius: number, strengthScale: number?)
		local waterBuffer = self._WaterBuffer

		if waterBuffer == nil or not isWorldPositionNearCamera(newWorldCenter, self._Config.PhysicsDistance) then
			return
		end

		local oldLocal = self.BaseCFrame:PointToObjectSpace(oldWorldCenter)
		local newLocal = self.BaseCFrame:PointToObjectSpace(newWorldCenter)

		waterBuffer:MoveSphere(oldLocal, newLocal, radius, strengthScale)
		self._InteractionWakeFrames = math.max(self._InteractionWakeFrames, 60)
	end

	function OceanTileClass:EmitSplash(worldPosition: Vector3, intensity: number, radius: number?, direction: Vector3?)
		local emitter = self._SplashEmitter

		if emitter == nil or self._SplashAttachment == nil or not self._Config.SplashParticlesEnabled then
			return
		end

		if self._Config.SplashParticleEmitScale <= 0 then
			return
		end

		local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
		local localDirection = if direction ~= nil
			then self.BaseCFrame:VectorToObjectSpace(direction)
			else Vector3.zero
		local emitUp = if localDirection.Magnitude > 0.001
			then (Vector3.yAxis + localDirection.Unit * 0.35).Unit
			else Vector3.yAxis
		local particleRadius = math.max(radius or 2, 0.5)
		local sizeScale = math.clamp(particleRadius * 0.28, 0.85, 8)
		local spread = math.clamp(12 + particleRadius * 0.55, 12, 34)
		local emitCount = math.clamp(
			math.round((0.65 + intensity * 0.35 + particleRadius * 0.05) * self._Config.SplashParticleEmitScale),
			1,
			2
		)

		local attachment = Instance.new("Attachment")
		attachment.Name = "SplashBurst"
		attachment.CFrame = cframeWithUp(localPosition, emitUp)
		attachment.Parent = self.MeshPart

		local burstEmitter = emitter:Clone()
		burstEmitter.Enabled = false
		burstEmitter.Rate = 0
		burstEmitter.Parent = attachment
		burstEmitter.SpreadAngle = Vector2.new(spread, spread)
		burstEmitter.Lifetime = NumberRange.new(0.28, 0.58)
		burstEmitter.Rotation = NumberRange.new(-18, 18)
		burstEmitter.RotSpeed = NumberRange.new(-28, 28)
		burstEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, sizeScale * 0.5),
			NumberSequenceKeypoint.new(0.22, sizeScale),
			NumberSequenceKeypoint.new(1, 0),
		})
		burstEmitter.Speed = NumberRange.new(
			math.max(self._Config.SplashParticleMinSpeed * 0.45, 1.2),
			math.max(self._Config.SplashParticleMaxSpeed * 0.45 + intensity * 1.4, 2.4)
		)
		burstEmitter:Emit(emitCount)

		task.delay(0.9, function()
			if attachment.Parent ~= nil then
				attachment:Destroy()
			end
		end)
	end

	function OceanTileClass:ContainsWorldPosition(worldPosition: Vector3): boolean
		local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
		local halfSize = self.SourcePart.Size * 0.5

		return math.abs(localPosition.X) <= halfSize.X and math.abs(localPosition.Z) <= halfSize.Z
	end

	function OceanTileClass:IsPointInWaterVolume(
		worldPosition: Vector3,
		time: number,
		surfacePadding: number?,
		bottomPadding: number?
	): boolean
		local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
		local halfSize = self.SourcePart.Size * 0.5

		if math.abs(localPosition.X) > halfSize.X or math.abs(localPosition.Z) > halfSize.Z then
			return false
		end

		local surfaceHeight = self:GetHeightAt(worldPosition, time, 1) + (surfacePadding or 0)
		local bottomLocalY = -getVolumeDepth(self, localPosition.X, localPosition.Z) - (bottomPadding or 0)
		local bottomWorld = self.BaseCFrame:PointToWorldSpace(Vector3.new(localPosition.X, bottomLocalY, localPosition.Z)).Y

		return worldPosition.Y <= surfaceHeight and worldPosition.Y >= bottomWorld
	end

	function OceanTileClass:GetBaseHeightAt(worldPosition: Vector3): number
		local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
		local onSurface = self.BaseCFrame:PointToWorldSpace(Vector3.new(localPosition.X, 0, localPosition.Z))

		return onSurface.Y
	end

	function OceanTileClass:GetHeightAt(worldPosition: Vector3, time: number, steps: number?): number
		local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
		local baseHeight = self.BaseCFrame:PointToWorldSpace(Vector3.new(localPosition.X, 0, localPosition.Z)).Y
		local waterBuffer = self._WaterBuffer
		local interactiveHeight = if waterBuffer ~= nil and waterBuffer:HasActivity()
			then waterBuffer:SampleHeight(localPosition.X, localPosition.Z)
			else 0

		return baseHeight + sampleBakedHeight(self, localPosition.X, localPosition.Z, time) + interactiveHeight
	end

	function OceanTileClass:GetNormalAt(worldPosition: Vector3, time: number): Vector3
		local localPosition = self.BaseCFrame:PointToObjectSpace(worldPosition)
		local sampleDistance = math.max(self._Config.VertexSpacing * 0.5, 1)
		local waterBuffer = self._WaterBuffer

		local function localHeight(localX: number, localZ: number): number
			local interactiveHeight = if waterBuffer ~= nil and waterBuffer:HasActivity()
				then waterBuffer:SampleHeight(localX, localZ)
				else 0

			return sampleBakedHeight(self, localX, localZ, time) + interactiveHeight
		end

		local x0 = localPosition.X - sampleDistance
		local x1 = localPosition.X + sampleDistance
		local z0 = localPosition.Z - sampleDistance
		local z1 = localPosition.Z + sampleDistance
		local px0 = Vector3.new(x0, localHeight(x0, localPosition.Z), localPosition.Z)
		local px1 = Vector3.new(x1, localHeight(x1, localPosition.Z), localPosition.Z)
		local pz0 = Vector3.new(localPosition.X, localHeight(localPosition.X, z0), z0)
		local pz1 = Vector3.new(localPosition.X, localHeight(localPosition.X, z1), z1)
		local normalLocal = (pz1 - pz0):Cross(px1 - px0)

		if normalLocal.Magnitude <= 0.001 then
			return self.BaseCFrame.UpVector
		end

		return self.BaseCFrame:VectorToWorldSpace(normalLocal.Unit).Unit
	end

	function OceanTileClass:GetVelocityAt(worldPosition: Vector3, time: number): Vector3
		local sampleDelta = 0.08
		local currentHeight = self:GetHeightAt(worldPosition, time, 1)
		local previousHeight = self:GetHeightAt(worldPosition, time - sampleDelta, 1)

		return Vector3.yAxis * ((currentHeight - previousHeight) / sampleDelta)
	end

	function OceanTileClass:IsInvalid(): boolean
		return self._Destroyed or self._MeshInvalid
	end

	function OceanTileClass:Destroy()
		self._Destroyed = true
		self._WaveLoopBakeId += 1
		self._SurfaceBakeId += 1
		self._SurfaceNormalBakeId += 1
		self._WaveLoopBaking = false
		self._SurfaceBakeBaking = false
		self._SurfaceNormalBakeBaking = false
		destroySurfaceAppearance(self)

		if self._HiddenSourcePart then
			self.SourcePart.LocalTransparencyModifier = self._SourceLocalTransparencyModifier
		end

		if self.MeshPart then
			self.MeshPart:Destroy()
		end

		if self.ReflectionMeshPart then
			self.ReflectionMeshPart:Destroy()
		end

		if self.EditableMesh then
			pcall(function()
				self.EditableMesh:Destroy()
			end)
		end
	end

	return OceanTileClass
end
