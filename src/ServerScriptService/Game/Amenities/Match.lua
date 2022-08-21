-- !strict

-- Author: Alex/EnDarke
-- Description: Handles back-end match systems

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite:WaitForChild("Unite"))
local Services = Unite.Services
local Settings = Unite.Settings
local Collection = Unite.Collection

--\\ Settings //--
local matchSettings = Settings.Match
local pathfindingSettings = Settings.Pathfinding

--\\ Collection //--
local Util = Collection.Util

--\\ Variables //--
local grids = {}

--\\ Module Code //--
local MatchAmenity = Unite.ForgeAmenity {
    Name = "MatchAmenity";
    Client = {};
}

--\\ Local Functions //--

--\\ Unite Server //--

--\\ Unite Start-Up //--
function MatchAmenity:UniteInit()
    
end

function MatchAmenity:UniteStart()
    coroutine.wrap(function()
        while task.wait() do
            
        end
    end)()
end