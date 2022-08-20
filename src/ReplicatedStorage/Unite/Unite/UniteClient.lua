-- !strict

-- Author: Alex/EnDarke
-- Description: Framework client handling. Inspired by the great Knit framework by Sleitnick and his team.

local Parent = script.Parent

--\\ Services //--
local Players = game:GetService("Players")

--\\ Types //--
type Route = {
    Inbound: ClientRoute?;
    Outbound: ClientRoute?;
}

type ClientRouteFunction = (args: {any}) -> (boolean, ...any)

type ClientRoute = {ClientRouteFunction}

type PerAmenityRoute = {[string]: Route}

type ManagerDef = {
    Name: string;
    [any]: any;
}

type Manager = {
    Name: string;
    [any]: any;
}

type Amenity = {
    [any]: any;
}

type UniteOptions = {
    AmenityOaths: boolean;
    Route: Route?;
    PerAmenityRoute: PerAmenityRoute?;
}

--\\ Setup //--
local UniteClient = {}
UniteClient.Player = Players.LocalPlayer

-- Getting the collection setup
UniteClient.Collection = {}
for _, module in ipairs(Parent.Parent.Collection:GetChildren()) do
    if module:IsA("ModuleScript") then
        UniteClient.Collection[module.Name] = require(module)
    else
        continue
    end
end

local normalOptions: UniteOptions = {
    AmenityOaths = true;
    Route = nil;
    PerAmenityRoute = {};
}

local chosenOptions = nil

local instance = Instance.new

local Oath = UniteClient.Collection.Oath
local Commune = UniteClient.Collection.Commune
local ClientCommune = Commune.ClientCommune

local managers: {[string]: Manager} = {}
local amenities: {[string]: Amenity} = {}
local amenitiesFolder = nil

local awoken = false
local awokenComplete = false
local onAwokenComplete = instance("BindableEvent")

--\\ Adding Services //--
UniteClient.Services = {
    -- Explorer Services
    Players = game:GetService("Players");
    Lighting = game:GetService("Lighting");
    ReplicatedStorage = game:GetService("ReplicatedStorage");
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
local function ManagerLives(managerName: string): boolean
    local manager: Manager? = managers[managerName]
    return manager ~= nil
end

local function AcquireAmenitiesFolder()
    if not amenitiesFolder then
        amenitiesFolder = Parent:WaitForChild("Amenities")
    end
    return amenitiesFolder
end

local function AcquireRouteForAmenity(amenityName: string)
    local uniteRoute = chosenOptions.Route or {}
    local amenityRoute = chosenOptions.PerAmenityRoute[amenityName]
    return amenityRoute or uniteRoute
end

local function ConstructAmenity(amenityName: string)
    local folder = AcquireAmenitiesFolder()
    local route = AcquireRouteForAmenity(amenityName)
    local clientCommune = ClientCommune.new(folder, chosenOptions.AmenityOaths, amenityName)
    local amenity = clientCommune:ConstructObject(route.Inbound, route.Outbound)

    amenities[amenityName] = amenity
    
    return amenity
end

--\\ Module Code //--
function UniteClient.ForgeManager(managerDef: ManagerDef): Manager
    assert(type(managerDef) == "table", "Manager must be a table: Got" .. type(managerDef))
    assert(type(managerDef.Name) == "string", "Manager.Name must be a string: Got " .. type(managerDef.Name))
    assert(#managerDef.Name > 0, "Manager.Name must be a non-empty string")
    assert(not ManagerLives(managerDef.Name), "Manager \"" .. managerDef.Name .. "\" already exists")

    local manager = managerDef :: Manager
    managers[manager.Name] = manager

    return manager
end

function UniteClient.AppendSingularManager(instance: Instance): Manager
    local manager = require(instance)
    if manager then
        return manager
    end
end

function UniteClient.AppendManagers(parent: Instance, isExtensive: boolean): {Manager}
    local appendedManagers = {}
    for _, v in ipairs(isExtensive and parent:GetDescendants() or parent:GetChildren()) do
        if not v:IsA("ModuleScript") then
            continue
        end
        table.insert(appendedManagers, require(v))
    end
    return appendedManagers
end

function UniteClient.AcquireAmenity(amenityName: string): Amenity
    local amenity = amenities[amenityName]

    if amenity then
        return amenity
    end
    
    assert(awoken, "Cannot call AcquireAmenity until Unite has started")
    assert(type(amenityName) == "string", "AmenityName must be a string: Got " .. type(amenityName))

    return ConstructAmenity(amenityName)
end

function UniteClient.AcquireManager(managerName: string): Manager
    local manager = managers[managerName]

    if manager then
        return manager
    end

    assert(awoken, "Cannot call AcquireManager until Unite has started")
    assert(type(managerName) == "string", "Why isn't the ManagerName a string? I ended up getting " .. type(managerName))

    error("Could not find manager \"" .. managerName .. "\". Double check that the manager with this name exists.", 2)
end

function UniteClient.Start(options: UniteOptions?)
    if awoken then
        return Oath.Reject("Unite already started")
    end

    awoken = true

    if not options then
        chosenOptions = normalOptions
    else
        assert(typeof(options) == "table", "Why isn't UniteOptions a table or nil? I ended up getting " .. typeof(options))

        chosenOptions = options

        for opt, val in pairs(chosenOptions) do
            if not chosenOptions[opt] then
                chosenOptions[opt] = val
            end
        end
    end

    if type(chosenOptions.PerAmenityRoute) ~= "table" then
        chosenOptions.PerAmenityRoute = {}
    end

    return Oath.new(function(resolve)
        local oathsAwakeManagers = {}

        for _, manager in pairs(managers) do
            if type(manager.UniteInit) == "function" then
                table.insert(oathsAwakeManagers, Oath.new(function(r)
                    debug.setmemorycategory(manager.Name)
                    manager:UniteInit()
                    r()
                end))
            end
        end

        resolve(Oath.All(oathsAwakeManagers))
    end):Follow(function()
        for _, manager in pairs(managers) do
            if type(manager.UniteStart) == "function" then
                task.spawn(function()
                    debug.setmemorycategory(manager.Name)
                    manager:UniteStart()
                end)
            end
        end

        awokenComplete = true
        onAwokenComplete:Fire()

        task.defer(function()
            onAwokenComplete:Destroy()
        end)
    end)
end

function UniteClient.OnStart()
    if awokenComplete then
        return Oath.Resolve()
    else
        return Oath.fromEvent(onAwokenComplete.Event)
    end
end

return UniteClient