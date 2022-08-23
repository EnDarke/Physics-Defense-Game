-- !strict

-- Author: Alex/EnDarke
-- Description: Handles guns on the client

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite:WaitForChild("Unite"))
local services = Unite.Services
local settings = Unite.Settings
local collection = Unite.Collection

--\\ Collection //--
local Minion = collection.Minion

--\\ Variables //--
local map = workspace.Map
local invisibleWalls = map.InvisibleWalls

local storage = services.ReplicatedStorage.Storage
local gunStorage = storage.Guns

--\\ Module Code //--
local BlasterManager = Unite.ForgeManager {
    Name = "GunManager";
}

function BlasterManager.FireBullet()
    local currentTime = workspace:GetServerTimeNow()
    if currentTime - Unite.Player:GetAttribute("LastShot") >= 0.5 then
        if BlasterManager.currentBlaster:IsDescendantOf(Unite.Player.Character) then
            BlasterManager.blasterAmenity:RequestBulletFire(BlasterManager.mouse.Hit.Position):Follow(function()
                print("Bullet has successfully been fired.")
            end)
        end
    end
end

function BlasterManager:UniteInit()
    BlasterManager.blasterAmenity = Unite.AcquireAmenity("BlasterAmenity")

    BlasterManager.character = Unite.Player.Character or Unite.Player.CharacterAdded:Wait()
    BlasterManager.backpack = Unite.Player.Backpack
    BlasterManager.mouse = Unite.Player:GetMouse()
    BlasterManager.mouse.TargetFilter = invisibleWalls

    BlasterManager._minion = Minion.new()
end

function BlasterManager:UniteStart()
    local Blaster = gunStorage.Blaster:Clone()
    Blaster.Parent = BlasterManager.backpack

    BlasterManager.currentBlaster = Blaster

    BlasterManager._minion:GiveTask(BlasterManager.mouse.Button1Down:Connect(BlasterManager.FireBullet))
end

return BlasterManager