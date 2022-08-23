-- !strict

-- Author: Alex/EnDarke
-- Description: Handles mob functionality

local Parent: Instance = script.Parent

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local services = Unite.Services
local collection = Unite.Collection

--\\ Types //--
type Node = {Node}
type NodeList = {[any]: Node}

--\\ Collection //--
local Minion = collection.Minion
local Util = collection.Util

--\\ Variables //--
local map = workspace.Map
local scriptables = workspace.Scriptables
local attackTrigger = scriptables.AttackTrigger

local vector3 = Util.Vector3
local tweenInfo = TweenInfo.new

local raycastParams = RaycastParams.new
local downRayParams = raycastParams()
downRayParams.FilterType = Enum.RaycastFilterType.Blacklist
downRayParams.FilterDescendantsInstances = {map.Essentials}

--\\ Local Utility Functions //--
local function raycastDown(position: Vector3)
    return workspace:Raycast(position, vector3.down * 1000, downRayParams)
end

--\\ Module Code //--
local Mob = {}
Mob.__index = Mob
Mob.Tag = "Mob"

function Mob.new(instance: Instance)
    local self = setmetatable({}, Mob)
    
    -- Mob Setup
    self.instance = instance
    self.target = attackTrigger

    -- Mob Stat Setup
    self.speed = 40
    self.path = {}
    self.targetIndex = 0

    -- Set Mob Collision Group
    services.Physics:SetPartCollisionGroup(self.instance, "User")

    -- Setup Mob with Minion
    print("Created Mob")
    self._minion = Minion.new()
    self._minion:GiveTask(function()
        print("Destroyed Mob")
    end)
    return self
end

-- Initialization function for elements
function Mob:Init()
    self.pathRequestAmenity = Unite.AcquireAmenity("PathRequestAmenity")

    local pathRequestInfo = {
        object = self;
        startPos = self.instance.Position;
        endPos = self.target.Position;
    }
    self.pathRequestAmenity:AddPathRequest(pathRequestInfo)

    self.instance:SetAttribute("Hit", false)
    self._minion:GiveTask(self.instance.AttributeChanged:Connect(function(attribute)
        if attribute == "Hit" and self.instance:GetAttribute("Hit") == true then
            -- Stop it's movement tween
            self.moveTween:Destroy()

            -- Clean-up
            task.wait(10)
            if self.instance then
                self.instance:Destroy()
            end
        end
    end))
end

function Mob:OnPathFound(newPath: NodeList)
    if newPath then
        self.path = newPath
        self:FollowPath()
    end
end

function Mob:FollowPath()
    coroutine.wrap(function()
        local currentWaypoint = self.path[1]

        self.instance.Anchored = false
        self.instance:SetNetworkOwner(nil)
        self.instance.Anchored = true

        for _, waypoint in ipairs(self.path) do
            if not self.gotHit then
                self.targetIndex += 1
                currentWaypoint = self.path[self.targetIndex]

                local _time = Util._getTimeFromDistance((self.instance.Position - currentWaypoint.worldPosition).Magnitude, self.speed)
                local newPos = raycastDown(currentWaypoint.worldPosition + (vector3.up * 20)).Position

                self.moveTween = services.Tween:Create(self.instance, tweenInfo(_time, Enum.EasingStyle.Linear), {
                    Position = newPos + (vector3.up * 3);
                })
                self.moveTween:Play()
                self.moveTween.Completed:Wait()
            end
        end

        local xCheck = self.instance.Position.X == currentWaypoint.worldPosition.X -- Checks if the x position is the same as the final waypoint
        local zCheck = self.instance.Position.Z == currentWaypoint.worldPosition.Z -- Checks if the z position is the same as the final waypoint
        if xCheck and zCheck then
            if not (map.Essentials.Castle:GetAttribute("Health") <= 0) then
                map.Essentials.Castle:SetAttribute("Health", map.Essentials.Castle:GetAttribute("Health") - 5)
            end
            self.instance:Destroy()
        end
    end)()
end

function Mob:Destroy()
    self.instance:SetAttribute("Hit", true)
    self._minion:Destroy()
end

return Mob