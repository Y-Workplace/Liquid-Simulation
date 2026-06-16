type Stripe = {
	y: number,
	center: number,
	length: number,
	width: number,
	alpha: number,
	speed: number,
	phase: number,
	waviness: number,
	curve: number,
	edge: number,
}

local TAU = math.pi * 2

local function valueOr(value: any, fallback: any): any
	return if value == nil then fallback else value
end

local function buildStripes(
	shineLineWidth: number,
	stripeWaviness: number,
	seed: number
): { Stripe }
	local stripes = table.create(16)
	local rng = Random.new(seed)
	local speeds = { -2, -1, 1, 2 }

	for _ = 1, 16 do
		local speed = speeds[rng:NextInteger(1, #speeds)]
		table.insert(stripes, {
			y = rng:NextNumber(0.04, 0.96),
			center = rng:NextNumber(0, 1),
			length = rng:NextNumber(0.16, 0.68),
			width = shineLineWidth * rng:NextNumber(0.22, 1.45),
			alpha = rng:NextNumber(0.36, 0.95),
			speed = speed,
			phase = rng:NextNumber(0, TAU),
			waviness = stripeWaviness * rng:NextNumber(0.18, 1.35),
			curve = stripeWaviness * rng:NextNumber(1.2, 4.6) * (if rng:NextNumber(0, 1) > 0.5 then 1 else -1),
			edge = rng:NextNumber(0.025, 0.12),
		})
	end

	return stripes
end

local function lineProfile(distance: number, width: number): number
	local core = math.clamp((width - distance) / width, 0, 1)
	local glow = math.clamp((width * 2.25 - distance) / (width * 2.25), 0, 1)

	return core * core + glow * glow * 0.14
end

local function segmentVisibility(u: number, t: number, stripe: Stripe, stripeSpeed: number, stripeBreakup: number): (number, number)
	local center = stripe.center + (t / TAU) * stripeSpeed * stripe.speed
	center -= math.floor(center)

	local signedDistance = u - center
	if signedDistance > 0.5 then
		signedDistance -= 1
	elseif signedDistance < -0.5 then
		signedDistance += 1
	end

	local distance = math.abs(signedDistance)
	local halfLength = stripe.length * 0.5
	if distance >= halfLength then
		return 0, 0
	end

	local localT = signedDistance / halfLength
	local tipFade = math.clamp((halfLength - distance) / stripe.edge, 0, 1)
	local shimmer = 0.78 + math.sin((u * 2.4 + stripe.phase) * TAU + t * stripe.speed) * 0.12
	local breakup = math.clamp(stripeBreakup, 0, 1)
	local variation = 1 - breakup * 0.32 + shimmer * breakup * 0.32
	local glint = math.max(0, math.sin((u * 5.0 + stripe.phase) * TAU + t * 2)) ^ 12

	return math.clamp(tipFade * variation + glint * tipFade * 0.18, 0, 1), localT
end

return {
	Name = "TriangularStripeForceField",
	Family = "Source",
	Inputs = {},
	Outputs = { "forceField" },
	DependsOnTime = true,

	Prepare = function(parameters, _workspace)
		local shineLineWidth = valueOr(parameters.ShineLineWidth, 0.02)
		local stripeWaviness = valueOr(parameters.StripeWaviness, 0.007)
		local seed = valueOr(parameters.Seed, 18067)

		return {
			stripes = buildStripes(shineLineWidth, stripeWaviness, seed),
		}
	end,

	Execute = function(_inputs, parameters, context)
		local strength = valueOr(parameters.Strength, 1.15)
		local shineLineStrength = valueOr(parameters.ShineLineStrength, 1.0)
		local stripeSpeed = valueOr(parameters.StripeSpeed, 1)
		local stripeBreakup = valueOr(parameters.StripeBreakup, 0.28)
		local stripes = if context.nodeState then context.nodeState.stripes else buildStripes(
			valueOr(parameters.ShineLineWidth, 0.02),
			valueOr(parameters.StripeWaviness, 0.007),
			valueOr(parameters.Seed, 18067)
		)
		local intensity = 0

		for _, stripe in ipairs(stripes) do
			local visibility, localT = segmentVisibility(context.u, context.t, stripe, stripeSpeed, stripeBreakup)
			if visibility <= 0 then
				continue
			end

			local midCurve = math.sin((localT + 1) * math.pi * 0.5)
			local wave = math.sin((context.u * 1.35 + stripe.phase) * TAU + context.t) * stripe.waviness
				+ math.sin((context.u * 3.1 + stripe.phase * 0.37) * TAU - context.t * 2) * stripe.waviness * 0.35
			local stripeY = stripe.y + wave + midCurve * stripe.curve
			local distance = math.abs(context.v - stripeY)
			local profile = lineProfile(distance, stripe.width)

			intensity += profile * visibility * stripe.alpha
		end

		return {
			forceField = math.clamp(intensity * strength * shineLineStrength, 0, 1),
		}
	end,
}
