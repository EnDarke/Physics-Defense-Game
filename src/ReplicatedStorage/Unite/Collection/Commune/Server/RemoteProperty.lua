-- !strict

-- Author: Alex/EnDarke
-- Description: Handles remote properties. Inspiration from Sleitnick

--\\ Services //--
local Players = game:GetService("Players")

--\\ Modules //--
local Util = require(script.Parent.Parent.Util)
local Types = require(script.Parent.Parent.Types)
local RemoteSignal = require(script.Parent.RemoteSignal)

--\\ Variables //--
local None = Util.None

--\\ Module Code //--
local RemoteProperty = {}
RemoteProperty.__index = RemoteProperty

function RemoteProperty.new(parent: Instance, name: string, initialValue: any, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?)
	local self = setmetatable({}, RemoteProperty)
	self._rs = RemoteSignal.new(parent, name, inboundRoute, outboundRoute)
	self._value = initialValue
	self._perPlayer = {}
	self._playerRemoving = Players.PlayerRemoving:Connect(function(player)
		self._perPlayer[player] = nil
	end)
	self._rs:Connect(function(player)
		local playerValue = self._perPlayer[player]
		local value = if playerValue == nil then self._value elseif playerValue == None then nil else playerValue
		self._rs:Fire(player, value)
	end)
	return self
end

function RemoteProperty:Set(value: any)
	self._value = value
	table.clear(self._perPlayer)
	self._rs:FireAll(value)
end

function RemoteProperty:SetTop(value: any)
	self._value = value
	for _,player in ipairs(Players:GetPlayers()) do
		if self._perPlayer[player] == nil then
			self._rs:Fire(player, value)
		end
	end
end

function RemoteProperty:SetFilter(predicate: (Player, any) -> boolean, value: any)
	for _,player in ipairs(Players:GetPlayers()) do
		if predicate(player, value) then
			self:SetFor(player, value)
		end
	end
end

function RemoteProperty:SetFor(player: Player, value: any)
	if player.Parent then
		self._perPlayer[player] = if value == nil then None else value
	end
	self._rs:Fire(player, value)
end

function RemoteProperty:SetForList(players: {Player}, value: any)
	for _,player in ipairs(players) do
		self:SetFor(player, value)
	end
end

function RemoteProperty:ClearFor(player: Player)
	if self._perPlayer[player] == nil then return end
	self._perPlayer[player] = nil
	self._rs:Fire(player, self._value)
end

function RemoteProperty:ClearForList(players: {Player})
	for _,player in ipairs(players) do
		self:ClearFor(player)
	end
end

function RemoteProperty:ClearFilter(predicate: (Player) -> boolean)
	for _,player in ipairs(Players:GetPlayers()) do
		if predicate(player) then
			self:ClearFor(player)
		end
	end
end

function RemoteProperty:Get(): any
	return self._value
end

function RemoteProperty:GetFor(player: Player): any
	local playerValue = self._perPlayer[player]
	local value = if playerValue == nil then self._value elseif playerValue == None then nil else playerValue
	return value
end

function RemoteProperty:Destroy()
	self._rs:Destroy()
	self._playerRemoving:Disconnect()
end

return RemoteProperty