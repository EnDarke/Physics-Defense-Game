-- !strict

-- Author: Alex/EnDarke
-- Description: Server for communication. Inspiration from Sleitnick

local Parent = script.Parent

--\\ Modules //--
local Util = require(Parent.Util)
local Types = require(Parent.Types)
local RemoteSignal = require(script.RemoteSignal)
local RemoteProperty = require(script.RemoteProperty)

--\\ Variables //--
local instance = Instance.new

--\\ Module Code //--
local Server = {}

function Server.BindFunction(parent: Instance, name: string, func: Types.FnBind, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?): RemoteFunction
    assert(Util.IsServer, "BindFunction must be called from the server")

    local folder = Util.GetCommSubFolder(parent, "RF"):Expect("Failed to get Commune RF folder")
    local rf = instance("RemoteFunction")
    rf.Name = name

    local hasInbound = type(inboundRoute) == "table" and #inboundRoute > 0
    local hasOutbound = type(outboundRoute) == "table" and #outboundRoute > 0

    local function processOutbound(player, ...)
        local args = table.pack(...)
        for _, routeFunc in ipairs(outboundRoute) do
            local routeResult = table.pack(routeFunc(player, args))
            if not routeResult[1] then
                return table.unpack(routeResult, 2, routeResult.n)
            end
            args.n = #args
        end
        return table.unpack(args, 1, args.n)
    end
    if hasInbound and hasOutbound then
        local function OnServerInvoke(player, ...)
            local args = table.pack(...)
            for _, routeFunc in ipairs(inboundRoute) do
                local routeResult = table.pack(routeFunc(player, args))
                if not routeResult[1] then
                    return table.unpack(routeResult, 2, routeResult.n)
                end
                args.n = #args
            end
            return processOutbound(player, func(player, table.unpack(args, 1, args.n)))
        end
        rf.OnServerInvoke = OnServerInvoke
    elseif hasInbound then
        local function OnServerInvoke(player, ...)
            local args = table.pack(...)
            for _, routeFunc in ipairs(inboundRoute) do
                local routeResult = table.pack(routeFunc(player, args))
                if not routeResult[1] then
                    return table.unpack(routeResult, 2, routeResult.n)
                end
                args.n = #args
            end
            return func(player, table.unpack(args, 1, args.n))
        end
        rf.OnServerInvoke = OnServerInvoke
    elseif hasOutbound then
        local function OnServerInvoke(player, ...)
            return processOutbound(player, func(player, ...))
        end
        rf.OnServerInvoke = OnServerInvoke
    else
        rf.OnServerInvoke = func
    end
    rf.Parent = folder
    return rf
end

function Server.Wrap(parent: Instance, tbl: {}, name: string, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?): RemoteFunction
	assert(Util.IsServer, "WrapMethod must be called from the server")
	local fn = tbl[name]
	assert(type(fn) == "function", "Value at index " .. name .. " must be a function; got " .. type(fn))
	return Server.BindFunction(parent, name, function(...)
        return fn(tbl, ...)
    end, inboundRoute, outboundRoute)
end


function Server.ForgeSignal(parent: Instance, name: string, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?)
	assert(Util.IsServer, "CreateSignal must be called from the server")
	local folder = Util.GetCommSubFolder(parent, "RE"):Expect("Failed to get Comm RE folder")
	local rs = RemoteSignal.new(folder, name, inboundRoute, outboundRoute)
	return rs
end


function Server.ForgeProperty(parent: Instance, name: string, initialValue: any, inboundRoute: Types.ServerRoute?, outboundRoute: Types.ServerRoute?)
	assert(Util.IsServer, "CreateProperty must be called from the server")
	local folder = Util.GetCommSubFolder(parent, "RP"):Expect("Failed to get Comm RP folder")
	local rp = RemoteProperty.new(folder, name, initialValue, inboundRoute, outboundRoute)
	return rp
end

return Server
