-- !strict

-- Author: Alex/EnDarke
-- Description: Handles client remote properties. Inspiration from Sleitnick

local Parent: Instance = script.Parent

--\\ Modules //--
local Indexing = require(Parent.Parent.Indexing)
local Oath = Indexing("Oath")
local Signal = Indexing("Signal")
local ClientRemoteSignal = require(Parent.ClientRemoteSignal)
local Types = require(Parent.Parent.Types)

--\\ Module Code //--
local ClientRemoteProperty = {}
ClientRemoteProperty.__index = ClientRemoteProperty

function ClientRemoteProperty.new(re: RemoteEvent, inboundRoute: Types.ClientRoute?, outboudRoute: Types.ClientRoute?)
	local self = setmetatable({}, ClientRemoteProperty)
	self._rs = ClientRemoteSignal.new(re, inboundRoute, outboudRoute)
	self._ready = false
	self._value = nil
	self.Changed = Signal.new()
	self._readyOath = self:OnReady():Follow(function()
		self._readyOath = nil
		self.Changed:Fire(self._value)
		self._changed = self._rs:Connect(function(value)
			if value == self._value then return end
			self._value = value
			self.Changed:Fire(value)
		end)
	end)
	self._rs:Fire()
	return self
end

function ClientRemoteProperty:Get(): any
	return self._value
end

function ClientRemoteProperty:OnReady()
	if self._ready then
		return Oath.resolve(self._value)
	end
	return Oath.fromEvent(self._rs, function(value)
		self._value = value
		self._ready = true
		return true
	end):Follow(function()
		return self._value
	end)
end

function ClientRemoteProperty:IsReady(): boolean
	return self._ready
end

function ClientRemoteProperty:Observe(observer: (any) -> ())
	if self._ready then
		task.defer(observer, self._value)
	end
	return self.Changed:Connect(observer)
end

function ClientRemoteProperty:Destroy()
	self._rs:Destroy()
	if self._readyOath then
		self._readyOath:cancel()
	end
	if self._changed then
		self._changed:Disconnect()
	end
	self.Changed:Destroy()
end

return ClientRemoteProperty
