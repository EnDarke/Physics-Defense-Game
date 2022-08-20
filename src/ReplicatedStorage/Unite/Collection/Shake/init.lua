--!strict

-- Author: Alex/EnDarke
-- Description: Handles object shaking. Inspiration from Sleitnick

local Parent = script.Parent

--\\ Services //--
local RunService = game:GetService("RunService")

--\\ Types //--
type UpdateCallbackFn = () -> (Vector3, Vector3, boolean)

--\\ Modules //--
local Indexing = require(script.Indexing)
local Trove = Indexing("Trove")

local random = Random.new()
local renderId = 0

local Shake = {}
Shake.__index = Shake

function Shake.new()
	local self = setmetatable({}, Shake)
	self.Amplitude = 1
	self.Frequency = 1
	self.FadeInTime = 1
	self.FadeOutTime = 1
	self.SustainTime = 0
	self.Sustain = false
	self.PositionInfluence = Vector3.one
	self.RotationInfluence = Vector3.one
	self.TimeFunction = if RunService:IsRunning() then time else os.clock
	self._timeOffset = random:NextNumber(-1e9, 1e9)
	self._startTime = 0
	self._trove = Trove.new()
	self._running = false
	return self
end

function Shake.InverseSquare(shake: Vector3, distance: number): Vector3
	if distance < 1 then
		distance = 1
	end
	local intensity = 1 / (distance * distance)
	return shake * intensity
end

function Shake.NextRenderName(): string
	renderId += 1
	return ("__shake_%.4i__"):format(renderId)
end

function Shake:Start()
	self._startTime = self.TimeFunction()
	self._running = true
	self._trove:Add(function()
		self._running = false
	end)
end

function Shake:Stop()
	self._trove:Clean()
end

function Shake:IsShaking(): boolean
	return self._running
end

function Shake:StopSustain()
	local now = self.TimeFunction()
	self.Sustain = false
	self.SustainTime = (now - self._startTime) - self.FadeInTime
end

function Shake:Update(): (Vector3, Vector3, boolean)
	local done = false

	local now = self.TimeFunction()
	local dur = now - self._startTime

	local noiseInput = ((now + self._timeOffset) / self.Frequency) % 1000000

	local multiplierFadeIn = 1
	local multiplierFadeOut = 1
	if dur < self.FadeInTime then
		-- Fade in
		multiplierFadeIn = dur / self.FadeInTime
	end
	if not self.Sustain and dur > self.FadeInTime + self.SustainTime then
		if self.FadeOutTime == 0 then
			done = true
		else
			-- Fade out
			multiplierFadeOut = 1 - (dur - self.FadeInTime - self.SustainTime) / self.FadeOutTime
			if not self.Sustain and dur >= self.FadeInTime + self.SustainTime + self.FadeOutTime then
				done = true
			end
		end
	end

	local offset = Vector3.new(
		math.noise(noiseInput, 0) / 2,
		math.noise(0, noiseInput) / 2,
		math.noise(noiseInput, noiseInput) / 2
	) * self.Amplitude * math.min(multiplierFadeIn, multiplierFadeOut)

	if done then
		self:Stop()
	end

	return self.PositionInfluence * offset, self.RotationInfluence * offset, done
end

function Shake:OnSignal(signal, callbackFn: UpdateCallbackFn)
	return self._trove:Connect(signal, function()
		callbackFn(self:Update())
	end)
end

function Shake:BindToRenderStep(name: string, priority: number, callbackFn: UpdateCallbackFn)
	self._trove:BindToRenderStep(name, priority, function()
		callbackFn(self:Update())
	end)
end

function Shake:Clone()
	local shake = Shake.new()
	local cloneFields = {
		"Amplitude",
		"Frequency",
		"FadeInTime",
		"FadeOutTime",
		"SustainTime",
		"Sustain",
		"PositionInfluence",
		"RotationInfluence",
		"TimeFunction",
	}
	for _, field in cloneFields do
		shake[field] = self[field]
	end
	return shake
end

function Shake:Destroy()
	self:Stop()
end

return Shake