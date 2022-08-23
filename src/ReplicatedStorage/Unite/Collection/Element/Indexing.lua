local ServerScriptService = game:GetService("ServerScriptService")
-- !strict

-- Author: Alex/EnDarke
-- Description: Used for indexing collections

local Parent: Instance = script.Parent

--\\ Module Code //--
return function(name)
    if name then
        return require(Parent.Parent[name])
    end
end