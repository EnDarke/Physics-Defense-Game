local ServerScriptService = game:GetService("ServerScriptService")
-- !strict

-- Author: Alex/EnDarke
-- Description: Used for indexing collections

local Parent = script.Parent

--\\ Services //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--\\ Module Code //--
return function(name)
    if name then
        return require(ReplicatedStorage.Unite.Collection[name])
    end
end