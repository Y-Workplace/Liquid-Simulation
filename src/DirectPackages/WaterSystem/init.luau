--!strict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local OceanTile = require(script.OceanTile)
local RuntimePanel = require(script.RuntimePanel)
local WaveSpectrum = require(script.WaveSpectrum)
local Types = require(script.Types)
local Defaults = require(script.Defaults)
local AttributeUtils = require(script.AttributeUtils)
local WaterConfig = require(script.WaterConfig)
local WaterSpatial = require(script.WaterSpatial)
local RuntimeLoops = require(script.RuntimeLoops)

export type WaterSystemOptions = Types.WaterSystemOptions
export type WaterSystem = Types.WaterSystem

type InternalWaterSystem = Types.InternalWaterSystem

local DEFAULT_OPTIONS = Defaults.DEFAULT_OPTIONS :: any
local cloneOptions = Defaults.cloneOptions
local readNumberAttribute = AttributeUtils.readNumberAttribute
local readBooleanAttribute = AttributeUtils.readBooleanAttribute
local resolveConfig = WaterConfig.resolveConfig
local resolveCascades = WaterConfig.resolveCascades
local resolveSpectrumOptions = WaterConfig.resolveSpectrumOptions
local isWaterPart = WaterSpatial.isWaterPart
local distanceToPart = WaterSpatial.distanceToPart

local WaterSystemClass = {}
WaterSystemClass.__index = WaterSystemClass

local activeSystem: InternalWaterSystem? = nil
local function disconnectAll(connections: { RBXScriptConnection }?)
	if connections == nil then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
end

local function getLoadDistance(
	sourceFolder: Instance?,
	options: WaterSystemOptions,
	config: OceanTile.TileConfig
): number
	local fallback = options.LoadDistance or config.MaxDistance

	if sourceFolder == nil then
		return fallback
	end

	return math.max(readNumberAttribute(sourceFolder, "OceanLoadDistance", fallback), 0)
end

local function getUnloadDistance(
	sourceFolder: Instance?,
	options: WaterSystemOptions,
	config: OceanTile.TileConfig
): number
	local loadDistance = getLoadDistance(sourceFolder, options, config)
	local fallback = options.UnloadDistance or math.max(loadDistance + 128, loadDistance * 1.15)

	if sourceFolder == nil then
		return fallback
	end

	return math.max(readNumberAttribute(sourceFolder, "OceanUnloadDistance", fallback), loadDistance)
end

local function getLodScanInterval(sourceFolder: Instance?, options: WaterSystemOptions): number
	local fallback = options.LodScanInterval or DEFAULT_OPTIONS.LodScanInterval

	if sourceFolder == nil then
		return fallback
	end

	return math.max(readNumberAttribute(sourceFolder, "OceanLodScanInterval", fallback), 0.05)
end

local function readFolderBoolean(sourceFolder: Instance?, name: string, fallback: boolean): boolean
	if sourceFolder == nil then
		return fallback
	end

	return readBooleanAttribute(sourceFolder, name, fallback)
end

local function readFolderNumber(sourceFolder: Instance?, name: string, fallback: number): number
	if sourceFolder == nil then
		return fallback
	end

	return readNumberAttribute(sourceFolder, name, fallback)
end

local function getTileUpdateRate(
	sourceFolder: Instance?,
	options: WaterSystemOptions,
	config: OceanTile.TileConfig,
	distance: number
): number
	local globalRate = if sourceFolder
		then readNumberAttribute(
			sourceFolder,
			"OceanUpdatesPerSecond",
			options.UpdatesPerSecond or DEFAULT_OPTIONS.UpdatesPerSecond
		)
		else options.UpdatesPerSecond or DEFAULT_OPTIONS.UpdatesPerSecond
	local nearDistanceFallback = options.NearUpdateDistance or math.max(config.FadeStartDistance * 0.5, 64)
	local midDistanceFallback = options.MidUpdateDistance or math.max(config.FadeStartDistance, nearDistanceFallback)
	local nearDistance = if sourceFolder
		then readNumberAttribute(sourceFolder, "OceanNearUpdateDistance", nearDistanceFallback)
		else nearDistanceFallback
	local midDistance = if sourceFolder
		then readNumberAttribute(sourceFolder, "OceanMidUpdateDistance", midDistanceFallback)
		else midDistanceFallback
	local nearRate = if sourceFolder
		then readNumberAttribute(sourceFolder, "OceanNearUpdatesPerSecond", options.NearUpdatesPerSecond or globalRate)
		else options.NearUpdatesPerSecond or globalRate
	local midRate = if sourceFolder
		then readNumberAttribute(
			sourceFolder,
			"OceanMidUpdatesPerSecond",
			options.MidUpdatesPerSecond or DEFAULT_OPTIONS.MidUpdatesPerSecond
		)
		else options.MidUpdatesPerSecond or DEFAULT_OPTIONS.MidUpdatesPerSecond
	local farRate = if sourceFolder
		then readNumberAttribute(
			sourceFolder,
			"OceanFarUpdatesPerSecond",
			options.FarUpdatesPerSecond or DEFAULT_OPTIONS.FarUpdatesPerSecond
		)
		else options.FarUpdatesPerSecond or DEFAULT_OPTIONS.FarUpdatesPerSecond

	if distance <= nearDistance then
		return math.max(nearRate, 0)
	end

	if distance <= midDistance then
		return math.max(midRate, 0)
	end

	return math.max(farRate, 0)
end

local function cloneTileConfig(config: OceanTile.TileConfig): OceanTile.TileConfig
	local result = {}

	for key, value in pairs(config :: any) do
		(result :: any)[key] = value
	end

	return result :: OceanTile.TileConfig
end

local function getChunkLodLevel(sourceFolder: Instance?, options: WaterSystemOptions, distance: number): number
	local enabled = readFolderBoolean(sourceFolder, "OceanChunkLodEnabled", options.ChunkLodEnabled ~= false)

	if not enabled then
		return 0
	end

	local lod0Distance = readFolderNumber(
		sourceFolder,
		"OceanChunkLod0Distance",
		options.ChunkLod0Distance or DEFAULT_OPTIONS.ChunkLod0Distance
	)
	local lod1Distance = readFolderNumber(
		sourceFolder,
		"OceanChunkLod1Distance",
		options.ChunkLod1Distance or DEFAULT_OPTIONS.ChunkLod1Distance
	)
	local lod2Distance = readFolderNumber(
		sourceFolder,
		"OceanChunkLod2Distance",
		options.ChunkLod2Distance or DEFAULT_OPTIONS.ChunkLod2Distance
	)

	if distance <= lod0Distance then
		return 0
	end

	if distance <= lod1Distance then
		return 1
	end

	if distance <= lod2Distance then
		return 2
	end

	return 3
end

local function getStableChunkLodLevel(
	sourceFolder: Instance?,
	options: WaterSystemOptions,
	distance: number,
	currentLod: number?
): number
	local idealLod = getChunkLodLevel(sourceFolder, options, distance)

	if currentLod == nil then
		return idealLod
	end

	local hysteresis = math.max(
		readFolderNumber(
			sourceFolder,
			"OceanChunkLodHysteresis",
			options.ChunkLodHysteresis or DEFAULT_OPTIONS.ChunkLodHysteresis
		),
		0
	)

	if hysteresis <= 0 then
		return idealLod
	end

	local thresholds = {
		readFolderNumber(
			sourceFolder,
			"OceanChunkLod0Distance",
			options.ChunkLod0Distance or DEFAULT_OPTIONS.ChunkLod0Distance
		),
		readFolderNumber(
			sourceFolder,
			"OceanChunkLod1Distance",
			options.ChunkLod1Distance or DEFAULT_OPTIONS.ChunkLod1Distance
		),
		readFolderNumber(
			sourceFolder,
			"OceanChunkLod2Distance",
			options.ChunkLod2Distance or DEFAULT_OPTIONS.ChunkLod2Distance
		),
	}
	local stableLod = math.clamp(math.round(currentLod), 0, 3)

	while stableLod < idealLod do
		local threshold = thresholds[stableLod + 1]

		if threshold == nil or distance <= threshold + hysteresis then
			break
		end

		stableLod += 1
	end

	while stableLod > idealLod do
		local threshold = thresholds[stableLod]

		if threshold == nil or distance >= threshold - hysteresis then
			break
		end

		stableLod -= 1
	end

	return stableLod
end

local function getChunkLodResolution(
	sourceFolder: Instance?,
	options: WaterSystemOptions,
	lodLevel: number,
	maxResolution: number
): number
	local attrName = if lodLevel == 0
		then "OceanChunkLod0Resolution"
		elseif lodLevel == 1 then "OceanChunkLod1Resolution"
		elseif lodLevel == 2 then "OceanChunkLod2Resolution"
		else "OceanChunkLod3Resolution"
	local fallback = if lodLevel == 0
		then options.ChunkLod0Resolution or DEFAULT_OPTIONS.ChunkLod0Resolution
		elseif lodLevel == 1 then options.ChunkLod1Resolution or DEFAULT_OPTIONS.ChunkLod1Resolution
		elseif lodLevel == 2 then options.ChunkLod2Resolution or DEFAULT_OPTIONS.ChunkLod2Resolution
		else options.ChunkLod3Resolution or DEFAULT_OPTIONS.ChunkLod3Resolution

	return math.clamp(math.round(readFolderNumber(sourceFolder, attrName, fallback)), 2, maxResolution)
end

local function getRenderConfigForSource(
	sourceFolder: Instance?,
	options: WaterSystemOptions,
	config: OceanTile.TileConfig,
	sourcePart: BasePart,
	cameraPosition: Vector3?
): (OceanTile.TileConfig, number)
	if cameraPosition == nil then
		return config, 0
	end

	local distance = distanceToPart(sourcePart, cameraPosition)
	local lodLevel = getChunkLodLevel(sourceFolder, options, distance)
	local renderConfig = cloneTileConfig(config)
	renderConfig.Resolution = getChunkLodResolution(sourceFolder, options, lodLevel, config.Resolution)

	return renderConfig, lodLevel
end

local function isPartInCameraView(sourcePart: BasePart, camera: Camera?, padding: number): boolean
	if camera == nil then
		return true
	end

	local viewport = camera.ViewportSize

	if viewport.X <= 0 or viewport.Y <= 0 then
		return true
	end

	local center = sourcePart.Position
	local radius = sourcePart.Size.Magnitude * 0.5 + padding
	local screenPoint, onScreen = camera:WorldToViewportPoint(center)

	if screenPoint.Z < -radius then
		return false
	end

	if onScreen then
		return true
	end

	local depth = math.max(screenPoint.Z, 1)
	local fovScale = (viewport.Y * 0.5) / math.tan(math.rad(camera.FieldOfView) * 0.5)
	local screenRadius = radius / depth * fovScale

	return screenPoint.X >= -screenRadius
		and screenPoint.X <= viewport.X + screenRadius
		and screenPoint.Y >= -screenRadius
		and screenPoint.Y <= viewport.Y + screenRadius
end

function WaterSystemClass:_EnsureContainer()
	local existing = workspace:FindFirstChild(self._Options.GeneratedFolderName or "GeneratedOcean")

	if existing and existing:IsA("Folder") then
		self._Container = existing
		return
	end

	local container = Instance.new("Folder")
	container.Name = self._Options.GeneratedFolderName or "GeneratedOcean"
	container.Parent = workspace
	self._Container = container
end

function WaterSystemClass:_DisconnectSource()
	if self._SourceAddedConnection then
		self._SourceAddedConnection:Disconnect()
		self._SourceAddedConnection = nil
	end

	if self._SourceRemovingConnection then
		self._SourceRemovingConnection:Disconnect()
		self._SourceRemovingConnection = nil
	end

	disconnectAll(self._FolderAttributeConnections)
	table.clear(self._FolderAttributeConnections)
end

function WaterSystemClass:_DestroyBakeActor()
	if self._BakeResultConnection then
		self._BakeResultConnection:Disconnect()
		self._BakeResultConnection = nil
	end

	if self._BakeActor then
		self._BakeActor:Destroy()
		self._BakeActor = nil
	end

	self._PendingBakeOptions = nil
	self._PendingBakeRebuildTiles = false
end

function WaterSystemClass:_EnsureBakeActor()
	if self._BakeActor ~= nil then
		return
	end

	local localPlayer = Players.LocalPlayer

	if localPlayer == nil then
		return
	end

	local playerScripts = localPlayer:FindFirstChildOfClass("PlayerScripts")

	if playerScripts == nil then
		local found = localPlayer:FindFirstChild("PlayerScripts")

		if found and found:IsA("PlayerScripts") then
			playerScripts = found
		end
	end

	local workerTemplate = script:FindFirstChild("WaveBakeWorker")

	if playerScripts == nil or workerTemplate == nil or not workerTemplate:IsA("LocalScript") then
		return
	end

	local actor = Instance.new("Actor")
	actor.Name = "WaterSystemBakeActor"

	local resultEvent = Instance.new("BindableEvent")
	resultEvent.Name = "WaveBakeResult"
	resultEvent.Parent = actor

	local worker = workerTemplate:Clone()
	worker.Parent = actor
	actor.Parent = playerScripts

	self._BakeActor = actor
	self._BakeResultConnection = resultEvent.Event:Connect(function(requestId: number, ok: boolean, result: any)
		if requestId ~= self._BakeRequestId then
			return
		end

		if not ok then
			warn("[WaterSystem] Parallel wave bake failed: " .. tostring(result))
			return
		end

		local bake = result :: WaveSpectrum.BakedSpectrum
		local options = self._PendingBakeOptions

		if options == nil then
			return
		end

		self:_ApplySpectrumBake(bake, options, self._PendingBakeRebuildTiles)
	end)
end

function WaterSystemClass:_RequestParallelBake(
	cascades: { WaveSpectrum.CascadeConfig },
	options: WaveSpectrum.SpectrumOptions,
	rebuildTiles: boolean
): boolean
	self:_EnsureBakeActor()

	local actor = self._BakeActor

	if actor == nil or actor:GetAttribute("Ready") ~= true then
		return false
	end

	self._BakeRequestId += 1
	self._PendingBakeOptions = options
	self._PendingBakeRebuildTiles = rebuildTiles
	actor:SendMessage("BakeSpectrum", self._BakeRequestId, cascades, options)

	return true
end

function WaterSystemClass:_ApplySourceVisibility(sourcePart: BasePart)
	if self._SourceLocalTransparency[sourcePart] == nil then
		self._SourceLocalTransparency[sourcePart] = sourcePart.LocalTransparencyModifier
	end

	local config = self:_GetConfigForSource(sourcePart) or self._Config
	local hideSource = if config
		then readBooleanAttribute(sourcePart, "OceanHideSourcePart", config.HideSourceParts)
		else true

	if hideSource then
		sourcePart.LocalTransparencyModifier = 1
	else
		sourcePart.LocalTransparencyModifier = self._SourceLocalTransparency[sourcePart]
			or sourcePart.LocalTransparencyModifier
	end
end

function WaterSystemClass:_RestoreSourceVisibility(sourcePart: BasePart)
	local originalTransparency = self._SourceLocalTransparency[sourcePart]

	if originalTransparency ~= nil then
		sourcePart.LocalTransparencyModifier = originalTransparency
	end

	self._SourceLocalTransparency[sourcePart] = nil
end

function WaterSystemClass:_TrackSourcePart(sourcePart: BasePart)
	if self._SourceParts[sourcePart] then
		self:_ApplySourceVisibility(sourcePart)
		return
	end

	self._SourceParts[sourcePart] = true
	self:_ApplySourceVisibility(sourcePart)
end

function WaterSystemClass:_UntrackSourcePart(sourcePart: BasePart)
	self:_RemoveTile(sourcePart)
	self._SourceParts[sourcePart] = nil
	self:_RestoreSourceVisibility(sourcePart)
end

function WaterSystemClass:_RemoveTile(sourcePart: BasePart)
	local tile = self._Tiles[sourcePart]

	if tile ~= nil then
		tile:Destroy()
		self._Tiles[sourcePart] = nil
	end

	disconnectAll(self._TileConnections[sourcePart])
	self._TileConnections[sourcePart] = nil
	self._Pending[sourcePart] = nil
	self._TileUpdateTimes[sourcePart] = nil
	self._TileRenderLods[sourcePart] = nil
	self._TileRenderLodChangeTimes[sourcePart] = nil
end

function WaterSystemClass:_RebuildTile(sourcePart: BasePart)
	local lodChangeTime = self._TileRenderLodChangeTimes[sourcePart]

	self:_RemoveTile(sourcePart)
	self._TileRenderLodChangeTimes[sourcePart] = lodChangeTime

	if self._Running and isWaterPart(sourcePart, self._SourceFolder, self._Container) then
		self:_TryAddTile(sourcePart)
	end
end

function WaterSystemClass:_RebuildAllTiles()
	local sourceFolder = self._SourceFolder

	if sourceFolder == nil then
		return
	end

	local sources = {}

	for sourcePart, tile in pairs(self._Tiles) do
		table.insert(sources, sourcePart)
	end

	for _, sourcePart in ipairs(sources) do
		self:_RemoveTile(sourcePart)
	end

	for _, descendant in ipairs(sourceFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			self:_TrackSourcePart(descendant)
		end
	end

	self:_RefreshSourceTiles(workspace.CurrentCamera)
end

function WaterSystemClass:_ApplySpectrumBake(
	bake: WaveSpectrum.BakedSpectrum,
	options: WaveSpectrum.SpectrumOptions,
	rebuildTiles: boolean?
)
	self._Spectrum = WaveSpectrum.fromBake(bake, options)

	if self._SourceFolder ~= nil and self._Config ~= nil then
		self._OceanConfigs[self._SourceFolder] = self._Config
		self._OceanSpectra[self._SourceFolder] = self._Spectrum
	end

	if rebuildTiles == true then
		self:_RebuildAllTiles()
		return
	end

	local camera = workspace.CurrentCamera
	local cameraPosition = if camera ~= nil then camera.CFrame.Position else nil

	for sourcePart, tile in pairs(self._Tiles) do
		local config = self:_GetConfigForSource(sourcePart)

		if config ~= nil then
			local oceanFolder = self:_GetOceanFolderForSource(sourcePart) or self._SourceFolder
			local renderConfig, renderLod =
				getRenderConfigForSource(oceanFolder, self._Options, config, sourcePart, cameraPosition)

			self._TileRenderLods[sourcePart] = renderLod
			tile:SetConfig(renderConfig)
		end

		local spectrum = self:_GetSpectrumForSource(sourcePart)

		if spectrum ~= nil then
			tile:SetSpectrum(spectrum)
		end
	end

	self:_RefreshSourceTiles(workspace.CurrentCamera)
end

function WaterSystemClass:_RefreshConfigsFromAttributes(rebuildTiles: boolean?)
	local sourceFolder = self._SourceFolder

	if sourceFolder == nil then
		return
	end

	self._Config = resolveConfig(sourceFolder, self._Options)
	table.clear(self._OceanConfigs)

	if rebuildTiles == true then
		self:_RebuildAllTiles()
		return
	end

	local camera = workspace.CurrentCamera
	local cameraPosition = if camera ~= nil then camera.CFrame.Position else nil

	for sourcePart, tile in pairs(self._Tiles) do
		local config = self:_GetConfigForSource(sourcePart)

		if config == nil then
			continue
		end

		local oceanFolder = self:_GetOceanFolderForSource(sourcePart) or self._SourceFolder
		local renderConfig, renderLod =
			getRenderConfigForSource(oceanFolder, self._Options, config, sourcePart, cameraPosition)

		self._TileRenderLods[sourcePart] = renderLod
		tile:SetConfig(renderConfig)
	end

	self:_RefreshSourceTiles(workspace.CurrentCamera)
end

function WaterSystemClass:RefreshFromAttributes(rebuildTiles: boolean?)
	local sourceFolder = self._SourceFolder

	if sourceFolder == nil then
		return
	end

	self._Config = resolveConfig(sourceFolder, self._Options)
	table.clear(self._OceanConfigs)
	table.clear(self._OceanSpectra)
	local cascades = resolveCascades(sourceFolder)
	local spectrumOptions = resolveSpectrumOptions(sourceFolder, self._Options)

	if self:_RequestParallelBake(cascades, spectrumOptions, rebuildTiles == true) then
		return
	end

	self:_ApplySpectrumBake(WaveSpectrum.Bake(cascades, spectrumOptions), spectrumOptions, rebuildTiles)
end

function WaterSystemClass:_GetOceanFolderForSource(sourcePart: BasePart): Instance?
	local sourceFolder = self._SourceFolder

	if sourceFolder == nil then
		return nil
	end

	local current = sourcePart.Parent

	while current ~= nil and current ~= sourceFolder do
		if current:IsA("Folder") and current.Parent == sourceFolder then
			return current
		end

		current = current.Parent
	end

	return sourceFolder
end

function WaterSystemClass:_GetConfigForSource(sourcePart: BasePart): OceanTile.TileConfig?
	local oceanFolder = self:_GetOceanFolderForSource(sourcePart)

	if oceanFolder == nil then
		return nil
	end

	if oceanFolder == self._SourceFolder then
		return self._Config
	end

	local cached = self._OceanConfigs[oceanFolder]

	if cached ~= nil then
		return cached
	end

	local config = resolveConfig(oceanFolder, self._Options)

	self._OceanConfigs[oceanFolder] = config
	return config
end

function WaterSystemClass:_GetSpectrumForSource(sourcePart: BasePart): WaveSpectrum.WaveSpectrum?
	local oceanFolder = self:_GetOceanFolderForSource(sourcePart)

	if oceanFolder == nil then
		return nil
	end

	if oceanFolder == self._SourceFolder then
		return self._Spectrum
	end

	local cached = self._OceanSpectra[oceanFolder]

	if cached ~= nil then
		return cached
	end

	local spectrumOptions = resolveSpectrumOptions(oceanFolder, self._Options)
	local spectrum = WaveSpectrum.new(resolveCascades(oceanFolder), spectrumOptions)

	self._OceanSpectra[oceanFolder] = spectrum
	return spectrum
end

function WaterSystemClass:_BindTileSource(sourcePart: BasePart)
	disconnectAll(self._TileConnections[sourcePart])

	self._TileConnections[sourcePart] = {
		sourcePart:GetPropertyChangedSignal("Size"):Connect(function()
			self:_RebuildTile(sourcePart)
		end),
		sourcePart:GetAttributeChangedSignal("OceanResolution"):Connect(function()
			self:_RebuildTile(sourcePart)
		end),
		sourcePart:GetAttributeChangedSignal("OceanVertexSpacing"):Connect(function()
			self:_RebuildTile(sourcePart)
		end),
		sourcePart:GetAttributeChangedSignal("OceanSurfaceOffset"):Connect(function()
			self:_RebuildTile(sourcePart)
		end),
		sourcePart:GetAttributeChangedSignal("OceanHideSourcePart"):Connect(function()
			self:_RebuildTile(sourcePart)
		end),
	}
end

function WaterSystemClass:_ShouldLoadSourcePart(sourcePart: BasePart, camera: Camera?): boolean
	local config = self:_GetConfigForSource(sourcePart)

	if config == nil or camera == nil then
		return true
	end

	local distance = distanceToPart(sourcePart, camera.CFrame.Position)
	local oceanFolder = self:_GetOceanFolderForSource(sourcePart) or self._SourceFolder
	return distance <= getLoadDistance(oceanFolder, self._Options, config)
end

function WaterSystemClass:_TryAddTile(instance: Instance)
	local sourceFolder = self._SourceFolder
	local container = self._Container

	if sourceFolder == nil or container == nil then
		return
	end

	if not isWaterPart(instance, sourceFolder, container) then
		return
	end

	local sourcePart = instance :: BasePart
	local config = self:_GetConfigForSource(sourcePart)
	local spectrum = self:_GetSpectrumForSource(sourcePart)

	if config == nil or spectrum == nil then
		return
	end

	self:_TrackSourcePart(sourcePart)

	if self._Tiles[sourcePart] ~= nil or self._Pending[sourcePart] then
		return
	end

	if not self:_ShouldLoadSourcePart(sourcePart, workspace.CurrentCamera) then
		return
	end

	self._Pending[sourcePart] = true

	task.spawn(function()
		if not self._Running or not isWaterPart(sourcePart, self._SourceFolder, self._Container) then
			self._Pending[sourcePart] = nil
			return
		end

		local camera = workspace.CurrentCamera
		local cameraPosition = if camera ~= nil then camera.CFrame.Position else nil
		local oceanFolder = self:_GetOceanFolderForSource(sourcePart) or sourceFolder
		local renderConfig, renderLod =
			getRenderConfigForSource(oceanFolder, self._Options, config, sourcePart, cameraPosition)
		local tile, err = OceanTile.new(sourcePart, container, spectrum, renderConfig)
		self._Pending[sourcePart] = nil

		if tile == nil then
			warn("[WaterSystem] Failed to create ocean tile for " .. sourcePart:GetFullName() .. ": " .. tostring(err))
			return
		end

		if not self._Running or not isWaterPart(sourcePart, self._SourceFolder, self._Container) then
			tile:Destroy()
			return
		end

		self._Tiles[sourcePart] = tile
		self._TileRenderLods[sourcePart] = renderLod
		self:_BindTileSource(sourcePart)
	end)
end

function WaterSystemClass:_RefreshSourceTiles(camera: Camera?)
	local sourceFolder = self._SourceFolder

	if sourceFolder == nil then
		return
	end

	local cameraPosition = if camera then camera.CFrame.Position else nil

	for sourcePart in pairs(self._SourceParts) do
		if not isWaterPart(sourcePart, sourceFolder, self._Container) then
			self:_UntrackSourcePart(sourcePart)
			continue
		end

		local config = self:_GetConfigForSource(sourcePart)

		if config == nil then
			continue
		end

		local oceanFolder = self:_GetOceanFolderForSource(sourcePart) or sourceFolder
		local unloadDistance = getUnloadDistance(oceanFolder, self._Options, config)

		self:_ApplySourceVisibility(sourcePart)

		if cameraPosition == nil then
			self:_TryAddTile(sourcePart)
			continue
		end

		local distance = distanceToPart(sourcePart, cameraPosition)

		if self._Tiles[sourcePart] ~= nil then
			if distance > unloadDistance then
				self:_RemoveTile(sourcePart)
			else
				local currentLod = self._TileRenderLods[sourcePart]
				local lodLevel = getStableChunkLodLevel(oceanFolder, self._Options, distance, currentLod)
				local switchCooldown = math.max(
					readFolderNumber(
						oceanFolder,
						"OceanChunkLodSwitchCooldown",
						self._Options.ChunkLodSwitchCooldown or DEFAULT_OPTIONS.ChunkLodSwitchCooldown
					),
					0
				)
				local lastSwitchTime = self._TileRenderLodChangeTimes[sourcePart] or -math.huge

				if
					currentLod ~= lodLevel
					and not self._Pending[sourcePart]
					and self._Time - lastSwitchTime >= switchCooldown
				then
					self._TileRenderLodChangeTimes[sourcePart] = self._Time
					self:_RebuildTile(sourcePart)
				end
			end
		elseif distance <= getLoadDistance(oceanFolder, self._Options, config) then
			self:_TryAddTile(sourcePart)
		end
	end
end

function WaterSystemClass:_AttachFolder(folder: Instance)
	self:_DisconnectSource()
	self._SourceFolder = folder
	self:RefreshFromAttributes(false)

	if self._Panel then
		self._Panel:SetFolder(folder)
	end

	self:_EnsureContainer()

	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			self:_TrackSourcePart(descendant)
		end
	end

	self:_RefreshSourceTiles(workspace.CurrentCamera)

	local rebuildAttributes = {
		"OceanResolution",
		"OceanVertexSpacing",
		"OceanVolumeEnabled",
		"OceanVolumeSideSpacing",
		"OceanVolumeVerticalSegments",
		"OceanVolumeBottomResolution",
		"OceanVolumeWaveScale",
		"OceanChunkLodEnabled",
		"OceanChunkLod0Distance",
		"OceanChunkLod1Distance",
		"OceanChunkLod2Distance",
		"OceanChunkLod0Resolution",
		"OceanChunkLod1Resolution",
		"OceanChunkLod2Resolution",
		"OceanChunkLod3Resolution",
		"OceanWaterColor",
		"OceanWaterTintColor",
		"OceanFoamColor",
		"OceanWaterVertexAlpha",
		"OceanFoamVertexAlpha",
		"OceanInteractiveWavesEnabled",
		"OceanInteractiveResolution",
		"OceanInteractiveDamping",
		"OceanInteractiveMaxHeight",
		"OceanInteractiveMaxVelocity",
		"OceanInteractiveMoveSphereScale",
		"OceanTransparency",
		"OceanReflectance",
		"OceanHideSourceParts",
		"OceanFoamTextureId",
		"OceanFoamTextureFromVerticesEnabled",
		"OceanFoamTextureResolution",
		"OceanFoamTextureTransparency",
		"OceanFoamTextureStudsPerTile",
		"OceanFoamNoiseSize",
		"OceanFoamNoiseSeed",
		"OceanEnableSeaSpray",
		"OceanSeaSprayTextureId",
		"OceanSeaSprayRate",
		"OceanDepthMapEnabled",
		"OceanDepthMapResolution",
		"OceanMaxRaycastDepth",
		"OceanFallbackDepth",
		"OceanObstacleMapEnabled",
		"OceanObstacleRootName",
		"OceanBakeAnchoredObstacles",
		"OceanObstacleMapResolution",
		"OceanObstacleInfluenceRadius",
		"OceanObstacleRayHeight",
		"OceanObstacleRayDepth",
		"OceanFoamBufferResolution",
	}

	for _, attributeName in ipairs(rebuildAttributes) do
		table.insert(
			self._FolderAttributeConnections,
			folder:GetAttributeChangedSignal(attributeName):Connect(function()
				self:RefreshFromAttributes(true)
			end)
		)
	end

	local refreshAttributes = {
		"OceanMaxDistance",
		"OceanFadeStartDistance",
		"OceanLoadDistance",
		"OceanUnloadDistance",
		"OceanLodScanInterval",
		"OceanNearUpdateDistance",
		"OceanMidUpdateDistance",
		"OceanNearUpdatesPerSecond",
		"OceanMidUpdatesPerSecond",
		"OceanFarUpdatesPerSecond",
		"OceanPhysicsDistance",
		"OceanFoamDistance",
		"OceanInteractiveSimulationIterations",
		"OceanInteractiveFoamStrength",
		"OceanInteractiveFoamSlopeThreshold",
		"OceanInteractiveFoamVelocityThreshold",
		"OceanInteractiveLodDissipation",
		"OceanChunkLodHysteresis",
		"OceanChunkLodSwitchCooldown",
		"OceanViewCullingEnabled",
		"OceanViewCullingPadding",
		"OceanFoamVertexBoost",
		"OceanFoamNoiseInfluence",
		"OceanShallowWaveScale",
		"OceanDeepWaveScale",
		"OceanShoreFoamStrength",
		"OceanObstacleWaveDamping",
		"OceanObstacleFoamStrength",
		"OceanFoamBufferEnabled",
		"OceanFoamBufferDecay",
		"OceanFoamBufferGrowth",
		"OceanFoamTextureUpdateInterval",
		"OceanCrestFoamStrength",
		"OceanHighWaveFoamThreshold",
		"OceanHighWaveFoamStrength",
		"OceanShallowDepth",
		"OceanLakeDepth",
		"OceanOceanDepth",
		"OceanWaveLoopFrames",
		"OceanWaveLoopDuration",
		"OceanFarWaveDetail",
		"OceanLod0Radius",
		"OceanLod1Radius",
		"OceanLod2Radius",
		"OceanLodRecenterDistance",
		"OceanMidLodVertexStep",
		"OceanFarLodVertexStep",
		"OceanExtremeLodVertexStep",
		"OceanStaticObstacleSplashEnabled",
		"OceanStaticObstacleSplashInterval",
		"OceanSplashParticlesEnabled",
		"OceanSplashParticleTextureId",
		"OceanSplashParticleMinSpeed",
		"OceanSplashParticleMaxSpeed",
		"OceanSplashParticleEmitScale",
		"OceanPhysicalInteractionEnabled",
		"OceanPhysicalScanInterval",
		"OceanPhysicalMaxTrackedParts",
		"OceanPhysicalMinSpeed",
		"OceanPhysicalImpactSpeed",
		"OceanPhysicalRadiusScale",
		"OceanPlayerInteractionEnabled",
		"OceanBuoyancyEnabled",
		"OceanBuoyancyStrength",
		"OceanBuoyancyDamping",
		"OceanBuoyancyLinearDrag",
		"OceanBuoyancyAngularDrag",
		"OceanBuoyancyScanInterval",
		"OceanBuoyancyMaxParts",
		"OceanPlayerSurfaceFloatEnabled",
		"OceanPlayerSurfaceInfluenceDepth",
		"OceanPlayerSurfaceSmoothness",
		"OceanPlayerSurfaceOffset",
		"OceanPlayerSurfaceMaxVerticalSpeed",
		"OceanPlayerSwimAnimationEnabled",
		"OceanPlayerSwimMovementThreshold",
		"OceanPlayerSwimDepth",
		"OceanUnderwaterEffectsEnabled",
		"OceanUnderwaterDepthStart",
		"OceanUnderwaterDepthFull",
		"OceanUnderwaterDepthOfFieldEnabled",
		"OceanUnderwaterDepthOfFieldFocusDistance",
		"OceanUnderwaterDepthOfFieldInFocusRadius",
		"OceanUnderwaterDepthOfFieldNearIntensity",
		"OceanUnderwaterDepthOfFieldFarIntensity",
		"OceanCameraDropsEnabled",
		"OceanCameraDropCount",
		"OceanCameraDropDuration",
	}

	local configOnlyAttributes = {
		"OceanRuntimeSurfaceColorEnabled",
	}

	for _, attributeName in ipairs(refreshAttributes) do
		table.insert(
			self._FolderAttributeConnections,
			folder:GetAttributeChangedSignal(attributeName):Connect(function()
				self:RefreshFromAttributes(false)
				self:_RefreshSourceTiles(workspace.CurrentCamera)
			end)
		)
	end

	for _, attributeName in ipairs(configOnlyAttributes) do
		table.insert(
			self._FolderAttributeConnections,
			folder:GetAttributeChangedSignal(attributeName):Connect(function()
				self:_RefreshConfigsFromAttributes(false)
			end)
		)
	end

	local function bindOceanFolderAttributes(oceanFolder: Instance)
		if oceanFolder == folder then
			return
		end

		for _, attributeName in ipairs(rebuildAttributes) do
			table.insert(
				self._FolderAttributeConnections,
				oceanFolder:GetAttributeChangedSignal(attributeName):Connect(function()
					self:RefreshFromAttributes(true)
				end)
			)
		end

		for _, attributeName in ipairs(refreshAttributes) do
			table.insert(
				self._FolderAttributeConnections,
				oceanFolder:GetAttributeChangedSignal(attributeName):Connect(function()
					self:RefreshFromAttributes(false)
					self:_RefreshSourceTiles(workspace.CurrentCamera)
				end)
			)
		end

		for _, attributeName in ipairs(configOnlyAttributes) do
			table.insert(
				self._FolderAttributeConnections,
				oceanFolder:GetAttributeChangedSignal(attributeName):Connect(function()
					self:_RefreshConfigsFromAttributes(false)
				end)
			)
		end
	end

	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("Folder") and descendant.Parent == folder then
			bindOceanFolderAttributes(descendant)
		end
	end

	self._SourceAddedConnection = folder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Folder") and descendant.Parent == folder then
			bindOceanFolderAttributes(descendant)
			self._OceanConfigs[descendant] = nil
			self._OceanSpectra[descendant] = nil
			self:_RefreshSourceTiles(workspace.CurrentCamera)
			return
		end

		if descendant:IsA("BasePart") then
			self:_TrackSourcePart(descendant)
			self:_TryAddTile(descendant)
		end
	end)

	self._SourceRemovingConnection = folder.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("Folder") and descendant.Parent == folder then
			self._OceanConfigs[descendant] = nil
			self._OceanSpectra[descendant] = nil
			return
		end

		if descendant:IsA("BasePart") then
			self:_UntrackSourcePart(descendant)
		end
	end)
end

function WaterSystemClass:_Step(deltaTime: number)
	local config = self._Config

	if config == nil then
		return
	end

	self._Time += deltaTime
	local camera = workspace.CurrentCamera
	local sourceFolder = self._SourceFolder

	self._SourceScanAccumulator += deltaTime

	if self._SourceScanAccumulator >= getLodScanInterval(sourceFolder, self._Options) then
		self._SourceScanAccumulator = 0
		self:_RefreshSourceTiles(camera)
	end

	local cameraPosition = if camera then camera.CFrame.Position else nil


	for sourcePart, tile in pairs(self._Tiles) do
		if not isWaterPart(sourcePart, self._SourceFolder, self._Container) then
			self:_UntrackSourcePart(sourcePart)
			continue
		end

		local tileConfig = self:_GetConfigForSource(sourcePart)

		if tileConfig == nil then
			continue
		end

		if tile:IsInvalid() then
			self:_RebuildTile(sourcePart)
			continue
		end

		local oceanFolder = self:_GetOceanFolderForSource(sourcePart) or sourceFolder

		if cameraPosition ~= nil then
			local distance = distanceToPart(sourcePart, cameraPosition)
			local unloadDistance = getUnloadDistance(oceanFolder, self._Options, tileConfig)

			if distance > unloadDistance then
				self:_RemoveTile(sourcePart)
				continue
			end

			local updateRate = getTileUpdateRate(oceanFolder, self._Options, tileConfig, distance)
			local lastUpdate = self._TileUpdateTimes[sourcePart]

			if updateRate > 0 and lastUpdate ~= nil and self._Time - lastUpdate < 1 / updateRate then
				continue
			end
		end

		local renderVisible = true

		if readFolderBoolean(oceanFolder, "OceanViewCullingEnabled", self._Options.ViewCullingEnabled ~= false) then
			local padding = math.max(
				readFolderNumber(
					oceanFolder,
					"OceanViewCullingPadding",
					self._Options.ViewCullingPadding or DEFAULT_OPTIONS.ViewCullingPadding
				),
				0
			)

			renderVisible = isPartInCameraView(sourcePart, camera, padding)
		end

		self._TileUpdateTimes[sourcePart] = self._Time
		tile:Update(self._Time, camera, renderVisible)
	end
end

function WaterSystemClass:Start()
	if self._Running then
		return
	end

	self._Running = true
	activeSystem = self

	if self._Options.RuntimePanel ~= false and self._Panel == nil then
		self._Panel = RuntimePanel.new(self)
		self._Panel:Start()
	end

	self:_EnsureBakeActor()

	local sourceFolder = workspace:FindFirstChild(self._Options.SourceFolderName or "Water")

	if sourceFolder ~= nil then
		self:_AttachFolder(sourceFolder)
	else
		warn(
			"[WaterSystem] Workspace."
				.. (self._Options.SourceFolderName or "Water")
				.. " was not found. Waiting for it."
		)
		self._WorkspaceChildAddedConnection = workspace.ChildAdded:Connect(function(child)
			if child.Name == (self._Options.SourceFolderName or "Water") then
				if self._WorkspaceChildAddedConnection then
					self._WorkspaceChildAddedConnection:Disconnect()
					self._WorkspaceChildAddedConnection = nil
				end

				self:_AttachFolder(child)
			end
		end)
	end

	self._RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		self:_Step(deltaTime)
	end)

	RuntimeLoops.start(self)
end

function WaterSystemClass:Stop()
	if not self._Running then
		return
	end

	self._Running = false

	if activeSystem == self then
		activeSystem = nil
	end

	RuntimeLoops.stop(self)

	if self._RenderConnection then
		self._RenderConnection:Disconnect()
		self._RenderConnection = nil
	end

	if self._WorkspaceChildAddedConnection then
		self._WorkspaceChildAddedConnection:Disconnect()
		self._WorkspaceChildAddedConnection = nil
	end

	if self._Panel then
		self._Panel:SetFolder(nil)
		self._Panel:Destroy()
		self._Panel = nil
	end

	self:_DestroyBakeActor()

	self:_DisconnectSource()

	local sources = {}

	for sourcePart in pairs(self._Tiles) do
		table.insert(sources, sourcePart)
	end

	for _, sourcePart in ipairs(sources) do
		self:_RemoveTile(sourcePart)
	end

	for sourcePart in pairs(self._SourceParts) do
		self:_RestoreSourceVisibility(sourcePart)
		self._SourceParts[sourcePart] = nil
	end

	for sourcePart in pairs(self._Pending) do
		self._Pending[sourcePart] = nil
	end

	if self._Container then
		self._Container:Destroy()
		self._Container = nil
	end


	self._SourceFolder = nil
	self._Config = nil
	self._Spectrum = nil
	self._Accumulator = 0
	self._SourceScanAccumulator = 0
	self._PhysicalAccumulator = 0
	self._BuoyancyAccumulator = 0
	self._PhysicalTime = 0
	self._BuoyancyTime = 0
	self._UnderwaterTime = 0
	self._PlayerWasSwimming = false
	self._UnderwaterDepth = 0
	self._WasUnderwater = false
	table.clear(self._PhysicalStates)
	table.clear(self._TileRenderLodChangeTimes)
	table.clear(self._OceanConfigs)
	table.clear(self._OceanSpectra)
end

function WaterSystemClass:Destroy()
	self:Stop()
end

function WaterSystemClass:GetHeight(worldPosition: Vector3, steps: number?): number?
	for _, tile in pairs(self._Tiles) do
		if tile:ContainsWorldPosition(worldPosition) then
			return tile:GetHeightAt(worldPosition, self._Time, steps)
		end
	end

	return nil
end

function WaterSystemClass:IsPointInWaterVolume(worldPosition: Vector3, surfacePadding: number?, bottomPadding: number?): boolean
	for _, tile in pairs(self._Tiles) do
		if tile:IsPointInWaterVolume(worldPosition, self._Time, surfacePadding, bottomPadding) then
			return true
		end
	end

	return false
end

function WaterSystemClass:GetNormal(worldPosition: Vector3): Vector3?
	for _, tile in pairs(self._Tiles) do
		if tile:ContainsWorldPosition(worldPosition) then
			return tile:GetNormalAt(worldPosition, self._Time)
		end
	end

	return nil
end

function WaterSystemClass:GetVelocity(worldPosition: Vector3): Vector3?
	for _, tile in pairs(self._Tiles) do
		if tile:ContainsWorldPosition(worldPosition) then
			return tile:GetVelocityAt(worldPosition, self._Time)
		end
	end

	return nil
end

function WaterSystemClass:CreateRipple(worldPosition: Vector3, strength: number?, radius: number?)
	local rippleStrength = strength or 0.22
	local rippleRadius = radius or 6

	for sourcePart, tile in pairs(self._Tiles) do
		if tile:ContainsWorldPosition(worldPosition) or distanceToPart(sourcePart, worldPosition) <= rippleRadius then
			tile:AddDrop(worldPosition, rippleRadius, rippleStrength)
		end
	end
end

function WaterSystemClass:Splash(worldPosition: Vector3, strength: number?, radius: number?)
	self:CreateRipple(worldPosition, strength or 0.34, radius or 8)
end

function WaterSystemClass:Footstep(worldPosition: Vector3, strength: number?, radius: number?)
	self:CreateRipple(worldPosition, strength or 0.08, radius or 3.5)
end

function WaterSystemClass:Explosion(worldPosition: Vector3, strength: number?, radius: number?)
	self:CreateRipple(worldPosition, strength or 1.2, radius or 28)
end

function WaterSystemClass:ProjectileImpact(worldPosition: Vector3, strength: number?, radius: number?)
	self:CreateRipple(worldPosition, strength or 0.18, radius or 4.5)
end

function WaterSystemClass:MoveSphere(
	oldWorldCenter: Vector3,
	newWorldCenter: Vector3,
	radius: number,
	strengthScale: number?
)
	for sourcePart, tile in pairs(self._Tiles) do
		if tile:ContainsWorldPosition(newWorldCenter) or distanceToPart(sourcePart, newWorldCenter) <= radius then
			tile:MoveSphere(oldWorldCenter, newWorldCenter, radius, strengthScale)
		end
	end
end

local WaterSystem = {}

function WaterSystem.new(options: WaterSystemOptions?): WaterSystem
	return setmetatable({
		_Options = cloneOptions(options),
		_Config = nil,
		_SourceFolder = nil,
		_Container = nil,
		_Spectrum = nil,
		_SourceParts = {},
		_SourceLocalTransparency = {},
		_Tiles = {},
		_Pending = {},
		_TileRenderLods = {},
		_TileRenderLodChangeTimes = {},
		_TileConnections = {},
		_TileUpdateTimes = {},
		_OceanConfigs = {},
		_OceanSpectra = {},
		_BakeActor = nil,
		_BakeResultConnection = nil,
		_BakeRequestId = 0,
		_PendingBakeOptions = nil,
		_PendingBakeRebuildTiles = false,
		_Running = false,
		_Time = 0,
		_Accumulator = 0,
		_SourceScanAccumulator = 0,
		_PhysicalAccumulator = 0,
		_PhysicalTime = 0,
		_PhysicalStates = {},
		_BuoyancyAccumulator = 0,
		_BuoyancyTime = 0,
		_UnderwaterTime = 0,
		_PlayerSwimAnimationState = nil,
		_PlayerSwimRoot = nil,
		_PlayerWasSwimming = false,
		_PlayerJumpingWasEnabled = nil,
		_UnderwaterDepth = 0,
		_WasUnderwater = false,
		_CameraDropFolder = nil,
		_OriginalFogColor = nil,
		_OriginalFogStart = 0,
		_OriginalFogEnd = 0,
		_OriginalDepthOfFieldEnabled = nil,
		_OriginalDepthOfFieldFocusDistance = 0,
		_OriginalDepthOfFieldInFocusRadius = 0,
		_OriginalDepthOfFieldNearIntensity = 0,
		_OriginalDepthOfFieldFarIntensity = 0,
		_RenderConnection = nil,
		_BuoyancyConnection = nil,
		_PhysicalConnection = nil,
		_PlayerSurfaceConnection = nil,
		_UnderwaterConnection = nil,
		_SourceAddedConnection = nil,
		_SourceRemovingConnection = nil,
		_WorkspaceChildAddedConnection = nil,
		_FolderAttributeConnections = {},
		_Panel = nil,
	}, WaterSystemClass) :: any
end

function WaterSystem.GetActive(): WaterSystem?
	return activeSystem
end

function WaterSystem.GetHeight(worldPosition: Vector3, steps: number?): number?
	if activeSystem == nil then
		return nil
	end

	return activeSystem:GetHeight(worldPosition, steps)
end

function WaterSystem.GetNormal(worldPosition: Vector3): Vector3?
	if activeSystem == nil then
		return nil
	end

	return activeSystem:GetNormal(worldPosition)
end

function WaterSystem.GetVelocity(worldPosition: Vector3): Vector3?
	if activeSystem == nil then
		return nil
	end

	return activeSystem:GetVelocity(worldPosition)
end

function WaterSystem.CreateRipple(worldPosition: Vector3, strength: number?, radius: number?)
	if activeSystem ~= nil then
		activeSystem:CreateRipple(worldPosition, strength, radius)
	end
end

function WaterSystem.Splash(worldPosition: Vector3, strength: number?, radius: number?)
	if activeSystem ~= nil then
		activeSystem:Splash(worldPosition, strength, radius)
	end
end

function WaterSystem.Footstep(worldPosition: Vector3, strength: number?, radius: number?)
	if activeSystem ~= nil then
		activeSystem:Footstep(worldPosition, strength, radius)
	end
end

function WaterSystem.Explosion(worldPosition: Vector3, strength: number?, radius: number?)
	if activeSystem ~= nil then
		activeSystem:Explosion(worldPosition, strength, radius)
	end
end

function WaterSystem.ProjectileImpact(worldPosition: Vector3, strength: number?, radius: number?)
	if activeSystem ~= nil then
		activeSystem:ProjectileImpact(worldPosition, strength, radius)
	end
end

function WaterSystem.MoveSphere(
	oldWorldCenter: Vector3,
	newWorldCenter: Vector3,
	radius: number,
	strengthScale: number?
)
	if activeSystem ~= nil then
		activeSystem:MoveSphere(oldWorldCenter, newWorldCenter, radius, strengthScale)
	end
end

return WaterSystem
