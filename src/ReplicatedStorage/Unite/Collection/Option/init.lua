-- !strict

-- Author: Alex/EnDarke
-- Description: Handles Options and Option functions. Inspiration from Sleitnick

--\\ Variables //--
local CLASSNAME = "Option"

--\\ Module Code //--
local Option = {}
Option.__index = Option

function Option._new(value)
	local self = setmetatable({
		ClassName = CLASSNAME;
		_v = value;
		_s = (value ~= nil);
	}, Option)
	return self
end

function Option.Some(value)
	assert(value ~= nil, "Option.Some() value cannot be nil")
	return Option._new(value)
end

function Option.Wrap(value)
	if value == nil then
		return Option.None
	else
		return Option.Some(value)
	end
end

function Option.Is(obj)
	return type(obj) == "table" and getmetatable(obj) == Option
end

function Option.Assert(obj)
	assert(Option.Is(obj), "Result was not of type Option")
end

function Option.Deserialize(data) -- type data = {ClassName: string, Value: any}
	assert(type(data) == "table" and data.ClassName == CLASSNAME, "Invalid data for deserializing Option")
	return data.Value == nil and Option.None or Option.Some(data.Value)
end

function Option:Serialize()
	return {
		ClassName = self.ClassName;
		Value = self._v;
	}
end

function Option:Match(matches)
	local onSome = matches.Some
	local onNone = matches.None
	assert(type(onSome) == "function", "Missing 'Some' match")
	assert(type(onNone) == "function", "Missing 'None' match")
	if self:IsSome() then
		return onSome(self:Unwrap())
	else
		return onNone()
	end
end

function Option:IsSome()
	return self._s
end

function Option:IsNone()
	return not self._s
end

function Option:Expect(msg)
	assert(self:IsSome(), msg)
	return self._v
end

function Option:ExpectNone(msg)
	assert(self:IsNone(), msg)
end

function Option:Unwrap()
	return self:Expect("Cannot unwrap option of None type")
end

function Option:UnwrapOr(default)
	if self:IsSome() then
		return self:Unwrap()
	else
		return default
	end
end

function Option:UnwrapOrElse(defaultFn)
	if self:IsSome() then
		return self:Unwrap()
	else
		return defaultFn()
	end
end

function Option:And(optionB)
	if self:IsSome() then
		return optionB
	else
		return Option.None
	end
end

function Option:AndThen(andThenFn)
	if self:IsSome() then
		local result = andThenFn(self:Unwrap())
		Option.Assert(result)
		return result
	else
		return Option.None
	end
end

function Option:Or(optionB)
	if self:IsSome() then
		return self
	else
		return optionB
	end
end

function Option:OrElse(orElseFn)
	if self:IsSome() then
		return self
	else
		local result = orElseFn()
		Option.Assert(result)
		return result
	end
end

function Option:XOr(optionB)
	local someOptA = self:IsSome()
	local someOptB = optionB:IsSome()
	if someOptA == someOptB then
		return Option.None
	elseif someOptA then
		return self
	else
		return optionB
	end
end

function Option:Filter(predicate)
	if self:IsNone() or not predicate(self._v) then
		return Option.None
	else
		return self
	end
end

function Option:Contains(value)
	return self:IsSome() and self._v == value
end

function Option:__tostring()
	if self:IsSome() then
		return ("Option<" .. typeof(self._v) .. ">")
	else
		return "Option<None>"
	end
end

function Option:__eq(opt)
	if Option.Is(opt) then
		if self:IsSome() and opt:IsSome() then
			return (self:Unwrap() == opt:Unwrap())
		elseif self:IsNone() and opt:IsNone() then
			return true
		end
	end
	return false
end

Option.None = Option._new()


return Option