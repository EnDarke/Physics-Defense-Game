--!strict

-- Author: Stephen Sleitnick
-- Description: TableUtil

--\\ Services //--
local HttpService = game:GetService("HttpService")

--\\ Type //--
type Table = {any}
type MapPredicate = (any, any, Table) -> any
type FilterPredicate = (any, any, Table) -> boolean
type ReducePredicate = (number, any, any, Table) -> any
type FindCallback = (any, any, Table) -> boolean
type IteratorFunc = (t: Table, k: any) -> (any, any)

--\\ Variables //--
local rng = Random.new()

--\\ Local Utility Functions //--
local function Copy(t: Table, deep: boolean?): Table
	if deep then
		local function DeepCopy(tbl)
			local tCopy = table.create(#tbl)
			for k,v in pairs(tbl) do
				if type(v) == "table" then
					tCopy[k] = DeepCopy(v)
				else
					tCopy[k] = v
				end
			end
			return tCopy
		end
		return DeepCopy(t)
	else
		if #t > 0 then
			return table.move(t, 1, #t, 1, table.create(#t))
		else
			local tCopy = {}
			for k,v in pairs(t) do
				tCopy[k] = v
			end
			return tCopy
		end
	end
end

local function Sync(srcTbl: Table, templateTbl: Table): Table
	assert(type(srcTbl) == "table", "First argument must be a table")
	assert(type(templateTbl) == "table", "Second argument must be a table")

	local tbl = Copy(srcTbl)

	for k,v in pairs(tbl) do

		local vTemplate = templateTbl[k]

		if vTemplate == nil then
			tbl[k] = nil

		elseif type(v) ~= type(vTemplate) then
			if type(vTemplate) == "table" then
				tbl[k] = Copy(vTemplate, true)
			else
				tbl[k] = vTemplate
			end

		elseif type(v) == "table" then
			tbl[k] = Sync(v, vTemplate)
		end

	end

	for k,vTemplate in pairs(templateTbl) do

		local v = tbl[k]

		if v == nil then
			if type(vTemplate) == "table" then
				tbl[k] = Copy(vTemplate, true)
			else
				tbl[k] = vTemplate
			end
		end

	end

	return tbl

end

local function Reconcile(src: Table, template: Table): Table

	assert(type(src) == "table", "First argument must be a table")
	assert(type(template) == "table", "Second argument must be a table")

	local tbl = Copy(src)

	for k,v in pairs(template) do
		local sv = src[k]
		if sv == nil then
			if type(v) == "table" then
				tbl[k] = Copy(v, true)
			else
				tbl[k] = v
			end
		elseif type(sv) == "table" then
			if type(v) == "table" then
				tbl[k] = Reconcile(sv, v)
			else
				tbl[k] = Copy(sv, true)
			end
		end
	end

	return tbl

end

local function SwapRemove(t: Table, i: number)
	local n = #t
	t[i] = t[n]
	t[n] = nil
end

local function SwapRemoveFirstValue(t: Table, v: any): number?
	local index: number? = table.find(t, v)
	if index then
		SwapRemove(t, index)
	end
	return index
end

local function Map(t: Table, f: MapPredicate): Table
	assert(type(t) == "table", "First argument must be a table")
	assert(type(f) == "function", "Second argument must be a function")
	local newT = table.create(#t)
	for k,v in pairs(t) do
		newT[k] = f(v, k, t)
	end
	return newT
end

local function Filter(t: Table, f: FilterPredicate): Table
	assert(type(t) == "table", "First argument must be a table")
	assert(type(f) == "function", "Second argument must be a function")
	local newT = table.create(#t)
	if #t > 0 then
		local n = 0
		for i,v in ipairs(t) do
			if f(v, i, t) then
				n += 1
				newT[n] = v
			end
		end
	else
		for k,v in pairs(t) do
			if f(v, k, t) then
				newT[k] = v
			end
		end
	end
	return newT
end

local function Reduce(t: Table, f: ReducePredicate, init: any?): any
	assert(type(t) == "table", "First argument must be a table")
	assert(type(f) == "function", "Second argument must be a function")
	local result = init
	if #t > 0 then
		local start = 1
		if init == nil then
			result = t[1]
			start = 2
		end
		for i = start,#t do
			result = f(result, t[i], i, t)
		end
	else
		local start = nil
		if init == nil then
			result = next(t)
			start = result
		end
		for k,v in next,t,start do
			result = f(result, v, k, t)
		end
	end
	return result
end

local function Assign(target: Table, ...: Table): Table
	local tbl = Copy(target)
	for _,src in ipairs({...}) do
		for k,v in pairs(src) do
			tbl[k] = v
		end
	end
	return tbl
end

local function Extend(target: Table, extension: Table): Table
	local tbl = Copy(target)
	for _,v in ipairs(extension) do
		table.insert(tbl, v)
	end
	return tbl
end

local function Reverse(tbl: Table): Table
	local n = #tbl
	local tblRev = table.create(n)
	for i = 1,n do
		tblRev[i] = tbl[n - i + 1]
	end
	return tblRev
end

local function Shuffle(tbl: Table, rngOverride: Random?): Table
	assert(type(tbl) == "table", "First argument must be a table")
	local shuffled = Copy(tbl)
	local random = if typeof(rngOverride) == "Random" then rngOverride else rng
	for i = #tbl, 2, -1 do
		local j = random:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

local function Sample(tbl: Table, size: number, rngOverride: Random?): Table
	assert(type(tbl) == "table", "First argument must be a table")
	assert(type(size) == "number", "Second argument must be a number")
	local shuffled = Copy(tbl)
	local sample = table.create(size)
	local random = if typeof(rngOverride) == "Random" then rngOverride else rng
	local len = #tbl
	size = math.clamp(size, 1, len)
	for i = 1,size do
		local j = random:NextInteger(i, len)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	table.move(shuffled, 1, size, 1, sample)
	return sample
end

local function Flat(tbl: Table, depth: number?): Table
	local maxDepth: number = if type(depth) == "number" then depth else 1
	local flatTbl = table.create(#tbl)
	local function Scan(t: Table, d: number)
		for _,v in ipairs(t) do
			if type(v) == "table" and d < maxDepth then
				Scan(v, d + 1)
			else
				table.insert(flatTbl, v)
			end
		end
	end
	Scan(tbl, 0)
	return flatTbl
end

local function FlatMap(tbl: Table, callback: MapPredicate): Table
	return Flat(Map(tbl, callback))
end

local function Keys(tbl: Table): Table
	local keys = table.create(#tbl)
	for k in pairs(tbl) do
		table.insert(keys, k)
	end
	return keys
end

local function Find(tbl: Table, callback: FindCallback): (any?, any?)
	for k,v in pairs(tbl) do
		if callback(v, k, tbl) then
			return v, k
		end
	end
	return nil, nil
end

local function Every(tbl: Table, callback: FindCallback): boolean
	for k,v in pairs(tbl) do
		if not callback(v, k, tbl) then
			return false
		end
	end
	return true
end

local function Some(tbl: Table, callback: FindCallback): boolean
	for k,v in pairs(tbl) do
		if callback(v, k, tbl) then
			return true
		end
	end
	return false
end

local function Truncate(tbl: Table, len: number): Table
	return table.move(tbl, 1, len, 1, table.create(len))
end

local function Zip(...): (IteratorFunc, Table, any)
	assert(select("#", ...) > 0, "Must supply at least 1 table")
	local function ZipIteratorArray(all: Table, k: number)
		k += 1
		local values = {}
		for i,t in ipairs(all) do
			local v = t[k]
			if v ~= nil then
				values[i] = v
			else
				return nil, nil
			end
		end
		return k, values
	end
	local function ZipIteratorMap(all: Table, k: any)
		local values = {}
		for i,t in ipairs(all) do
			local v = next(t, k)
			if v ~= nil then
				values[i] = v
			else
				return nil, nil
			end
		end
		return k, values
	end
	local all = {...}
	if #all[1] > 0 then
		return ZipIteratorArray, all, 0
	else
		return ZipIteratorMap, all, nil
	end
end

local function Lock(tbl: Table): Table
	local function Freeze(t: Table)
		for k,v in pairs(t) do
			if type(v) == "table" then
				t[k] = Freeze(v)
			end
		end
		return table.freeze(t)
	end
	return Freeze(tbl)
end

local function IsEmpty(tbl)
	return next(tbl) == nil
end

local function EncodeJSON(value: any): string
	return HttpService:JSONEncode(value)
end

local function DecodeJSON(str: string): any
	return HttpService:JSONDecode(str)
end

--\\ Module Code //--
local TableUtil = {}

TableUtil.Copy = Copy
TableUtil.Sync = Sync
TableUtil.Reconcile = Reconcile
TableUtil.SwapRemove = SwapRemove
TableUtil.SwapRemoveFirstValue = SwapRemoveFirstValue
TableUtil.Map = Map
TableUtil.Filter = Filter
TableUtil.Reduce = Reduce
TableUtil.Assign = Assign
TableUtil.Extend = Extend
TableUtil.Reverse = Reverse
TableUtil.Shuffle = Shuffle
TableUtil.Sample = Sample
TableUtil.Flat = Flat
TableUtil.FlatMap = FlatMap
TableUtil.Keys = Keys
TableUtil.Find = Find
TableUtil.Every = Every
TableUtil.Some = Some
TableUtil.Truncate = Truncate
TableUtil.Zip = Zip
TableUtil.Lock = Lock
TableUtil.IsEmpty = IsEmpty
TableUtil.EncodeJSON = EncodeJSON
TableUtil.DecodeJSON = DecodeJSON

return TableUtil