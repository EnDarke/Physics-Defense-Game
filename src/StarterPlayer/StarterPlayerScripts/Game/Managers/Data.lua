-- !strict

-- Author: Alex/EnDarke
-- Description: Handles data on the client

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)

--\\ Module Code //--
local DataManager = Unite.ForgeManager {
    Name = "DataManager";
}

--\\ Unite Start-Up //--
function DataManager:UniteInit()
    -- Yielding the data manager until player's data has loaded
    local DataLoaded = Unite.Player:GetAttribute("DataLoaded") == true or Unite.Player:GetAttributeChangedSignal("DataLoaded"):Wait()
end

function DataManager:UniteStart()
    -- Getting the server module for player data
    local DataAmenity = Unite.AcquireAmenity("DataAmenity")
    DataAmenity:Get():Follow(function(data)
        print(data)
    end)
end

return DataManager