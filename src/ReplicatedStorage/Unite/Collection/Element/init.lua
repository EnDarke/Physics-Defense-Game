-- !strict

-- Author: Alex/EnDarke
-- Description: Used for binding elements using tags. Inspiration from Sleitnick's Componenet module

local Indexing = require(script.Indexing)
local Trove = Indexing("Trove")
local Signal = Indexing("Signal")
local Oath = Indexing("Oath")
local TableUtil = Indexing("TableUtil")

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IS_SERVER = RunService:IsServer()
local DEFAULT_WAIT_FOR_TIMEOUT = 60
local ATTRIBUTE_ID_NAME = "ElementServerId"

local DESCENDANT_WHITELIST = {workspace, Players}

local elementsByTag = {}

local elementByTagCreated = Signal.new()
local elementByTagDestroyed = Signal.new()

--\\ Local Utility Functions
local function IsDescendantOfWhitelist(instance)
	for _,v in ipairs(DESCENDANT_WHITELIST) do
		if instance:IsDescendantOf(v) then
			return true
		end
	end
	return false
end

--\\ Module Code //--
local Element = {}
Element.__index = Element

function Element.FromTag(tag)
	return elementsByTag[tag]
end

function Element.ObserveFromTag(tag, observer)
	local trove = Trove.new()
	local observeTrove = trove:Construct(Trove)
	local function OnCreated(element)
		if element._tag == tag then
			observer(element, observeTrove)
		end
	end
	local function OnDestroyed(element)
		if element._tag == tag then
			observeTrove:Clean()
		end
	end
	do
		local element = Element.FromTag(tag)
		if element then
			task.spawn(OnCreated, element)
		end
	end
	trove:Add(elementByTagCreated:Connect(OnCreated))
	trove:Add(elementByTagDestroyed:Connect(OnDestroyed))
	return trove
end

function Element.Auto(parent)
	local function Setup(moduleScript)
		local m = require(moduleScript)
		assert(type(m) == "table", "Expected table for element")
		assert(type(m.Tag) == "string", "Expected .Tag property")
		Element.new(m.Tag, m, m.RenderPriority, m.RequiredElements)
	end
	for _,v in ipairs(parent:GetDescendants()) do
		if v:IsA("ModuleScript") then
			Setup(v)
		end
	end
	return parent.DescendantAdded:Connect(function(v)
		if v:IsA("ModuleScript") then
			Setup(v)
		end
	end)
end

function Element.new(tag, class, renderPriority, requireElements)

	assert(type(tag) == "string", "Argument #1 (tag) should be a string; got " .. type(tag))
	assert(type(class) == "table", "Argument #2 (class) should be a table; got " .. type(class))
	assert(type(class.new) == "function", "Class must contain a .new constructor function")
	assert(type(class.Destroy) == "function", "Class must contain a :Destroy function")
	assert(elementsByTag[tag] == nil, "Element already bound to this tag")

	local self = setmetatable({}, Element)

	self._trove = Trove.new()
	self._lifecycleTrove = self._trove:Construct(Trove)
	self._tag = tag
	self._class = class
	self._objects = {}
	self._instancesToObjects = {}
	self._hasHeartbeatUpdate = (type(class.HeartbeatUpdate) == "function")
	self._hasSteppedUpdate = (type(class.SteppedUpdate) == "function")
	self._hasRenderUpdate = (type(class.RenderUpdate) == "function")
	self._hasInit = (type(class.Init) == "function")
	self._hasDeinit = (type(class.Deinit) == "function")
	self._renderPriority = renderPriority or Enum.RenderPriority.Last.Value
	self._requireElements = requireElements or {}
	self._lifecycle = false
	self._nextId = 0

	self.Added = self._trove:Construct(Signal)
	self.Removed = self._trove:Construct(Signal)

	local observeTrove = self._trove:Construct(Trove)

	local function ObserveTag()

		local function HasRequiredElements(instance)
			for _,reqComp in ipairs(self._requireElements) do
				local comp = Element.FromTag(reqComp)
				if comp:GetFromInstance(instance) == nil then
					return false
				end
			end
			return true
		end

		observeTrove:Connect(CollectionService:GetInstanceAddedSignal(tag), function(instance)
			if IsDescendantOfWhitelist(instance) and HasRequiredElements(instance) then
				self:_instanceAdded(instance)
			end
		end)

		observeTrove:Connect(CollectionService:GetInstanceRemovedSignal(tag), function(instance)
			self:_instanceRemoved(instance)
		end)

		for _,reqComp in ipairs(self._requireElements) do
			local comp = Element.FromTag(reqComp)
			observeTrove:Connect(comp.Added, function(obj)
				if CollectionService:HasTag(obj.Instance, tag) and HasRequiredElements(obj.Instance) then
					self:_instanceAdded(obj.Instance)
				end
			end)
			observeTrove:Connect(comp.Removed, function(obj)
				if CollectionService:HasTag(obj.Instance, tag) then
					self:_instanceRemoved(obj.Instance)
				end
			end)
		end

		observeTrove:Add(function()
			self:_stopLifecycle()
			for instance in pairs(self._instancesToObjects) do
				self:_instanceRemoved(instance)
			end
		end)

		do
			for _,instance in ipairs(CollectionService:GetTagged(tag)) do
				if IsDescendantOfWhitelist(instance) and HasRequiredElements(instance) then
					task.defer(function()
						self:_instanceAdded(instance)
					end)
				end
			end
		end

	end

	if #self._requireElements == 0 then
		ObserveTag()
	else
		-- Only observe tag when all required elements are available:
		local tagsReady = {}
		local function Check()
			for _,ready in pairs(tagsReady) do
				if not ready then
					return
				end
			end
			ObserveTag()
		end
		local function Cleanup()
			observeTrove:Clean()
		end
		for _,requiredElement in ipairs(self._requireElements) do
			tagsReady[requiredElement] = false
		end
		for _,requiredElement in ipairs(self._requireElements) do
			self._trove:Add(Element.ObserveFromTag(requiredElement, function(_element, trove)
				tagsReady[requiredElement] = true
				Check()
				trove:Add(function()
					tagsReady[requiredElement] = false
					Cleanup()
				end)
			end))
		end
	end

	elementsByTag[tag] = self
	elementByTagCreated:Fire(self)
	self._trove:Add(function()
		elementsByTag[tag] = nil
		elementByTagDestroyed:Fire(self)
	end)

	return self

end

function Element:_startHeartbeatUpdate()
	local all = self._objects
	self._heartbeatUpdate = RunService.Heartbeat:Connect(function(dt)
		for _,v in ipairs(all) do
			v:HeartbeatUpdate(dt)
		end
	end)
	self._lifecycleTrove:Add(self._heartbeatUpdate)
end

function Element:_startSteppedUpdate()
	local all = self._objects
	self._steppedUpdate = RunService.Stepped:Connect(function(_, dt)
		for _,v in ipairs(all) do
			v:SteppedUpdate(dt)
		end
	end)
	self._lifecycleTrove:Add(self._steppedUpdate)
end

function Element:_startRenderUpdate()
	local all = self._objects
	self._renderName = (self._tag .. "RenderUpdate")
	RunService:BindToRenderStep(self._renderName, self._renderPriority, function(dt)
		for _,v in ipairs(all) do
			v:RenderUpdate(dt)
		end
	end)
	self._lifecycleTrove:Add(function()
		RunService:UnbindFromRenderStep(self._renderName)
	end)
end

function Element:_startLifecycle()
	self._lifecycle = true
	if self._hasHeartbeatUpdate then
		self:_startHeartbeatUpdate()
	end
	if self._hasSteppedUpdate then
		self:_startSteppedUpdate()
	end
	if self._hasRenderUpdate then
		self:_startRenderUpdate()
	end
end

function Element:_stopLifecycle()
	self._lifecycle = false
	self._lifecycleTrove:Clean()
end

function Element:_instanceAdded(instance)
	if self._instancesToObjects[instance] then return end
	if not self._lifecycle then
		self:_startLifecycle()
	end
	self._nextId = (self._nextId + 1)
	local id = (self._tag .. tostring(self._nextId))
	if IS_SERVER then
		instance:SetAttribute(ATTRIBUTE_ID_NAME, id)
	end
	local obj = self._class.new(instance)
	obj.Instance = instance
	obj._id = id
	self._instancesToObjects[instance] = obj
	table.insert(self._objects, obj)
	if self._hasInit then
		task.defer(function()
			if self._instancesToObjects[instance] ~= obj then return end
			obj:Init()
		end)
	end
	self.Added:Fire(obj)
	return obj
end

function Element:_instanceRemoved(instance)
	if not self._instancesToObjects[instance] then return end
	self._instancesToObjects[instance] = nil
	for i,obj in ipairs(self._objects) do
		if obj.Instance == instance then
			if self._hasDeinit then
				obj:Deinit()
			end
			if IS_SERVER and instance.Parent and instance:GetAttribute(ATTRIBUTE_ID_NAME) ~= nil then
				instance:SetAttribute(ATTRIBUTE_ID_NAME, nil)
			end
			self.Removed:Fire(obj)
			obj:Destroy()
			obj._destroyed = true
			TableUtil.SwapRemove(self._objects, i)
			break
		end
	end
	if #self._objects == 0 and self._lifecycle then
		self:_stopLifecycle()
	end
end

function Element:GetAll()
	return TableUtil.Copy(self._objects)
end

function Element:GetFromInstance(instance)
	return self._instancesToObjects[instance]
end

function Element:GetFromID(id)
	for _,v in ipairs(self._objects) do
		if v._id == id then
			return v
		end
	end
	return nil
end

function Element:Filter(filterFn)
	return TableUtil.Filter(self._objects, filterFn)
end

function Element:WaitFor(instance, timeout)
	local isName = (type(instance) == "string")
	local function IsInstanceValid(obj)
		return ((isName and obj.Instance.Name == instance) or ((not isName) and obj.Instance == instance))
	end
	for _,obj in ipairs(self._objects) do
		if IsInstanceValid(obj) then
			return Oath.resolve(obj)
		end
	end
	local lastObj = nil
	return Oath.fromEvent(self.Added, function(obj)
		lastObj = obj
		return IsInstanceValid(obj)
	end):andThen(function()
		return lastObj
	end):timeout(timeout or DEFAULT_WAIT_FOR_TIMEOUT)
end

function Element:Observe(instance, observer)
	local trove = Trove.new()
	local observeTrove = trove:Construct(Trove)
	trove:Connect(self.Added, function(obj)
		if obj.Instance == instance then
			observer(obj, observeTrove)
		end
	end)
	trove:Connect(self.Removed, function(obj)
		if obj.Instance == instance then
			observeTrove:Clean()
		end
	end)
	for _,obj in ipairs(self._objects) do
		if obj.Instance == instance then
			task.spawn(observer, obj, observeTrove)
			break
		end
	end
	return trove
end

function Element:Destroy()
	self._trove:Destroy()
end

return Element