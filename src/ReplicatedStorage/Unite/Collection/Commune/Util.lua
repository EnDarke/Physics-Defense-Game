-- !strict

-- Author: Alex/EnDarke
-- Description: Utility library for communication. Inspired by Sleitnick's communication module.

local Parent: Instance = script.Parent

--\\ Services //--
local runService = game:GetService("RunService")

--\\ Modules //--
local Indexing = require(Parent.Indexing)
local Option = Indexing("Option")

--\\ Variables //--
local instance = Instance.new

--\\ Module Code //--
local Util = {}
Util.IsServer = runService:IsServer()
Util.WaitForChildTimeout = 60
Util.DefaultCommFolderName = "__comm__"
Util.None = newproxy()

function Util.GetCommSubFolder(parent: Instance, subFolderName: string): Option
    local subFolder: Instance = nil
    if Util.IsServer then
        subFolder = parent:FindFirstChild(subFolderName)
        if not subFolder then
            subFolder = instance("Folder")
            subFolder.Name = subFolderName
            subFolder.Parent = parent
        end
    else
        subFolder = parent:WaitForChild(subFolderName, Util.WaitForChildTimeout)
    end
    return Option.Wrap(subFolder)
end

return Util