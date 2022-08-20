-- !strict

-- Author: Alex/EnDarke
-- Description: Data Amenity for all server-sided data functions

local Parent = script.Parent

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite:WaitForChild("Unite"))
local Services = Unite.Services
local Settings = Unite.Settings
local Collection = Unite.Collection

--\\ Modules //--
local Account = require(Parent.Parent.Modules.Accounts)

local DataFormat = require(script.DataFormat)

--\\ Settings //--
local DataSettings = Settings.Data
local AdminSettings = Settings.Admin

--\\ Collection //--
local Util = Collection.Util

--\\ Variables //--
local PlayerStore = Account.GetAccountStore("Player", DataFormat)

local Accounts = {}

--\\ Module Code //--
local DataAmenity = Unite.ForgeAmenity {
    Name = "DataAmenity";
    Client = {};
}

--\\ Local Functions //--
local function onPlayerAdded(player: Player)
    local userId = player and player.UserId
    local account = PlayerStore:LoadAccountAsync(DataSettings.PlayerKey..userId, "ForceLoad")

    if account then
        account:ListenToRelease(function()
            Accounts[player] = nil
            player:Kick()
        end)

        if player:IsDescendantOf(Services.Players) then
            Accounts[player] = account
            --DataAmenity:AddCoins(player, 10)
            DataAmenity:Update(player)
            player:SetAttribute("DataLoaded", true)
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
function DataAmenity:ChangeValue(player: Player, section: string, name: string, value: any, override: boolean): boolean
    local data = DataAmenity.Client:Get(player)
    if data then
        local dataType = data[section][name]
        if dataType then
            if type(value) == "number" then
                if override then -- True | Sets dataType to 0 for setting the amount
                    dataType -= dataType
                end
                dataType += value
            elseif type(value) == "string" or type(value) == "boolean" then
                dataType = value
            elseif type(value) == "table" then
                dataType = Util._deepCopy(value)
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
    local data = DataAmenity.Client:Get(player)
    if data then
        Util._reconcileTable(data, DataFormat)
    else
        return false, 002
    end
end

function DataAmenity:Wipe(player: Player)
    local data = DataAmenity.Client:Get(player)
    if data then
        data = Util._deepCopy(DataFormat)
    else
        return false, 002
    end
end

--\\ Unite Start-Up //--
function DataAmenity:UniteInit()
    for _, player in ipairs(Services.Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    Services.Players.PlayerAdded:Connect(onPlayerAdded)
    Services.Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function DataAmenity:UniteStart()
    
end

return DataAmenity