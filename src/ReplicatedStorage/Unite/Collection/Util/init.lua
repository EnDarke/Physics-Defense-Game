-- !strict

-- Author: Alex/EnDarke
-- Description: Holds all utility functions

--\\ Services //--
local HttpService = game:GetService("HttpService")

--\\ Local Utility Variables //--
local suffixKeys = {
    "k", "M", "B", "T", "qd", "Qn", "sx", "Sp", "O", "N", "de", "Ud", "DD",
	"tdD", "qdD", "QnD", "sxD", "SpD", "OcD", "NvD", "Vgn", "UVg", "DVg",
	"TVg", "qtV", "QnV", "SeV", "SPG", "OVG", "NVG", "TGN", "UTG", "DTG",
	"tsTG", "qtTG", "QnTG", "ssTG", "SpTG", "OcTG", "NoTG", "QdDR", "uQDR",
	"dQDR", "tQDR", "qdQDR", "QnQDR", "sxQDR", "SpQDR", "OQDDr", "NQDDr",
	"qQGNT", "uQGNT", "dQGNT", "tQGNT", "qdQGNT", "QnQGNT", "sxQGNT",
	"SpQGNT", "OQQGNT", "NQQGNT", "SXGNTL",
}

local abs = math.abs
local floor = math.floor
local find = string.find
local sub = string.sub
local len = string.len
local gsub = string.gsub
local btest = bit32.btest

local vector3 = Vector3.new

--\\ Module Code //--
local Util = {}

--\\ Hold new objects //--
Util.Vector3 = {
	new = Vector3.new;
	one = Vector3.one;
	up = vector3(0, 1, 0);
	down = vector3(0, -1, 0);
	left = vector3(-1, 0, 0);
	right = vector3(1, 0, 0);
	forward = vector3(0, 0, 1);
	backward = vector3(0, 0, -1);
}

-- Creates a new table mirrored from another
function Util._deepCopy(t: table): table
    local copy = {}
	for _index, _value in pairs(t) do
		if type(_value) == "table" then
			_value = Util._deepCopy(_value)
		end
		copy[_index] = _value
	end
	return copy
end

-- Freezes a table to make it non-editable
function Util._readOnly(t: table): table
    local function freeze(tab)
		for key, value in pairs(tab) do
			if type(value) == "table" then
				freeze(value)
			end
		end
		return table.freeze(tab)
	end
	return freeze(t)
end

-- Makes sure a table has every value another has
function Util._reconcileTable(target: table, template: table)
	for k, v in pairs(template) do
		if type(k) == "string" then
			if target[k] == nil then
				if type(v) == "table" then
					target[k] = Util._deepCopy(v)
				else
					target[k] = v
				end
			elseif type(target[k]) == "table" and type(v) == "table" then
				Util._reconcileTable(target[k], v)
			end
		end
	end
end

-- Sorts the inputted list
function Util._makeSortedList(list: table, isArray: boolean)
	list = Util._deepCopy(list)
	table.sort(list, function(a, b)
        if not isArray then
			return a < b
		else
			return a[2] < b[2]
		end
    end)
	return list
end

-- Getting the time based from distance
function Util._getTimeFromDistance(distance: number, speed: number)
	return distance / speed
end

-- Creates a unique user id for making object's and object names unique for unique instantiation
function Util._createUUID(lookupTable: table, hasCurlyBrackets: boolean?)
	hasCurlyBrackets = hasCurlyBrackets or false
	local function getUUID()
		local uuid = HttpService:GenerateGUID(hasCurlyBrackets)
		if lookupTable[uuid] then
			return getUUID()
		else
			return uuid
		end
	end
	return getUUID()
end

-- Converting true/false to 1/0
function Util._boolToBinary(b)
	return b == true and 1 or 0
end

-- Checking if the input is a boolean/true/fale
function Util._binaryTest(b)
	if type(b) == "boolean" then
		return Util._boolToBinary(b)
	else
		return b
	end
end

-- Checking if the input is a number/1/0
function Util._boolTest(b)
	if type(b) == "number" and b == 0 or b == 1 then
		return btest(b)
	else
		return b
	end
end

-- Suffixes the inputted number into a shortened string | EX: 10000 -> 10K
function Util._suffixShorten(input: number): string
    local negative = input < 0
    local paired = false
    input = abs(input)

    for i, v in pairs(suffixKeys) do
        if not (input >= 10 ^ (3 * i)) then
            input = input / 10 ^ (3 * (i - 1))
            local isComplex = (find(tostring(input), ".") and sub(tostring(input), 4, 4) ~= ".")
			input = sub(tostring(input), 1, (isComplex and 4) or 3) .. (suffixKeys[i - 1] or "")
			paired = true
			break
        end
    end

    if not paired then
        local rounded = floor(input)
        input = tostring(rounded)
    end

    if negative then
        return "-" .. input
    end

    return input
end

-- Adds a comma for every thousandth placing | EX: 10000 -> 10,000
function Util._suffixComma(input: number): string
    input = tostring(input)
    for i = 1, len(input), 1 do
        input, i = gsub(input, "^(-?%d+)(%d%d%d)", '%1,%2')
        if i == 0 then
            break
        end
    end
    return input
end

-- Checks if the inputted player is in the inputted group
function Util._checkGroupStatus(player: Player, groupId: number)
    if player then
        return player:IsInGroup(groupId)
    else
        return false, 002
    end
end

return Util