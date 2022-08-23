-- !strict

-- Author: Alex/EnDarke
-- Description: Handles front-end match systems

local Parent: Instance = script.Parent

--\\ Unite //--
local Players = game:GetService("Players")
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local collection: {} = Unite.Collection
local signals: {} = Unite.Signals

--\\ Collection //--
local minion = collection.Minion

--\\ Module Code //--
local MatchManager = Unite.ForgeManager {
    Name = "MatchManager";
}

--\\ Unite Start-Up //--
function MatchManager:UniteInit()
    -- Yield MatchManager till character is loaded
    local character = Unite.Player.Character or Unite.Player.CharacterAdded:Wait()

    self._minion = minion.new()
end

function MatchManager:UniteStart()
    -- Initialize Variables
    local playerGui = Unite.Player.PlayerGui
    local announcementUI = playerGui:WaitForChild("Announcement")

    -- Change announcement text whenever there is a script signal from the server
    self._minion:GiveTask(signals.Announce:Connect(function(message: string)
        if message then
            announcementUI.MainFrame.Label.Text = message
        end
    end))
end

return MatchManager