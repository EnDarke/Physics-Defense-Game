-- !strict

-- Author: Alex/EnDarke
-- Description: Handles A* Pathfinding with Grid input

local parent = script.Parent

--\\ Classes //--
local heapClass = require(parent.Parent.Unite.Collection:WaitForChild("Heap"))

--\\ Types //--
type GridObject = {GridObject}
type NodeObject = {NodeObject}

type HeapList = {[any]: any}
type NodeList = {[any]: any}

--\\ Variables //--
local abs = math.abs

local vector2 = Vector2.new

--\\ Local Utility Functions //--
local function comparator(a, b)
    if a:fCost() > b:fCost() then
        return true
    else
        return false
    end
end

local function reverse(t: table)
    for i = 1, math.floor(#t / 2) do
        local j: number = #t - i + 1
        t[i], t[j] = t[j], t[i]
    end
    return t
end

--\\ Module Code //--
local pathfindingClass = {}
pathfindingClass.__index = pathfindingClass

function pathfindingClass.new(grid: GridObject)
    local self = setmetatable({}, pathfindingClass)

    self.grid = grid

    return self
end

local function getDistance(nodeA: NodeObject, nodeB: NodeObject)
    local dstX: number = abs(nodeA.gridX - nodeB.gridX)
    local dstY: number = abs(nodeA.gridY - nodeB.gridY)

    if (dstX > dstY) then
        return 14 * dstY + 10 * (dstX - dstY)
    end
    return 14 * dstX + 10 * (dstY - dstX)
end

function pathfindingClass:findPath(startPos: Vector3, targetPos: Vector3)
    local startNode: NodeObject = self.grid:nodeFromWorldPoint(startPos)
    local targetNode: NodeObject = self.grid:nodeFromWorldPoint(targetPos)

    local pathFound: boolean = false

    local finalPath: NodeList = {}
    local openSet: HeapList = heapClass.new(comparator)
    local closedSet: NodeList = {}
    openSet:add(startNode)

    while #openSet > 0 do
        local currentNode: NodeObject = openSet:remove()
        table.insert(closedSet, currentNode)

        if currentNode == targetNode then
            pathFound = true
            break
        end

        for _, neighbor in ipairs(self.grid:getNeighbors(currentNode)) do
            if not neighbor.walkable or table.find(closedSet, neighbor) then
                continue
            end

            local newMovementCostToNeighbor: number = currentNode.gCost + getDistance(currentNode, neighbor)
            if newMovementCostToNeighbor < neighbor.gCost or not table.find(openSet, neighbor) then
                neighbor.gCost = newMovementCostToNeighbor
                neighbor.hCost = getDistance(neighbor, targetNode)
                neighbor.parent = currentNode

                if not table.find(openSet, neighbor) then
                    openSet:add(neighbor)
                end
            end
        end
    end
    if pathFound then
        finalPath = self:retracePath(startNode, targetNode)
    end

    return finalPath
end

function pathfindingClass:retracePath(startNode: NodeObject, endNode: NodeObject)
    local path: NodeList = {}
    local currentNode: NodeObject = endNode

    while currentNode ~= startNode do
        table.insert(path, currentNode)
        currentNode = currentNode.parent
    end

    --[[local waypoints = self:simplifyPath(path)
    waypoints = reverse(waypoints)]]

    return reverse(path)
end

--[[function pathfindingClass:simplifyPath(path: NodeList)
    local waypoints: NodeList = {}
    local directionOld: Vector2 = vector2()

    for i = 2, #path - 1, 1 do
        local directionNew: Vector2 = vector2(path[i - 1].gridX - path[i].gridX, path[i - 1].gridY - path[i].gridY)
        if not (directionNew == directionOld) then
            table.insert(waypoints, path[i].worldPosition)
        end
        directionOld = directionNew
    end
    return waypoints
end]]

return pathfindingClass