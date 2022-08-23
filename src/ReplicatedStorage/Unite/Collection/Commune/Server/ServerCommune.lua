-- !strict

-- Author: Alex/EnDarke
-- Description: Handles server communication functions. Inspiration from Sleitnick

local Parent: Instance = script.Parent

--\\ Modules //--
local Commune = require(Parent)
local Util = require(Parent.Parent.Util)
local Types = require(Parent.Parent.Types)

--\\ Module Code //--
local ServerCommune = {}
ServerCommune.__index = ServerCommune

function ServerCommune.new(parent: Instance, namespace: string?)
	assert(Util.IsServer, "ServerCommune must be constructed from the server")
	assert(typeof(parent) == "Instance", "Parent must be of type Instance")
	local ns = Util.DefaultCommFolderName
	if namespace then
		ns = namespace
	end
	assert(not parent:FindFirstChild(ns), "Parent already has another ServerCommune bound to namespace " .. ns)
	local self = setmetatable({}, ServerCommune)
	self._instancesFolder = Instance.new("Folder")
	self._instancesFolder.Name = ns
	self._instancesFolder.Parent = parent
	return self
end

function ServerCommune:BindFunction(name: string, fn: Types.FnBind, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?): RemoteFunction
	return Commune.BindFunction(self._instancesFolder, name, fn, inboundRoute, outboundRoute)
end

function ServerCommune:Wrap(tbl: {}, name: string, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?): RemoteFunction
	return Commune.Wrap(self._instancesFolder, tbl, name, inboundRoute, outboundRoute)
end

function ServerCommune:ForgeSignal(name: string, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?)
	return Commune.ForgeSignal(self._instancesFolder, name, inboundRoute, outboundRoute)
end

function ServerCommune:ForgeProperty(name: string, initialValue: any, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?)
	return Commune.ForgeProperty(self._instancesFolder, name, initialValue, inboundRoute, outboundRoute)
end

function ServerCommune:Destroy()
	self._instancesFolder:Destroy()
end

return ServerCommune