-- !strict

-- Author: Stephen Sleitnick
-- Description: Trove

--\\ Services //--
local RunService = game:GetService("RunService")

--\\ Variables //--
local FN_MARKER = newproxy()
local THREAD_MARKER = newproxy()

--\\ Local Utility Functions //--
local function GetObjectCleanupFunction(object, cleanupMethod)
	local t = typeof(object)
	if t == "function" then
		return FN_MARKER
	elseif t == "thread" then
		return THREAD_MARKER
	end
	if cleanupMethod then
		return cleanupMethod
	end
	if t == "Instance" then
		return "Destroy"
	elseif t == "RBXScriptConnection" then
		return "Disconnect"
	elseif t == "table" then
		if typeof(object.Destroy) == "function" then
			return "Destroy"
		elseif typeof(object.Disconnect) == "function" then
			return "Disconnect"
		end
	end
	error("Failed to get cleanup function for object " .. t .. ": " .. tostring(object), 3)
end

local function AssertOathLike(object)
	if type(object) ~= "table" or type(object.getStatus) ~= "function" or type(object.finally) ~= "function" or type(object.cancel) ~= "function" then
		error("Did not receive a Oath as an argument", 3)
	end
end

--\\ Module Code //--
local Trove = {}
Trove.__index = Trove

function Trove.new()
	local self = setmetatable({}, Trove)
	self._objects = {}
	return self
end

function Trove:Extend()
	return self:Construct(Trove)
end

function Trove:Clone(instance: Instance): Instance
	return self:Add(instance:Clone())
end

function Trove:Construct(class, ...)
	local object = nil
	local t = type(class)
	if t == "table" then
		object = class.new(...)
	elseif t == "function" then
		object = class(...)
	end
	return self:Add(object)
end

function Trove:Connect(signal, fn)
	return self:Add(signal:Connect(fn))
end

function Trove:BindToRenderStep(name: string, priority: number, fn: (dt: number) -> ())
	RunService:BindToRenderStep(name, priority, fn)
	self:Add(function()
		RunService:UnbindFromRenderStep(name)
	end)
end

function Trove:AddOath(oath)
	AssertOathLike(oath)
	if oath:getStatus() == "Started" then
		oath:finally(function()
			return self:_findAndRemoveFromObjects(oath, false)
		end)
		self:Add(oath, "cancel")
	end
	return oath
end

function Trove:Add(object: any, cleanupMethod: string?): any
	local cleanup = GetObjectCleanupFunction(object, cleanupMethod)
	table.insert(self._objects, {object, cleanup})
	return object
end

function Trove:Remove(object: any): boolean
	return self:_findAndRemoveFromObjects(object, true)
end

function Trove:Clean()
	for _,obj in ipairs(self._objects) do
		self:_cleanupObject(obj[1], obj[2])
	end
	table.clear(self._objects)
end

function Trove:_findAndRemoveFromObjects(object: any, cleanup: boolean): boolean
	local objects = self._objects
	for i,obj in ipairs(objects) do
		if obj[1] == object then
			local n = #objects
			objects[i] = objects[n]
			objects[n] = nil
			if cleanup then
				self:_cleanupObject(obj[1], obj[2])
			end
			return true
		end
	end
	return false
end

function Trove:_cleanupObject(object, cleanupMethod)
	if cleanupMethod == FN_MARKER then
		object()
	elseif cleanupMethod == THREAD_MARKER then
		coroutine.close(object)
	else
		object[cleanupMethod](object)
	end
end

function Trove:AttachToInstance(instance: Instance)
	assert(instance:IsDescendantOf(game), "Instance is not a descendant of the game hierarchy")
	return self:Connect(instance.Destroying, function()
		self:Destroy()
	end)
end

function Trove:Destroy()
	self:Clean()
end


return Trove