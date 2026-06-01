local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local lensFlareDir = ReplicatedStorage.Shared.LensFlare
local EventTree = require(ReplicatedStorage.Packages.EventTree)

EventTree.LensFlare.Start.Callable:Register(function()
  local LensFlare = require(lensFlareDir.Modules.LensFlare)
  local Configuration = require(lensFlareDir.Constants.Configuration)

  local camera = workspace.CurrentCamera

  local SUN_DISTANCE = 5000

  local SUN_EXPOSURE_ADJUST = Configuration.SUN_EXPOSURE_ADJUSTMENT
  local SUN_EXPOSURE_SMOOTH_TIME = Configuration.SUN_EXPOSURE_TIME

  local SUN_BRIGHTNESS_THRESHOLD = Configuration.SUN_BRIGHTNESS_THRESHOLD
  local SUN_ANGLE_THRESHOLD = Configuration.SUN_ANGLE_THRESHOLD

  local alpha, vel = 0, 0

  -- Sun Lens Flare
  local sunPart = Instance.new("Part")
  sunPart.Anchored = true
  sunPart.CanCollide = false
  sunPart.CanQuery = false
  sunPart.CanTouch = false
  sunPart.Transparency = 0.5
  sunPart.Size = vector.create(1, 1, 1)
  sunPart.Name = "SunFlareTestPart"
  sunPart.Parent = workspace

  sunPart:SetAttribute("LensFlareStrength", 0.5)

  local function updateColor()
    sunPart.Color = Lighting.ColorShift_Top
  end

  local sunFlare = LensFlare.new(camera, "Sun", sunPart)

  updateColor()
  Lighting:GetPropertyChangedSignal("ColorShift_Top"):Connect(updateColor)

  local function updateStrength()
    local sunAngle = Lighting:GetSunDirection().Y * 90
    local sunAlpha = math.clamp(sunAngle / SUN_ANGLE_THRESHOLD, 0, 1)
    local brightnessAlpha = math.clamp(Lighting.Brightness / SUN_BRIGHTNESS_THRESHOLD, 0, 1)
    local totalAlpha = sunAlpha * brightnessAlpha

    sunFlare.Enabled = totalAlpha > 0

    sunPart:SetAttribute("LensFlareStrength", totalAlpha)
  end

  updateStrength()
  Lighting:GetPropertyChangedSignal("Brightness"):Connect(updateStrength)
  Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateStrength)

  RunService:BindToRenderStep("UpdateLensFlarePart", Enum.RenderPriority.Camera.Value + 9, function()
    sunPart.Position = camera.CFrame.Position + (Lighting:GetSunDirection() * SUN_DISTANCE)
  end)

  RunService:BindToRenderStep("UpdateExposure", Enum.RenderPriority.Camera.Value + 11, function(delta: number)
    Lighting.ExposureCompensation -= (alpha * SUN_EXPOSURE_ADJUST)
    alpha, vel = TweenService:SmoothDamp(alpha, sunFlare.Alpha ^ 2, vel, SUN_EXPOSURE_SMOOTH_TIME, nil, delta)
    Lighting.ExposureCompensation += (alpha * SUN_EXPOSURE_ADJUST)
  end)
end)
