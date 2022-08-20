-- !strict

-- Description: Handles randomized pool creation and usage
-- Author: Alex/EnDarke inspired by Brad_Developer's Rarity Pool Module
-- Date: 06/24/22

local random = Random.new

local RarityPool = {}
RarityPool.__index = RarityPool

function RarityPool.new(pool)
	assert(pool, "Not pool object found")
	local self = setmetatable({}, RarityPool)

	self.Pool = {}
	self.ActualPool = {}

	self:SetPool(pool)

	return self
end

function RarityPool:SetPool(pool)
	table.clear(self.Pool)
	table.clear(self.ActualPool)

	self.Pool = pool
	self.TotalRarity = 0

	for _index = 1, #self.Pool do
		self.TotalRarity += self.Pool[_index][2]
	end
end

function RarityPool:Roll()
	local choice = self.TotalRarity * random():NextNumber(0, 1)
	local value = 0

	for _index = 1, #self.Pool do
		value += self.Pool[_index][2]
		if choice <= value then
			return self.Pool[_index][1]
		end
	end
end

return RarityPool