-- !strict

-- Author: Alex/EnDarke
-- Description: Handles client initialization

local Parent = script.Parent

local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local Element = require(Unite.Collection.Element)

--Unite.AppendSingularAmenity(Parent.Amenities.TestAmenity) -- Adds the specific amenity
Unite.AppendAmenities(Parent.Amenities) -- Adds all amenities under this instance, add a bool after to get all descendants as well

Unite.Start():Follow(function()
    print("This starts on the server")
end):Hook(warn)