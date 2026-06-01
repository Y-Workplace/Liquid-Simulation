local RunService = game:GetService("RunService")

export type Compute<T> = (properties: T, progress: number) -> ()
export type Action<T> = (properties: T?) -> ()

export type TrackOptions = {
	time: number?,
	startTime: number?,
	duration: number?,
	easing: ((number) -> number)?,
	id: string?,
}

export type KeyframeOptions<T> = {
	id: string?,
	properties: T?,
	once: boolean?,
}

export type AudioOptions = {
	id: string?,
	time: number?,
	startTime: number?,
	offset: number?,
	duration: number?,
	playbackSpeed: number?,
	volume: number?,
	looped: boolean?,
	stopAtEnd: boolean?,
	tolerance: number?,
}

type Track = {
	id: string?,
	properties: any,
	compute: Compute<any>,
	startTime: number,
	duration: number,
	easing: ((number) -> number)?,
}

type Keyframe = {
	id: string?,
	time: number,
	action: Action<any>,
	properties: any?,
	once: boolean,
	fired: boolean,
}

type AudioTrack = {
	id: string?,
	sound: Sound,
	startTime: number,
	offset: number,
	duration: number?,
	playbackSpeed: number,
	volume: number?,
	looped: boolean,
	stopAtEnd: boolean,
	tolerance: number,
}

local TimelineClass = {}
TimelineClass.__index = TimelineClass

local Easing = {}

function Easing.Linear(progress: number): number
	return progress
end

function Easing.InQuad(progress: number): number
	return progress * progress
end

function Easing.OutQuad(progress: number): number
	return 1 - (1 - progress) * (1 - progress)
end

function Easing.InOutQuad(progress: number): number
	if progress < 0.5 then
		return 2 * progress * progress
	end

	return 1 - ((-2 * progress + 2) ^ 2) / 2
end

local function clamp01(value: number): number
	if value < 0 then
		return 0
	end

	if value > 1 then
		return 1
	end

	return value
end

local function resolveTrackStart(options: { startTime: number?, time: number? }?): number
	if options == nil then
		return 0
	end

	return options.startTime or options.time or 0
end

function TimelineClass.new(duration: number?): any
	return setmetatable({
		Duration = duration or 1,
		Time = 0,
		Speed = 1,
		Looped = false,
		Playing = false,
		_tracks = {} :: { Track },
		_keyframes = {} :: { Keyframe },
		_audioTracks = {} :: { AudioTrack },
		_connection = nil :: RBXScriptConnection?,
		_lastClock = 0,
	}, TimelineClass)
end

function TimelineClass:SetDuration(duration: number): any
	assert(duration >= 0, "Timeline duration must be >= 0")
	self.Duration = duration
	return self
end

function TimelineClass:SetSpeed(speed: number): any
	self.Speed = speed
	return self
end

function TimelineClass:SetLooped(looped: boolean): any
	self.Looped = looped
	return self
end

function TimelineClass:Register<T>(properties: T, compute: Compute<T>, options: TrackOptions?): Track
	assert(type(compute) == "function", "Timeline:Register expects a compute function")

	local startTime = resolveTrackStart(options)
	local duration = if options and options.duration then options.duration else math.max(self.Duration - startTime, 0)

	assert(startTime >= 0, "Track start time must be >= 0")
	assert(duration >= 0, "Track duration must be >= 0")

	local track = {
		id = if options then options.id else nil,
		properties = properties,
		compute = compute,
		startTime = startTime,
		duration = duration,
		easing = if options then options.easing else nil,
	}

	table.insert(self._tracks, track)
	self.Duration = math.max(self.Duration, startTime + duration)

	return track
end

function TimelineClass:RegisterAudio(sound: Sound, options: AudioOptions?): AudioTrack
	assert(sound ~= nil and sound:IsA("Sound"), "Timeline:RegisterAudio expects a Sound instance")

	local startTime = resolveTrackStart(options)
	local offset = if options and options.offset then options.offset else 0
	local duration = if options then options.duration else nil

	assert(startTime >= 0, "Audio start time must be >= 0")
	assert(offset >= 0, "Audio offset must be >= 0")
	if duration ~= nil then
		assert(duration >= 0, "Audio duration must be >= 0")
	end

	local audioTrack = {
		id = if options then options.id else nil,
		sound = sound,
		startTime = startTime,
		offset = offset,
		duration = duration,
		playbackSpeed = if options and options.playbackSpeed then options.playbackSpeed else sound.PlaybackSpeed,
		volume = if options then options.volume else nil,
		looped = if options and options.looped ~= nil then options.looped else sound.Looped,
		stopAtEnd = if options and options.stopAtEnd ~= nil then options.stopAtEnd else true,
		tolerance = if options and options.tolerance then options.tolerance else 0.035,
	}

	table.insert(self._audioTracks, audioTrack)

	if duration ~= nil then
		self.Duration = math.max(self.Duration, startTime + duration)
	elseif sound.TimeLength > 0 then
		self.Duration = math.max(self.Duration, startTime + math.max(sound.TimeLength - offset, 0))
	end

	return audioTrack
end

function TimelineClass:Keyframe<T>(time: number, action: Action<T>, options: KeyframeOptions<T>?): Keyframe
	assert(time >= 0, "Keyframe time must be >= 0")
	assert(type(action) == "function", "Timeline:Keyframe expects an action function")

	local keyframe = {
		id = if options then options.id else nil,
		time = time,
		action = action,
		properties = if options then options.properties else nil,
		once = if options and options.once ~= nil then options.once else true,
		fired = false,
	}

	table.insert(self._keyframes, keyframe)
	table.sort(self._keyframes, function(left, right)
		return left.time < right.time
	end)

	self.Duration = math.max(self.Duration, time)

	return keyframe
end

function TimelineClass:Action<T>(time: number, action: Action<T>, options: KeyframeOptions<T>?): Keyframe
	return self:Keyframe(time, action, options)
end

function TimelineClass:_evaluateTracks(timePosition: number)
	for _, track in ipairs(self._tracks) do
		local progress

		if track.duration == 0 then
			progress = if timePosition >= track.startTime then 1 else 0
		else
			progress = clamp01((timePosition - track.startTime) / track.duration)
		end

		if track.easing then
			progress = clamp01(track.easing(progress))
		end

		track.compute(track.properties, progress)
	end
end

function TimelineClass:_evaluateAudioTracks(timePosition: number)
	for _, audioTrack in ipairs(self._audioTracks) do
		local sound = audioTrack.sound
		local duration = audioTrack.duration

		if duration == nil and sound.TimeLength > 0 then
			duration = math.max(sound.TimeLength - audioTrack.offset, 0)
		end

		local localTime = timePosition - audioTrack.startTime
		local isBefore = localTime < 0
		local isAfter = duration ~= nil and localTime > duration
		local shouldPlay = self.Playing and not isBefore and not isAfter

		sound.PlaybackSpeed = audioTrack.playbackSpeed * self.Speed
		sound.Looped = audioTrack.looped

		if audioTrack.volume ~= nil then
			sound.Volume = audioTrack.volume
		end

		if shouldPlay then
			local targetTime = audioTrack.offset + localTime * audioTrack.playbackSpeed

			if sound.TimeLength > 0 then
				targetTime = math.clamp(targetTime, 0, sound.TimeLength)
			else
				targetTime = math.max(targetTime, 0)
			end

			if math.abs(sound.TimePosition - targetTime) > audioTrack.tolerance then
				sound.TimePosition = targetTime
			end

			if not sound.IsPlaying then
				sound:Play()
			end
		elseif sound.IsPlaying then
			if audioTrack.stopAtEnd and isAfter then
				sound:Stop()
			else
				sound:Pause()
			end
		end
	end
end

function TimelineClass:_fireKeyframes(previousTime: number, nextTime: number)
	if nextTime < previousTime then
		return
	end

	for _, keyframe in ipairs(self._keyframes) do
		if keyframe.once and keyframe.fired then
			continue
		end

		if previousTime < keyframe.time and keyframe.time <= nextTime then
			keyframe.fired = true
			keyframe.action(keyframe.properties)
		end
	end
end

function TimelineClass:_fireKeyframesAt(timePosition: number)
	for _, keyframe in ipairs(self._keyframes) do
		if keyframe.once and keyframe.fired then
			continue
		end

		if keyframe.time == timePosition then
			keyframe.fired = true
			keyframe.action(keyframe.properties)
		end
	end
end

function TimelineClass:_markPastKeyframes()
	for _, keyframe in ipairs(self._keyframes) do
		keyframe.fired = keyframe.once and keyframe.time <= self.Time
	end
end

function TimelineClass:_resetKeyframes()
	for _, keyframe in ipairs(self._keyframes) do
		keyframe.fired = false
	end
end

function TimelineClass:Step(deltaTime: number): any
	if deltaTime == 0 then
		self:_evaluateTracks(self.Time)
		self:_evaluateAudioTracks(self.Time)
		return self
	end

	local previousTime = self.Time
	local nextTime = previousTime + deltaTime * self.Speed

	if self.Duration > 0 then
		if self.Looped then
			while nextTime >= self.Duration do
				self:_fireKeyframes(previousTime, self.Duration)
				nextTime -= self.Duration
				previousTime = 0
				self:_resetKeyframes()
			end
		else
			nextTime = math.min(nextTime, self.Duration)
		end
	end

	self.Time = math.max(nextTime, 0)
	self:_fireKeyframes(previousTime, self.Time)
	self:_evaluateTracks(self.Time)
	self:_evaluateAudioTracks(self.Time)

	if not self.Looped and self.Duration > 0 and self.Time >= self.Duration then
		self:Pause()
	end

	return self
end

function TimelineClass:Seek(timePosition: number, fireActions: boolean?): any
	assert(timePosition >= 0, "Timeline seek time must be >= 0")

	local previousTime = self.Time
	self.Time = math.min(timePosition, self.Duration)

	if fireActions then
		self:_fireKeyframes(previousTime, self.Time)
	else
		self:_markPastKeyframes()
	end

	self:_evaluateTracks(self.Time)
	self:_evaluateAudioTracks(self.Time)
	return self
end

function TimelineClass:Play(fromTime: number?): any
	if fromTime ~= nil then
		self:Seek(fromTime)
	end

	if self.Playing then
		return self
	end

	self.Playing = true
	self._lastClock = os.clock()
	self:_evaluateTracks(self.Time)
	self:_evaluateAudioTracks(self.Time)
	self:_fireKeyframesAt(self.Time)

	self._connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local deltaTime = now - self._lastClock
		self._lastClock = now

		self:Step(deltaTime)
	end)

	return self
end

function TimelineClass:Pause(): any
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	self.Playing = false
	self:_evaluateAudioTracks(self.Time)
	return self
end

function TimelineClass:Stop(): any
	self:Pause()
	self.Time = 0
	self:_resetKeyframes()
	self:_evaluateTracks(0)

	for _, audioTrack in ipairs(self._audioTracks) do
		audioTrack.sound:Stop()
		audioTrack.sound.TimePosition = audioTrack.offset
	end

	return self
end

function TimelineClass:Clear(): any
	table.clear(self._tracks)
	table.clear(self._keyframes)
	table.clear(self._audioTracks)
	self.Time = 0
	self.Duration = 1
	return self
end

function TimelineClass:Destroy()
	self:Pause()
	self:Clear()
end

local defaultTimeline = TimelineClass.new()

local Timeline = {
	Easing = Easing,
}

function Timeline.new(duration: number?): any
	return TimelineClass.new(duration)
end

for name, value in pairs(TimelineClass) do
	if type(value) == "function" and name ~= "new" and string.sub(name, 1, 1) ~= "_" then
		Timeline[name] = function(_, ...)
			return value(defaultTimeline, ...)
		end
	end
end

return Timeline
