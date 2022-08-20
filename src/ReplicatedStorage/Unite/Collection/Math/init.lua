-- !strict

-- Author: Alex/EnDarke
-- Description: Handles math functions and calculations

--\\ Modules //--
local Indexing = require(script.Indexing)
local Util = Indexing("Util")

--\\ Variables //--
local round = math.round

--\\ Module Code //--
local Math = {}

function Math.mean(list: table): number
    if list then
        local counter = 0
        for _, num in list do
            counter += num
        end
        counter /= #list
        return counter
    end
end

function Math.median(list: table)
    return Util._makeSortedList(list)[round(#list / 2)]
end

function Math.mode(list: table)
    local counts = {}
    local highest
    for _, num in list do
        -- Add up their counters
        if not counts[num] then
            counts[num] = 1
        else
            counts[num] += 1
        end

        -- Check what has the highest value
        if not highest then
            highest = num
        end
        if counts[num] > counts[highest] then
            highest = num
        end
    end
    return highest
end

function Math.range(list: table)
    list = Util._makeSortedList(list)
    return list[#list] - list[1]
end

return Math