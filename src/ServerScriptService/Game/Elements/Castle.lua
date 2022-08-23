-- !strict

-- Author: Alex/EnDarke
-- Description: Handles castle elements for the server

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local services = Unite.Services
local collection = Unite.Collection

--\\ Collection //--
local Minion = collection.Minion

--\\ Module Code //--
local Castle = {}
Castle.__index = Castle
Castle.Tag = "Castle"

function Castle.new(instance: Instance)
    local self = setmetatable({}, Castle)

    self.instance = instance
    self._minion = Minion.new()

    print("Castle Created")
    self._minion:GiveTask(function()
        print("Castle Deleted")
    end)

    return self
end

function Castle:Init()
    local healthGui = self.instance.PrimaryPart.HealthGui
    healthGui.HealthText.Text = self.instance:GetAttribute("Health")

    -- Castle health change signalized function
    self._minion:GiveTask(self.instance.AttributeChanged:Connect(function(attributeType)
        if healthGui then
            local health = self.instance:GetAttribute(attributeType)
            if health < 0 then
                health = 0
            end
            healthGui.HealthText.Text = health
        end
    end))
end

function Castle:Destroy()
    self._minion:Destroy()
end

return Castle