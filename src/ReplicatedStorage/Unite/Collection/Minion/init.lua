-- !strict

-- Author: Alex/EnDarke
-- Description: Handles cleaning up instances and connected functions. Inspirated from Quenty's Maid Module

--\\ Module Code //--
local Minion = {}
Minion.ClassName = "Maid"

function Minion.new()
	return setmetatable({
		_tasks = {}
	}, Minion)
end

function Minion.isMaid(value)
	return type(value) == "table" and value.ClassName == "Maid"
end

function Minion:__index(index)
	if Minion[index] then
		return Minion[index]
	else
		return self._tasks[index]
	end
end

function Minion:__newindex(index, newTask)
	if Minion[index] ~= nil then
		error(("'%s' is reserved"):format(tostring(index)), 2)
	end

	local tasks = self._tasks
	local oldTask = tasks[index]

	if oldTask == newTask then
		return
	end

	tasks[index] = newTask

	if oldTask then
		if type(oldTask) == "function" then
			oldTask()
		elseif typeof(oldTask) == "RBXScriptConnection" then
			oldTask:Disconnect()
		elseif oldTask.Destroy then
			oldTask:Destroy()
		end
	end
end

function Minion:GiveTask(task)
	if not task then
		error("Task cannot be false or nil", 2)
	end

	local taskId = #self._tasks+1
	self[taskId] = task

	if type(task) == "table" and (not task.Destroy) then
		warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return taskId
end

function Minion:GiveOath(oath)
	if not oath:IsPending() then
		return oath
	end

	local newOath = oath.resolved(oath)
	local id = self:GiveTask(newOath)

	newOath:Finally(function()
		self[id] = nil
	end)

	return newOath
end

function Minion:DoCleaning()
	local tasks = self._tasks

	for index, task in pairs(tasks) do
		if typeof(task) == "RBXScriptConnection" then
			tasks[index] = nil
			task:Disconnect()
		end
	end

	local index, task = next(tasks)
	while task ~= nil do
		tasks[index] = nil
		if type(task) == "function" then
			task()
		elseif typeof(task) == "RBXScriptConnection" then
			task:Disconnect()
		elseif task.Destroy then
			task:Destroy()
		end
		index, task = next(tasks)
	end
end

Minion.Destroy = Minion.DoCleaning

return Minion