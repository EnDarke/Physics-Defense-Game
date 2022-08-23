-- !strict

-- Author: Alex/EnDarke
-- Description: Object module for nodes

--\\ Module Code //--
local Node: {} = {}
Node.__index = Node

function Node.new(_walkable: boolean, _worldPos: Vector3, _gridX: number, _gridY: number)
    local self = setmetatable({}, Node)

    self.walkable = _walkable
    self.worldPosition = _worldPos
    self.gridX = _gridX
    self.gridY = _gridY

    self.gCost = 0
    self.hCost = 0
    self.parent = nil

    return self
end

function Node:fCost()
    return self.gCost + self.hCost
end

function Node:compareTo(nodeToCompare)
    local compare: boolean = self:fCost() == nodeToCompare.fCost and true or false
    if compare then
        compare = self.hCost == nodeToCompare.hCost and true or false
    end
    return not compare
end

return Node