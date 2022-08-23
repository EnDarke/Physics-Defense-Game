-- !strict

-- Author: Alex/EnDarke
-- Description: Handles blasters on the server

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite:WaitForChild("Unite"))
local services = Unite.Services
local settings = Unite.Settings
local collection = Unite.Collection

--\\ Collection //--
local TaskQueue = collection.TaskQueue
local Util = collection.Util

--\\ Variables //--
local map = workspace.Map
local invisibleWalls = map.InvisibleWalls

local scriptables = workspace.Scriptables
local bulletHolder = scriptables.Bullets

local storage = services.ReplicatedStorage.Storage
local bulletStorage = storage.Bullets
local miscStorage = storage.Misc

local instance = Instance.new
local raycastParams = RaycastParams.new

local vector3 = Util.Vector3

local log = math.log

local blasterRayParams = raycastParams()
blasterRayParams.FilterType = Enum.RaycastFilterType.Blacklist

--\\ Local Utility Functions //--
local function createBullet(spawnPosition: Vector3) -- Calculates and applies force based on positions
    local bullet: Instance = bulletStorage.Bullet:Clone()
    bullet.Position = spawnPosition
    bullet.Parent = bulletHolder
    return bullet
end

local function addVectorForceObject(object: Instance)
    if not (object:FindFirstChildOfClass("VectorForce")) then
        -- Add ForceAttachment for Vector force
        local forceAttachment = instance("Attachment")
        forceAttachment.Parent = object

        -- Add ZeroGravity Vector force
        local zeroGravityObject = miscStorage.ZeroGravity:Clone()
        zeroGravityObject.Force = vector3.new(0, workspace.Gravity * object.AssemblyMass, 0)
        zeroGravityObject.Attachment0 = forceAttachment
        zeroGravityObject.Parent = object
    end
end

local function applyImpulse(object: Instance, startPosition: Vector3, endPosition: Vector3)
    local objectDirection: Vector3 = startPosition - endPosition
    local impulseDuration: number = log(1.001 + objectDirection.Magnitude * 0.01)
    local impulseForce: Vector3 = objectDirection / impulseDuration + (vector3.up * (workspace.Gravity * impulseDuration * 0.5))
    object:ApplyImpulse(impulseForce * object.AssemblyMass)
end

--\\ Module Code //--
local BlasterAmenity = Unite.ForgeAmenity {
    Name = "BlasterAmenity";
    Client = {};
}

--\\ Unite Client //--
function BlasterAmenity.Client:RequestBulletFire(player: Player, mousePos: Vector3) -- Request bullet firing from the client to the server
    local currentTime = workspace:GetServerTimeNow()
    if currentTime - player:GetAttribute("LastShot") >= 0.5 then
        print(mousePos)
        blasterRayParams.FilterDescendantsInstances = {player.Character, invisibleWalls} -- Change descendant :)

        BlasterAmenity.bulletQueue:Add({Player = player, MousePos = mousePos}) -- Add bullet to the task queue
        player:SetAttribute("LastShot", currentTime)
    end
end

--\\ Unite Server //--
function BlasterAmenity.FireBullet(bullets: {}) -- Task Queue function that gathers all bullet instances and plays every bit of code for each
    local bulletEvents = {}

    -- Coroutine these so they run separately on a "different thread" on the server.
    coroutine.wrap(function()
        for bulletIndex, bulletReq in ipairs(bullets) do
            -- Presetting variables in relation to task queue items
            local player = bulletReq.Player
            local mousePos = bulletReq.MousePos

            -- Finding the character and right hand instance
            local character = player.Character
            local rightHand = character and character:FindFirstChild("RightHand")
            if rightHand then
                local rayResult = workspace:Raycast(rightHand.Position, (mousePos - rightHand.Position) * 300, blasterRayParams)
                if rayResult then
                    -- Creating the bullet and applying the force to said bullet to hit the target
                    local bullet: Instance = createBullet(rightHand.Position)
                    applyImpulse(bullet, mousePos, rightHand.Position)

                    -- Setting network owner to decrease sight of lag
                    task.wait()
                    bullet:SetNetworkOwner(player)

                    -- Check if the fired bullet hits anything
                    bulletEvents[bulletIndex] = bullet.Touched:Connect(function(touched)
                        if touched.Name == "Attacker" then -- Did it hit an attacker object?
                            if not touched:GetAttribute("Hit") then
                                BlasterAmenity.dataAmenity:ChangeValue(player, "Core", "Kills", 1)
                            end

                            -- Initiates object deletion after 10 seconds
                            touched:SetAttribute("Hit", true)
                            
                            touched.PowParticle:Emit(1)

                            -- Prep for force
                            touched.Anchored = false
                            touched.CanCollide = true

                            -- Add VectorForce object for ZeroGravity
                            addVectorForceObject(touched)

                            -- Apply hit force to enemy
                            applyImpulse(touched, touched.Position, bullet.Position)

                            -- Setting network owner to decrease sight of lag
                            touched:SetNetworkOwner()
                        end
                        if bulletEvents[bulletIndex] then
                            bulletEvents[bulletIndex]:Disconnect()
                        end
                        task.wait(2)
                        bullet:Destroy()
                    end)
                end
            end
        end

        -- Clean-up | Unnecessary, but good habit to send to garbage collection early
        task.wait(5)
        if bulletEvents[1] then
            for i, bullet in ipairs(bulletEvents) do
                bullet:Disconnect()
            end
        else
            bulletEvents = nil
        end
    end)()
end

--\\ Unite Start-up //--
function BlasterAmenity:UniteInit()
    BlasterAmenity.dataAmenity = Unite.AcquireAmenity("DataAmenity") -- Grabbing the data code
    BlasterAmenity.bulletQueue = TaskQueue.new(BlasterAmenity.FireBullet) -- Creating the task queue system
end

function BlasterAmenity:UniteStart()
    
end

return BlasterAmenity