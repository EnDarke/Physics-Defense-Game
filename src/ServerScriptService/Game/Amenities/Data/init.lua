-- !strict

-- Author: Alex/EnDarke
-- Description: Data Amenity for all server-sided data functions

local Parent: Instance = script.Parent

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite:WaitForChild("Unite"))
local services = Unite.Services
local settings = Unite.Settings
local collection = Unite.Collection

--\\ Modules //--
local Account = require(Parent.Parent.Modules.Accounts)

local DataFormat = require(script.DataFormat)

--\\ Settings //--
local DataSettings = settings.Data
local AdminSettings = settings.Admin

--\\ Collection //--
local Util = collection.Util

--\\ Variables //--
local PlayerStore = Account.GetAccountStore("Player", DataFormat)

local Accounts = {}

local instance = Instance.new

--\\ Module Code //--
local DataAmenity = Unite.ForgeAmenity {
    Name = "DataAmenity";
    Client = {};
}

--\\ Local Functions //--
local function setObjectCollisionsRecursive(object: Instance, collisionGroup: string)
    if object:IsA("BasePart") then
        services.Physics:SetPartCollisionGroup(object, collisionGroup)
    end

    for _, child in ipairs(object:GetChildren()) do
        setObjectCollisionsRecursive(child, collisionGroup)
    end
end

local function onPlayerAdded(player: Player)
    local userId = player and player.UserId
    local account = PlayerStore:LoadAccountAsync(DataSettings.PlayerKey..userId, "ForceLoad")

    if account then
        account:ListenToRelease(function()
            Accounts[player] = nil
            player:Kick()
        end)

        if player:IsDescendantOf(services.Players) then
            Accounts[player] = account
            DataAmenity:Update(player)

            -- Setup leaderstats for the player
            local leaderstats = instance("Folder")
            leaderstats.Name = "leaderstats"
            leaderstats.Parent = player

            for name, value in pairs(account.Data.Core) do
                if type(value) == "number" then
                    local obj = instance("NumberValue")
                    obj.Name = name
                    obj.Value = value
                    obj.Parent = leaderstats
                end
            end

            --[[local wins = instance("NumberValue")
            wins.Name = "Wins"
            wins.Value = account.Data.Core.Wins
            wins.Parent = leaderstats

            local kills = instance("NumberValue")
            kills.Name = "Kills"
            kills.Value = account.Data.Core.Kills
            kills.Parent = leaderstats]]

            -- Waiting on Character to setup collisions
            local character = player.Character or player.CharacterAdded:Wait()
            setObjectCollisionsRecursive(character, "User")

            -- Setup player attributes
            player:SetAttribute("LastShot", workspace:GetServerTimeNow())
            player:SetAttribute("DataLoaded", true) -- Lets the client know when to proceed with initialization
        else
            account:Release()
        end
    else
        player:Kick(AdminSettings.KickMessages[1])
    end
end

local function onPlayerRemoving(player: Player)
    local account = Accounts[player]
    if account then
        account:Release()
    end
end

--\\ Unite Client //--
function DataAmenity.Client:Get(player: Player)
    local account = Accounts[player]
    if account then
        return account.Data
    else
        return false, 001
    end
end

--\\ Unite Server //--
function DataAmenity:Get(player: Player)
    local account = Accounts[player]
    if account then
        return account.Data
    else
        return false, 001
    end
end

function DataAmenity:ChangeValue(player: Player, section: string, name: string, value: any, override: boolean): boolean
    local data = DataAmenity:Get(player)
    if data then
        if data[section][name] then
            if type(value) == "number" then
                if override then -- True | Sets dataType to 0 for setting the amount
                    data[section][name] -= data[section][name]
                end
                data[section][name] += value
            elseif type(value) == "string" or type(value) == "boolean" then
                data[section][name] = value
            elseif type(value) == "table" then
                data[section][name] = Util._deepCopy(value)
            end

            -- Change leaderstats
            local leaderHasData = player.leaderstats:FindFirstChild(name)
            if leaderHasData then
                leaderHasData.Value = data[section][name]
            end
            return true
        else
            return false, 003
        end
    else
        return false, 002
    end
end

function DataAmenity:Update(player: Player)
    local userId = player and player.UserId
    local account = Accounts[player]
    if account then
        account:Reconcile()
    else
        return false, 002
    end
end

function DataAmenity:Wipe(player: Player)
    local userId = player and player.UserId
    local account = Accounts[player]
    if account then
        account:WipeAccountAsync(DataSettings.PlayerKey..userId)
    else
        return false, 002
    end
end

--\\ Unite Start-Up //--
function DataAmenity:UniteInit()
    for _, player in ipairs(services.Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    services.Players.PlayerAdded:Connect(onPlayerAdded)
    services.Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function DataAmenity:UniteStart()
    
end

return DataAmenity