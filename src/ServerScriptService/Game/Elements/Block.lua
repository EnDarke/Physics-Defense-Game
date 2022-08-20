local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local Minion = require(Unite.Collection.Minion)

local Block = {}
Block.__index = Block

Block.Tag = "Block"

function Block.new(instance)
    local self = setmetatable({}, Block)
    self._minion = Minion.new()
    print("NEWLY ADDED" .. instance.Name)
    self._minion:GiveTask(function()
        print("BLOCK DESTROYED")
    end)
    return self
end

function Block:Destroy()
    self._minion:Destroy()
end

return Block