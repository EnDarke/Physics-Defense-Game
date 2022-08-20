-- !strict

-- Author: Alex/EnDarke
-- Description: Handles data on the client

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local Services = Unite.Services

--\\ Variables //--
local player = Services.Players.LocalPlayer

--\\ Module Code //--
local DataManager = Unite.ForgeManager {
    Name = "DataManager";
}

function DataManager:UniteInit()
    -- Yielding the data manager until player's data has loaded
    local DataLoaded = player:GetAttribute("DataLoaded") == true or player:GetAttributeChangedSignal("DataLoaded"):Wait()
end

function DataManager:UniteStart()
    -- Getting the server module for player data
    local DataAmenity = Unite.AcquireAmenity("DataAmenity")
    DataAmenity:Get(Unite.Services.Players.LocalPlayer):Follow(function(data)
        print(data)
    end)
end

return DataManager