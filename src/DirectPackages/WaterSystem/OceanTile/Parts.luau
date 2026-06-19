--!strict

type TileConfig = any
type InternalOceanTile = any

return function(deps: any)
	local DEFAULT_MATERIAL = deps.DEFAULT_MATERIAL
	local cframeWithUp = deps.cframeWithUp
	local normalizeAssetId = deps.normalizeAssetId
	local readNumberAttribute = deps.readNumberAttribute

	local function configureMeshPart(meshPart: MeshPart, sourcePart: BasePart, config: TileConfig)
		meshPart.Name = "OceanTile_" .. sourcePart.Name
		meshPart.Anchored = true
		meshPart.CanCollide = false
		meshPart.CanTouch = false
		meshPart.CanQuery = false
		meshPart.CastShadow = false
		meshPart.Material = DEFAULT_MATERIAL
		meshPart.Color = config.WaterColorBack
		meshPart.Transparency = config.Transparency
		meshPart.Reflectance = config.Reflectance
	end

	local function getReflectionSize(meshPart: MeshPart): Vector3
		local size = meshPart.Size

		return Vector3.new(
			math.max(size.X - 0.1, 0.001),
			math.max(size.Y - 1, 0.001),
			math.max(size.Z - 0.1, 0.001)
		)
	end

	local function getReflectionCFrame(meshPart: MeshPart): CFrame
		local position = meshPart.Position

		return CFrame.new(position.X, position.Y - 0.5, position.Z)
	end

	local function configureReflectionMeshPart(meshPart: MeshPart, sourcePart: BasePart, renderMeshPart: MeshPart)
		meshPart.Name = "OceanTileReflection_" .. sourcePart.Name
		meshPart.Anchored = true
		meshPart.CanCollide = false
		meshPart.CanTouch = false
		meshPart.CanQuery = false
		meshPart.CastShadow = false
		meshPart.Material = Enum.Material.Glass
		meshPart.Transparency = 5
		meshPart.Reflectance = 0
		meshPart.Size = getReflectionSize(renderMeshPart)

		local highlight = Instance.new("Highlight")
		highlight.Name = "Highlight"
		highlight.Enabled = false
		highlight.Parent = meshPart
	end

	local function syncReflectionMeshPart(tile: InternalOceanTile)
		local size = getReflectionSize(tile.MeshPart)
		local cframe = getReflectionCFrame(tile.MeshPart)

		if tile.ReflectionMeshPart.Size ~= size then
			tile.ReflectionMeshPart.Size = size
		end

		if tile.ReflectionMeshPart.CFrame ~= cframe then
			tile.ReflectionMeshPart.CFrame = cframe
		end
	end

	local function configureSeaSpray(tile: InternalOceanTile)
		local meshPart = tile.MeshPart
		local textureId = normalizeAssetId(tile._Config.SeaSprayTextureId)

		if not tile._Config.SeaSprayEnabled or textureId == nil then
			if tile._SeaSprayEmitter then
				tile._SeaSprayEmitter.Enabled = false
				tile._SeaSprayEmitter.Rate = 0
			end

			return
		end

		local attachment = tile._SeaSprayAttachment

		if attachment == nil then
			attachment = Instance.new("Attachment")
			attachment.Name = "SeaSprayAttachment"
			attachment.Parent = meshPart
			tile._SeaSprayAttachment = attachment
		end

		local emitter = tile._SeaSprayEmitter

		if emitter == nil then
			emitter = Instance.new("ParticleEmitter")
			emitter.Name = "SeaSpray"
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Lifetime = NumberRange.new(0.45, 1.1)
			emitter.Rate = 0
			emitter.Speed = NumberRange.new(3, 10)
			emitter.SpreadAngle = Vector2.new(22, 22)
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-60, 60)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(0.35, 1.2),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.65, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.LightEmission = 0.25
			emitter.LockedToPart = false
			emitter.Parent = attachment
			tile._SeaSprayEmitter = emitter
		end

		emitter.Texture = textureId
		emitter.Rate = 0
		emitter.Color = ColorSequence.new(tile._Config.FoamColor)
		emitter.Enabled = true
	end

	local function configureSplashParticles(tile: InternalOceanTile)
		local meshPart = tile.MeshPart
		local textureId = normalizeAssetId(tile._Config.SplashParticleTextureId) or normalizeAssetId(tile._Config.SeaSprayTextureId)

		if not tile._Config.SplashParticlesEnabled then
			if tile._SplashEmitter then
				tile._SplashEmitter.Enabled = false
			end

			return
		end

		local attachment = tile._SplashAttachment

		if attachment == nil then
			attachment = Instance.new("Attachment")
			attachment.Name = "SplashAttachment"
			attachment.Parent = meshPart
			tile._SplashAttachment = attachment
		end

		local emitter = tile._SplashEmitter

		if emitter == nil then
			emitter = Instance.new("ParticleEmitter")
			emitter.Name = "ImpactSplash"
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Lifetime = NumberRange.new(0.28, 0.58)
			emitter.Rate = 0
			emitter.Speed = NumberRange.new(
				math.max(tile._Config.SplashParticleMinSpeed * 0.45, 1.2),
				math.max(tile._Config.SplashParticleMaxSpeed * 0.45, 2.4)
			)
			emitter.SpreadAngle = Vector2.new(18, 18)
			emitter.Rotation = NumberRange.new(-18, 18)
			emitter.RotSpeed = NumberRange.new(-28, 28)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.65),
				NumberSequenceKeypoint.new(0.22, 2.2),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.55, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.LightEmission = 0.18
			emitter.LockedToPart = false
			emitter.Parent = attachment
			tile._SplashEmitter = emitter
		end

		if textureId ~= nil then
			emitter.Texture = textureId
		end

		emitter.Lifetime = NumberRange.new(0.28, 0.58)
		emitter.Speed = NumberRange.new(
			math.max(tile._Config.SplashParticleMinSpeed * 0.45, 1.2),
			math.max(tile._Config.SplashParticleMaxSpeed * 0.45, 2.4)
		)
		emitter.SpreadAngle = Vector2.new(18, 18)
		emitter.Rotation = NumberRange.new(-18, 18)
		emitter.RotSpeed = NumberRange.new(-28, 28)
		emitter.Color = ColorSequence.new(tile._Config.FoamColor)
		emitter.Enabled = true
	end


	return {
		configureMeshPart = configureMeshPart,
		getReflectionCFrame = getReflectionCFrame,
		configureReflectionMeshPart = configureReflectionMeshPart,
		syncReflectionMeshPart = syncReflectionMeshPart,
		configureSeaSpray = configureSeaSpray,
		configureSplashParticles = configureSplashParticles,
	}
end
