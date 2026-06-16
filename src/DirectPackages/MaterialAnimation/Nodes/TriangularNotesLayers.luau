local AnimationProjection = require(script.Parent.Parent.Parent.AnimationProjection)

type AbstractLayer = {
	color: Color3,
	center: Vector2,
	radius: Vector2,
	opacity: number,
	phase: number,
	drift: Vector2,
	rotation: number,
	wobble: number,
	waveA: number,
	waveB: number,
	speed: number,
}

local function valueOr(value: any, fallback: any): any
	return if value == nil then fallback else value
end

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function atan2(y: number, x: number): number
	if x > 0 then
		return math.atan(y / x)
	elseif x < 0 and y >= 0 then
		return math.atan(y / x) + math.pi
	elseif x < 0 then
		return math.atan(y / x) - math.pi
	elseif y > 0 then
		return math.pi * 0.5
	elseif y < 0 then
		return -math.pi * 0.5
	end

	return 0
end

local function lerpColor(a: Color3, b: Color3, alpha: number): Color3
	return Color3.new(lerp(a.R, b.R, alpha), lerp(a.G, b.G, alpha), lerp(a.B, b.B, alpha))
end

local function blendColor(base: Color3, top: Color3, alpha: number): Color3
	alpha = math.clamp(alpha, 0, 1)

	return Color3.new(lerp(base.R, top.R, alpha), lerp(base.G, top.G, alpha), lerp(base.B, top.B, alpha))
end

local function buildLayers(colorB: Color3, colorC: Color3, colorD: Color3, colorE: Color3): { AbstractLayer }
	return {
		{
			color = colorC,
			center = Vector2.new(0.08, 0.28),
			radius = Vector2.new(0.38, 0.2),
			opacity = 0.82,
			phase = 0.1,
			drift = Vector2.new(0.18, -0.08),
			rotation = 0.35,
			wobble = 0.18,
			waveA = 3.0,
			waveB = 6.0,
			speed = 1,
		},
		{
			color = colorB,
			center = Vector2.new(0.58, 0.09),
			radius = Vector2.new(0.46, 0.16),
			opacity = 0.78,
			phase = 1.6,
			drift = Vector2.new(-0.16, 0.06),
			rotation = -0.18,
			wobble = 0.16,
			waveA = 2.0,
			waveB = 5.0,
			speed = 2,
		},
		{
			color = colorE,
			center = Vector2.new(0.82, 0.38),
			radius = Vector2.new(0.2, 0.34),
			opacity = 0.86,
			phase = 2.4,
			drift = Vector2.new(-0.1, 0.12),
			rotation = 0.9,
			wobble = 0.2,
			waveA = 4.0,
			waveB = 7.0,
			speed = 1,
		},
		{
			color = colorC,
			center = Vector2.new(0.22, 0.57),
			radius = Vector2.new(0.28, 0.3),
			opacity = 0.8,
			phase = 3.15,
			drift = Vector2.new(0.12, 0.1),
			rotation = -0.72,
			wobble = 0.22,
			waveA = 5.0,
			waveB = 8.0,
			speed = 2,
		},
		{
			color = colorD,
			center = Vector2.new(0.66, 0.72),
			radius = Vector2.new(0.4, 0.28),
			opacity = 0.9,
			phase = 4.45,
			drift = Vector2.new(0.08, -0.14),
			rotation = 0.28,
			wobble = 0.14,
			waveA = 2.0,
			waveB = 5.0,
			speed = 1,
		},
		{
			color = colorB,
			center = Vector2.new(0.36, 0.86),
			radius = Vector2.new(0.18, 0.36),
			opacity = 0.84,
			phase = 5.3,
			drift = Vector2.new(-0.09, -0.1),
			rotation = 0.54,
			wobble = 0.24,
			waveA = 4.0,
			waveB = 9.0,
			speed = 2,
		},
		{
			color = colorC,
			center = Vector2.new(0.94, 0.12),
			radius = Vector2.new(0.17, 0.2),
			opacity = 0.88,
			phase = 0.85,
			drift = Vector2.new(0.06, 0.16),
			rotation = -0.45,
			wobble = 0.2,
			waveA = 6.0,
			waveB = 6.0,
			speed = 1,
		},
		{
			color = colorD,
			center = Vector2.new(0.04, 0.9),
			radius = Vector2.new(0.22, 0.44),
			opacity = 0.62,
			phase = 2.9,
			drift = Vector2.new(0.1, 0.08),
			rotation = -0.32,
			wobble = 0.12,
			waveA = 3.0,
			waveB = 7.0,
			speed = 1,
		},
		{
			color = colorE,
			center = Vector2.new(0.72, 0.97),
			radius = Vector2.new(0.34, 0.13),
			opacity = 0.78,
			phase = 4.9,
			drift = Vector2.new(-0.12, -0.06),
			rotation = 0.12,
			wobble = 0.17,
			waveA = 5.0,
			waveB = 10.0,
			speed = 2,
		},
	}
end

local function organicMask(u: number, v: number, t: number, layer: AbstractLayer, animationRadius: number): number
	local time = t * layer.speed + layer.phase
	local centerX = layer.center.X + math.cos(time) * layer.drift.X * animationRadius * 10
	local centerY = layer.center.Y + math.sin(time) * layer.drift.Y * animationRadius * 10
	local rotation = layer.rotation + math.sin(time) * 0.18
	local cosRotation = math.cos(rotation)
	local sinRotation = math.sin(rotation)
	local dx = u - centerX
	local dy = v - centerY
	local px = (dx * cosRotation + dy * sinRotation) / layer.radius.X
	local py = (-dx * sinRotation + dy * cosRotation) / layer.radius.Y
	local angle = atan2(py, px)
	local distance = math.sqrt(px * px + py * py)
	local shape = 1
		+ math.sin(angle * layer.waveA + time) * layer.wobble
		+ math.cos(angle * layer.waveB - time * 2) * layer.wobble * 0.5
		+ math.sin(angle * 2 + time * 3) * layer.wobble * 0.35

	return if distance <= shape then layer.opacity else 0
end

local function resolveColor(parameters, context, directKey: string, keyParameter: string, fallbackKey: string, fallback: Color3): Color3
	if parameters[directKey] ~= nil then
		return parameters[directKey]
	end

	return context.workspace[parameters[keyParameter] or fallbackKey] or fallback
end

return {
	Name = "TriangularNotesLayers",
	Family = "Material",
	Inputs = {},
	Outputs = { "color", "alpha" },
	DependsOnTime = true,

	Prepare = function(parameters, workspace)
		local context = {
			workspace = workspace,
		}
		local colorA = resolveColor(parameters, context, "ColorA", "ColorAKey", "ColorA", Color3.fromRGB(22, 180, 222))
		local colorB = resolveColor(parameters, context, "ColorB", "ColorBKey", "ColorB", Color3.fromRGB(103, 226, 232))
		local colorC = resolveColor(parameters, context, "ColorC", "ColorCKey", "ColorC", Color3.fromRGB(129, 239, 238))
		local colorD = resolveColor(parameters, context, "ColorD", "ColorDKey", "ColorD", Color3.fromRGB(29, 118, 228))
		local colorE = resolveColor(parameters, context, "ColorE", "ColorEKey", "ColorE", Color3.fromRGB(41, 205, 226))

		return {
			colorA = colorA,
			colorB = colorB,
			layers = buildLayers(colorB, colorC, colorD, colorE),
			animationRadius = valueOr(parameters.AnimationRadius, 0.565),
		}
	end,

	Execute = function(_inputs, parameters, context)
		local state = context.nodeState
		local colorA = if state then state.colorA else resolveColor(parameters, context, "ColorA", "ColorAKey", "ColorA", Color3.fromRGB(22, 180, 222))
		local colorB = if state then state.colorB else resolveColor(parameters, context, "ColorB", "ColorBKey", "ColorB", Color3.fromRGB(103, 226, 232))
		local layers = if state then state.layers else buildLayers(colorB, Color3.fromRGB(129, 239, 238), Color3.fromRGB(29, 118, 228), Color3.fromRGB(41, 205, 226))
		local animationRadius = if state then state.animationRadius else valueOr(parameters.AnimationRadius, 0.565)
		local projectedX, projectedY =
			AnimationProjection.ProjectPixel(context.x, context.y, context.width, context.height, context.projectionMode)
		local u = if context.width > 1 then projectedX / (context.width - 1) else 0
		local v = if context.height > 1 then projectedY / (context.height - 1) else 0
		u = math.clamp(u, 0, 1)
		v = math.clamp(v, 0, 1)

		local wash = math.clamp((u * 0.3 + v * 0.7) + math.sin(context.t + u * 2.2) * 0.035, 0, 1)
		local color = lerpColor(colorA, colorB, wash)

		for _, layer in ipairs(layers) do
			local alpha = organicMask(u, v, context.t, layer, animationRadius)
			color = blendColor(color, layer.color, alpha)
		end

		return {
			color = color,
			alpha = 1,
		}
	end,
}
