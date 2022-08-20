-- !strict

-- Author: Alex/EnDarke
-- Description: RemoteSignal module. Inspiration from Sleitnick

--\\ Services //--
local Players = game:GetService("Players")

--\\ Modules //--
local Signal = require(script.Parent.Parent.Parent.Signal)
local Types = require(script.Parent.Parent.Types)

--\\ Module Code //--
local RemoteSignal = {}
RemoteSignal.__index = RemoteSignal

function RemoteSignal.new(parent: Instance, name: string, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?)
	local self = setmetatable({}, RemoteSignal)
	self._re = Instance.new("RemoteEvent")
	self._re.Name = name
	self._re.Parent = parent
	if outboundRoute and #outboundRoute > 0 then
		self._hasOutbound = true
		self._outbound = outboundRoute
	else
		self._hasOutbound = false
	end
	if inboundRoute and #inboundRoute > 0 then
		self._directConnect = false
		self._signal = Signal.new()
		self._re.OnServerEvent:Connect(function(player, ...)
			local args = table.pack(...)
			for _,RouteFunc in ipairs(inboundRoute) do
				local RouteResult = table.pack(RouteFunc(player, args))
				if not RouteResult[1] then
					return
				end
				args.n = #args
			end
			self._signal:Fire(player, table.unpack(args, 1, args.n))
		end)
	else
		self._directConnect = true
	end
	return self
end

function RemoteSignal:Connect(fn)
	if self._directConnect then
		return self._re.OnServerEvent:Connect(fn)
	else
		return self._signal:Connect(fn)
	end
end

function RemoteSignal:_processOutboundRoute(player: Player?, ...: any)
	if not self._hasOutbound then
		return ...
	end
	local args = table.pack(...)
	for _,RouteFunc in ipairs(self._outbound) do
		local RouteResult = table.pack(RouteFunc(player, args))
		if not RouteResult[1] then
			return table.unpack(RouteResult, 2, RouteResult.n)
		end
		args.n = #args
	end
	return table.unpack(args, 1, args.n)
end

function RemoteSignal:Fire(player: Player, ...: any)
	self._re:FireClient(player, self:_processOutboundRoute(player, ...))
end

function RemoteSignal:FireAll(...: any)
	self._re:FireAllClients(self:_processOutboundRoute(nil, ...))
end

function RemoteSignal:FireExcept(ignorePlayer: Player, ...: any)
	self:FireFilter(function(plr)
		return plr ~= ignorePlayer
	end, ...)
end

function RemoteSignal:FireFilter(predicate: (Player, ...any) -> boolean, ...: any)
	for _,player in ipairs(Players:GetPlayers()) do
		if predicate(player, ...) then
			self._re:FireClient(player, self:_processOutboundRoute(nil, ...))
		end
	end
end

function RemoteSignal:FireFor(players: {Player}, ...: any)
	for _,player in ipairs(players) do
		self._re:FireClient(player, self:_processOutboundRoute(nil, ...))
	end
end

function RemoteSignal:Destroy()
	self._re:Destroy()
	if self._signal then
		self._signal:Destroy()
	end
end

return RemoteSignal