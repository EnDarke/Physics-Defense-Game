-- !strict

-- Author: Alex/EnDarke
-- Description: Handles communication for the client. Inspiration from Sleitnick

local Parent: Instance = script.Parent

--\\ Modules //--
local Commune = require(Parent)
local Util = require(Parent.Parent.Util)
local Types = require(Parent.Parent.Types)

--\\ Module Code //--
local ClientCommune = {}
ClientCommune.__index = ClientCommune

function ClientCommune.new(parent: Instance, useOath: boolean, namespace: string?)
	assert(not Util.IsServer, "ClientComm must be constructed from the client")
	assert(typeof(parent) == "Instance", "Parent must be of type Instance")
	local ns = Util.DefaultCommFolderName
	if namespace then
		ns = namespace
	end
	local folder: Instance? = parent:WaitForChild(ns, Util.WaitForChildTimeout)
	assert(folder ~= nil, "Could not find namespace for ClientComm in parent: " .. ns)
	local self = setmetatable({}, ClientCommune)
	self._instancesFolder = folder
	self._useOath = useOath
	return self
end

function ClientCommune:GetFunction(name: string, inboundRoute: Types.ClientRoute?, outboundRoute: Types.ClientRoute?)
	return Commune.GetFunction(self._instancesFolder, name, self._useOath, inboundRoute, outboundRoute)
end

function ClientCommune:GetSignal(name: string, inboundRoute: Types.ClientRoute?, outboundRoute: Types.ClientRoute?)
	return Commune.GetSignal(self._instancesFolder, name, inboundRoute, outboundRoute)
end

function ClientCommune:GetProperty(name: string, inboundRoute: Types.ClientRoute?, outboundRoute: Types.ClientRoute?)
	return Commune.GetProperty(self._instancesFolder, name, inboundRoute, outboundRoute)
end

function ClientCommune:ConstructObject(inboundRoute: Types.ClientRoute?, outboundRoute: Types.ClientRoute?)
	local obj = {}
	local rfFolder = self._instancesFolder:FindFirstChild("RF")
	local reFolder = self._instancesFolder:FindFirstChild("RE")
	local rpFolder = self._instancesFolder:FindFirstChild("RP")
	if rfFolder then
		for _,rf in ipairs(rfFolder:GetChildren()) do
			if not rf:IsA("RemoteFunction") then continue end
			local f = self:GetFunction(rf.Name, inboundRoute, outboundRoute)
			obj[rf.Name] = function(_self, ...)
				return f(...)
			end
		end
	end
	if reFolder then
		for _,re in ipairs(reFolder:GetChildren()) do
			if not re:IsA("RemoteEvent") then continue end
			obj[re.Name] = self:GetSignal(re.Name, inboundRoute, outboundRoute)
		end
	end
	if rpFolder then
		for _,re in ipairs(rpFolder:GetChildren()) do
			if not re:IsA("RemoteEvent") then continue end
			obj[re.Name] = self:GetProperty(re.Name, inboundRoute, outboundRoute)
		end
	end
	return obj
end

return ClientCommune