local DataStoreService = game:GetService("DataStoreService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
-- !strict

-- Author: Alex/EnDarke
-- Description: Framework server handling. Inspired by the great Knit framework by Sleitnick and his team.

local Parent = script.Parent

--\\ Types //--
type Route = {
    Inbound: ServerRoute?;
    Outbound: ServerRoute?;
}

type ServerRouteFunction = (player: Player, args: {any}) -> (boolean, ...any)

type ServerRoute = {ServerRoute}

type AmenityDef = {
    Name: string,
    Client: {[any]: any}?;
    Route: Route?;
    [any]: any;
}

type Amenity = {
    Name: string;
    Client: {[any]: any}?;
    Route: Route?;
    [any]: any;
}

type AmenityClient = {
    Server: Amenity;
    [any]: any;
}

type UniteOptions = {
    Route: Route?;
}

--\\ Setup //--
local UniteServer = {}

-- Getting the collection setup
UniteServer.Collection = {}
for _, module in ipairs(Parent.Parent.Collection:GetChildren()) do
    if module:IsA("ModuleScript") then
        UniteServer.Collection[module.Name] = require(module)
    else
        continue
    end
end

local normalOptions: UniteOptions = {
    Route = nil;
}

local chosenOptions = nil

local SignalMarker = newproxy(true)
getmetatable(SignalMarker).__tostring = function()
    return "SignalMarker"
end

local PropertyMarker = newproxy(true)
getmetatable(PropertyMarker).__tostring = function()
    return "PropertyMarker"
end

local instance = Instance.new

local uniteRefAmenityFolder = instance("Folder")
uniteRefAmenityFolder.Name = "Amenities"

local Oath = UniteServer.Collection.Oath
local Commune = UniteServer.Collection.Commune
local ServerCommune = Commune.ServerCommune

local amenities: {[string]: Amenity} = {}
local awoken = false
local awokenComplete = false
local onAwokenComplete = instance("BindableEvent")

--\\ Adding Services //--
UniteServer.Services = {
    -- Explorer Services
    Players = game:GetService("Players");
    Lighting = game:GetService("Lighting");
    ReplicatedStorage = game:GetService("ReplicatedStorage");
    ServerScriptService = game:GetService("ServerScriptService");
    ServerStorage = game:GetService("ServerStorage");
    Teams = game:GetService("Teams");
    Sound = game:GetService("SoundService");
    Chat = game:GetService("Chat");

    -- Other Services
    Run = game:GetService("RunService");
    Http = game:GetService("HttpService");
    DataStore = game:GetService("DataStoreService");
    Tween = game:GetService("TweenService");
    Marketplace = game:GetService("MarketplaceService");
    Badge = game:GetService("BadgeService");
    UserInput = game:GetService("UserInputService");
    PathfindingService = game:GetService("PathfindingService");
    ContextAction = game:GetService("ContextActionService");
}

--\\ Local Utility Functions //--
local function AmenityLives(amenityName: string): boolean
    local amenity: Amenity? = amenities[amenityName]
    return amenity ~= nil
end

--\\ Module Code //--
function UniteServer.ForgeAmenity(amenityDef: AmenityDef): Amenity
    -- Assertion Hookes so wrong information isn't passed through
    assert(type(amenityDef) == "table", "Amenity must be a table. Got " .. type(amenityDef))
    assert(type(amenityDef.Name) == "string", "Amenity.Name must be a string. Got " .. type(amenityDef.Name))
    assert(#amenityDef.Name > 0, "Amenity.Name must be a non-empty string")
    assert(not AmenityLives(amenityDef.Name), "Amenity \"" .. amenityDef.Name .. "\" already exists")

    -- Forging a new amenity and giving it a form of communication
    local amenity = amenityDef
    amenity.UniteCommune = ServerCommune.new(uniteRefAmenityFolder, amenityDef.Name)

    -- If neither are what they're supposed to be, then set them to be
    if type(amenity.Client) ~= "table" then
        amenity.Client = {Server = amenity}
    else
        if amenity.Client.Server ~= amenity then
            amenity.Client.Server = amenity
        end
    end

    -- Adding the amenity to the amenities list
    amenities[amenity.Name] = amenity

    -- Return giving amenity :)
    return amenity
end

function UniteServer.AppendSingularAmenity(instance: Instance): Amenity
    local amenity = require(instance)
    if amenity then
        return amenity
    end
end

function UniteServer.AppendAmenities(parent: Instance, isExtensive: boolean): {Amenity}
    local appendedAmenities = {}
    for _, v in ipairs(isExtensive and parent:GetDescendants() or parent:GetChildren()) do
        if not v:IsA("ModuleScript") then
            continue
        end
        table.insert(appendedAmenities, require(v))
    end
    return appendedAmenities
end

function UniteServer.AcquireAmenity(amenityName: string): Amenity
    assert(awoken, "Cannot call AcquireAmenity until Unite has awoken")
    assert(type(amenityName) == "string", "AmenityName must be a string: Got " .. type(amenityName))
    return assert(amenities[amenityName], "Could not find amenity \"" .. amenityName .. "\"") :: Amenity
end

function UniteServer.ForgeSignal()
    return SignalMarker
end

function UniteServer.ForgeProperty()
    return PropertyMarker
end

function UniteServer.Start(options: UniteOptions?)
    if awoken then
        return Oath.Reject("Unite already started")
    end

    awoken = true

    if options == nil then
        chosenOptions = normalOptions
    else
        assert(typeof(options) == "table", "Why isn't UniteOptions a table or nil? I ended up getting " .. typeof(options))
        
        chosenOptions = options

        for opt, val in pairs(normalOptions) do
            if chosenOptions[opt] == nil then
                chosenOptions[opt] = val
            end
        end
    end

    return Oath.new(function(resolve)
        local uniteRoute = chosenOptions.Route or {}

        for _, amenity in pairs(amenities) do
            local route = amenity.Route or {}
            local inbound = route.Inbound or uniteRoute.Inbound
            local outbound = route.Outbound or uniteRoute.Outbound
            
            amenity.Route = nil

            for opt, val in pairs(amenity.Client) do
                if type(val) == "function" then
                    amenity.UniteCommune:Wrap(amenity.Client, opt, inbound, outbound)
                elseif val == SignalMarker then
                    amenity.Client[opt] = amenity.UniteCommune:ForgeSignal(opt, inbound, outbound)
                elseif type(val) == "table" and val[1] == PropertyMarker then
                    amenity.Client[opt] = amenity.UniteCommune:ForgeProperty(opt, val[2], inbound, outbound)
                end
            end
        end

        local oathsInitAmenities = {}
        for _, amenity in pairs(amenities) do
            if type(amenity.UniteStart) == "function" then
                table.insert(oathsInitAmenities, Oath.new(function(r)
                    debug.setmemorycategory(amenity.Name)
                    amenity:UniteInit()
                    r()
                end))
            end
        end

        resolve(Oath.All(oathsInitAmenities))
    end):Follow(function()
        for _, amenity in pairs(amenities) do
            if type(amenity.UniteStart) == "function" then
                task.spawn(function()
                    debug.setmemorycategory(amenity.Name)
                    amenity:UniteStart()
                end)
            end
        end

        awokenComplete = true
        onAwokenComplete:Fire()

        task.defer(function()
            onAwokenComplete:Destroy()
        end)

        uniteRefAmenityFolder.Parent = script.Parent
    end)
end

function UniteServer.OnStart()
    if awokenComplete then
        return Oath.Resolve()
    else
        return Oath.fromEvent(onAwokenComplete.Event)
    end
end

return UniteServer