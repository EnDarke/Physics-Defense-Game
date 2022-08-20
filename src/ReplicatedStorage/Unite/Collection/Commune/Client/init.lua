-- !strict

-- Author: Alex/EnDarke
-- Description: Handles client remote handling

--\\ Modules //--
local Util = require(script.Parent.Util)
local Types = require(script.Parent.Types)
local Oath = require(script.Parent.Parent.Oath)
local ClientRemoteSignal = require(script.ClientRemoteSignal)
local ClientRemoteProperty = require(script.ClientRemoteProperty)

--\\ Module Code //--
local Client = {}

function Client.GetFunction(parent: Instance, name: string, useOath: boolean, inboundRoute: Types.ClientRoute?, outboundRoute: Types.ClientRoute?)
	assert(not Util.IsServer, "GetFunction must be called from the client")
	local folder = Util.GetCommSubFolder(parent, "RF"):Expect("Failed to get Comm RF folder")
	local rf = folder:WaitForChild(name, Util.WaitForChildTimeout)
	assert(rf ~= nil, "Failed to find RemoteFunction: " .. name)
	local hasInbound = type(inboundRoute) == "table" and #inboundRoute > 0
	local hasOutbound = type(outboundRoute) == "table" and #outboundRoute > 0
	local function ProcessOutbound(args)
		for _,RouteFunc in ipairs(outboundRoute) do
			local RouteResult = table.pack(RouteFunc(args))
			if not RouteResult[1] then
				return table.unpack(RouteResult, 2, RouteResult.n)
			end
			args.n = #args
		end
		return table.unpack(args, 1, args.n)
	end
	if hasInbound then
		if useOath then
			return function(...)
				local args = table.pack(...)
				return Oath.new(function(resolve, reject)
					local success, res = pcall(function()
						if hasOutbound then
							return table.pack(rf:InvokeServer(ProcessOutbound(args)))
						else
							return table.pack(rf:InvokeServer(table.unpack(args, 1, args.n)))
						end
					end)
					if success then
						for _,RouteFunc in ipairs(inboundRoute) do
							local RouteResult = table.pack(RouteFunc(res))
							if not RouteResult[1] then
								return table.unpack(RouteResult, 2, RouteResult.n)
							end
							res.n = #res
						end
						resolve(table.unpack(res, 1, res.n))
					else
						reject(res)
					end
				end)
			end
		else
			return function(...)
				local res
				if hasOutbound then
					res = table.pack(rf:InvokeServer(ProcessOutbound(table.pack(...))))
				else
					res = table.pack(rf:InvokeServer(...))
				end
				for _,RouteFunc in ipairs(inboundRoute) do
					local RouteResult = table.pack(RouteFunc(res))
					if not RouteResult[1] then
						return table.unpack(RouteResult, 2, RouteResult.n)
					end
					res.n = #res
				end
				return table.unpack(res, 1, res.n)
			end
		end
	else
		if useOath then
			return function(...)
				local args = table.pack(...)
				return Oath.new(function(resolve, reject)
					local success, res = pcall(function()
						if hasOutbound then
							return table.pack(rf:InvokeServer(ProcessOutbound(args)))
						else
							return table.pack(rf:InvokeServer(table.unpack(args, 1, args.n)))
						end
					end)
					if success then
						resolve(table.unpack(res, 1, res.n))
					else
						reject(res)
					end
				end)
			end
		else
			if hasOutbound then
				return function(...)
					return rf:InvokeServer(ProcessOutbound(table.pack(...)))
				end
			else
				return function(...)
					return rf:InvokeServer(...)
				end
			end
		end
	end
end


function Client.GetSignal(parent: Instance, name: string, inboundRoute: Types.ClientRoute?, outboundRoute: Types.ClientRoute?)
	assert(not Util.IsServer, "GetSignal must be called from the client")
	local folder = Util.GetCommSubFolder(parent, "RE"):Expect("Failed to get Comm RE folder")
	local re = folder:WaitForChild(name, Util.WaitForChildTimeout)
	assert(re ~= nil, "Failed to find RemoteEvent: " .. name)
	return ClientRemoteSignal.new(re, inboundRoute, outboundRoute)
end


function Client.GetProperty(parent: Instance, name: string, inboundRoute: Types.ClientRoute?, outboundRoute: Types.ClientRoute?)
	assert(not Util.IsServer, "GetProperty must be called from the client")
	local folder = Util.GetCommSubFolder(parent, "RP"):Expect("Failed to get Comm RP folder")
	local re = folder:WaitForChild(name, Util.WaitForChildTimeout)
	assert(re ~= nil, "Failed to find RemoteEvent for RemoteProperty: " .. name)
	return ClientRemoteProperty.new(re, inboundRoute, outboundRoute)
end

return Client