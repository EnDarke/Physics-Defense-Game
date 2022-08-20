-- !strict

-- Author: Alex/EnDarke
-- Description: Handles symbol creation. Inspiration from Sleitnick

local function Symbol(name: string?)
	local symbol = newproxy(true)
	if not name then
		name = ""
	end
	getmetatable(symbol).__tostring = function()
		return "Symbol(" .. name .. ")"
	end
	return symbol
end

return Symbol