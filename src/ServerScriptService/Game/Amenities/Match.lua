-- !strict

-- Author: Alex/EnDarke
-- Description: Handles back-end match systems

local Parent: Instance = script.Parent

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite:WaitForChild("Unite"))
local services: {} = Unite.Services
local settings: {} = Unite.Settings
local collection: {} = Unite.Collection
local signals: {} = Unite.Signals

--\\ Modules //--
local gridClass: {} = require(services.ReplicatedStorage.Modules:WaitForChild("Grid"))
local pathfindingClass: {} = require(services.ReplicatedStorage.Modules:WaitForChild("Pathfinding"))

--\\ Types //--
type Amenity = {
    Name: string;
    Client: {[any]: any};
    [any]: any;
}

--\\ Settings //--
local matchSettings: {} = settings.Match

local intermissionTime = matchSettings.Intermission_Time
local matchTime = matchSettings.Total_Time
local castleHealth = matchSettings.Castle_Health

--\\ Collection //--
local commune = collection.Commune

--\\ Variables //--
local map: Folder = workspace.Map

local essentials = map.Essentials
local castle = essentials.Castle

local scriptables: Folder = workspace.Scriptables
local mobs: Folder = scriptables.Mobs

local storage: Folder = services.ReplicatedStorage.Storage
local mobStorage: Folder = storage.Mobs

local playArea: Part = map.Essentials:WaitForChild("Base")

--\\ Module Code //--
local MatchAmenity: Amenity = Unite.ForgeAmenity {
    Name = "MatchAmenity";
    Client = {};
}

--\\ Local Functions //--
local function createMob()
    local attacker = mobStorage:WaitForChild("Attacker"):Clone()
    attacker:PivotTo(CFrame.new(Vector3.new(Random.new():NextInteger(-27, 33), 5, Random.new():NextInteger(-83, -63))))
    services.Collection:AddTag(attacker, "Mob")
    attacker.Parent = mobs
end

--\\ Unite Start-Up //--
function MatchAmenity:UniteInit()
    self.DataAmenity = Unite.AcquireAmenity("DataAmenity")

    self.GridClass = gridClass.new(playArea)
    self.PathClass = pathfindingClass.new(self.GridClass)
end

function MatchAmenity:UniteStart()
    local healthGui = castle.PrimaryPart:WaitForChild("HealthGui")

    coroutine.wrap(function()
        while task.wait() do
            -- Start Intermission Timer
            for count = intermissionTime, 1, -1 do
                signals.Announce:FireAll(("MATCH STARTING IN %d SECONDS..."):format(count))
                task.wait(1) -- So it counts down on an accurate time.
            end

            -- Starting Match Display
            signals.Announce:FireAll("UNLEASH THE SPHERES")

            -- Setup Match
            local CastleIsLiving = true
            castle:SetAttribute("Health", castleHealth)
            services.Collection:AddTag(castle, "Castle")

            healthGui.Enabled = true

            -- Start Match Timer
            for count = matchTime, 1, -1 do
                if count < (matchTime - 2) then
                    signals.Announce:FireAll(("THERE ARE %d SECONDS LEFT..."):format(count))
                end

                -- Spawn Mob
                createMob()

                -- Check if the castle is dead
                if castle:GetAttribute("Health") <= 0 then
                    CastleIsLiving = false
                    break
                end

                task.wait(1)
            end

            -- Mob Clean-Up
            mobs:ClearAllChildren()

            -- Run win/lose code
            if CastleIsLiving then
                signals.Announce:FireAll("YOU SURVIVED!")

                -- Reward players for their win!
                for _, player in ipairs(services.Players:GetPlayers()) do
                    self.DataAmenity:ChangeValue(player, "Core", "Wins", 1)
                end
            else
                signals.Announce:FireAll("YOU LOST!")
            end
            task.wait(3) -- Leave message up for x time

            -- Post Match
            healthGui.Enabled = false
        end
    end)()
end

return MatchAmenity