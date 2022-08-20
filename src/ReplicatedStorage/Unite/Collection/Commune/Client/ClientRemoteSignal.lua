-- !strict

-- Author: Alex/EnDarke
-- Description: Handles remote signals. Inspiration from Sleitnick

local Parent = script.Parent

--\\ Modules //--
local Signal = require(Parent.Parent.Parent.Signal)
local Types = require(Parent.Parent.Types)

--\\ Module Code //--
local ClientRemoteSignal = {}
ClientRemoteSignal.__index = ClientRemoteSignal

function ClientRemoteSignal.new(re: RemoteEvent, inboundRoute: Types.ClientRoute?, outboundRoute: Types.ClientRoute?)
	local self = setmetatable({}, ClientRemoteSignal)
	self._re = re
	if outboundRoute and #outboundRoute > 0 then
		self._hasOutbound = true
		self._outbound = outboundRoute
	else
		self._hasOutbound = false
	end
	if inboundRoute and #inboundRoute > 0 then
		self._directConnect = false
		self._signal = Signal.new()
		self._reConn = self._re.OnClientEvent:Connect(function(...)
			local args = table.pack(...)
			for _, RouteFunc in ipairs(inboundRoute) do
				local RouteResult = table.pack(RouteFunc(args))
				if not RouteResult[1] then
					return
				end
				args.n = #args
			end
			self._signal:Fire(table.unpack(args, 1, args.n))
		end)
	else
		self._directConnect = true
	end
	return self
end

function ClientRemoteSignal:_processOutboundRoute(...: any)
	local args = table.pack(...)
	for _, RouteFunc in ipairs(self._outbound) do
		local RouteResult = table.pack(RouteFunc(args))
		if not RouteResult[1] then
			return table.unpack(RouteResult, 2, RouteResult.n)
		end
		args.n = #args
	end
	return table.unpack(args, 1, args.n)
end

function ClientRemoteSignal:Connect(fn: (...any) -> ())
	if self._directConnect then
		return self._re.OnClientEvent:Connect(fn)
	else
		return self._signal:Connect(fn)
	end
end

function ClientRemoteSignal:Fire(...: any)
	if self._hasOutbound then
		self._re:FireServer(self:_processOutboundRoute(...))
	else
		self._re:FireServer(...)
	end
end

function ClientRemoteSignal:Destroy()
	if self._signal then
		self._signal:Destroy()
	end
end

return ClientRemoteSignal