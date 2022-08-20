-- !strict

-- Author: Alex/EnDarke
-- Description: Handles client initialization

local Parent = script.Parent

local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)

--Unite.AppendSingularManager(Parent.Managers.TestManager) -- Adds the specific manager
Unite.AppendManagers(Parent.Managers) -- Adds all managers under this instance, add a bool after to get all descendants as well

Unite.Start():Follow(function()
    print("This is for testing")
end):Hook(warn)