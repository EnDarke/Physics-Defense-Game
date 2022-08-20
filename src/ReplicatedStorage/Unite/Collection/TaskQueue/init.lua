--!strict

-- Author: Alex/EnDarke
-- Description: Handles task execution through a queue. Inspiration from Sleitnick's task queuing module.

local TaskQueue = {}
TaskQueue.__index = TaskQueue

function TaskQueue.new<T>(onFlush: ({ T }) -> nil)
	local self = setmetatable({}, TaskQueue)
	self._queue = {}
	self._flushing = false
	self._flushingScheduled = false
	self._onFlush = onFlush
	return self
end

function TaskQueue:Add<T>(object: T)
	table.insert(self._queue, object)
	if not self._flushingScheduled then
		self._flushingScheduled = true
		task.defer(function()
			if not self._flushingScheduled then
				return
			end
			self._flushing = true
			self._onFlush(self._queue)
			table.clear(self._queue)
			self._flushing = false
			self._flushingScheduled = false
		end)
	end
end

function TaskQueue:Clear()
	if self._flushing then
		return
	end
	table.clear(self._queue)
	self._flushingScheduled = false
end

function TaskQueue:Destroy()
	self:Clear()
end

return TaskQueue