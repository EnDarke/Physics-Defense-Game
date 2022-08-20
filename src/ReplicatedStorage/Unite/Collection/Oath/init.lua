-- !strict

-- Author: Alex/EnDarke
-- Description: Module to handle oaths/Oaths with functions.

--\\ Setup //--
local errorNoOathInList = "Oath value that is passed into %s at index %s is nil"
local errorNoList = "There was no list passed to %s"
local errorNoFunction = "There was no function passed to %s"
local modeKeyMetatable = {__mode = "k"}

--\\ Local Utility Functions //--
local function isCallable(value)
	if type(value) == "function" then
		return true
	end

	if type(value) == "table" then
		local metatable = getmetatable(value)
		if metatable and type(rawget(metatable, "__call")) == "function" then
			return true
		end
	end

	return false
end

local function makeEnum(enumName, members)
	local enum = {}

	for _, memberName in ipairs(members) do
		enum[memberName] = memberName
	end

	return setmetatable(enum, {
		__index = function(_, k)
			error(string.format("%s is not in %s!", k, enumName), 2)
		end,
		__newindex = function()
			error(string.format("Creating new members in %s is not allowed!", enumName), 2)
		end,
	})
end

local Error do
	Error = {
		Kind = makeEnum("Oath.Error.Kind", {
			"ExecutionError",
			"AlreadyCancelled",
			"NotResolvedInTime",
			"TimedOut",
		}),
	}
	Error.__index = Error

	function Error.new(options, parent)
		options = options or {}
		return setmetatable({
			error = tostring(options.error) or "[This error has no error text.]",
			trace = options.trace,
			context = options.context,
			kind = options.kind,
			parent = parent,
			createdTick = os.clock(),
			createdTrace = debug.traceback(),
		}, Error)
	end

	function Error.is(anything)
		if type(anything) == "table" then
			local metatable = getmetatable(anything)

			if type(metatable) == "table" then
				return rawget(anything, "error") ~= nil and type(rawget(metatable, "extend")) == "function"
			end
		end

		return false
	end

	function Error.isKind(anything, kind)
		assert(kind ~= nil, "Argument #2 to Oath.Error.isKind must not be nil")

		return Error.is(anything) and anything.kind == kind
	end

	function Error:Extend(options)
		options = options or {}

		options.kind = options.kind or self.kind

		return Error.new(options, self)
	end

	function Error:GetErrorChain()
		local runtimeErrors = { self }

		while runtimeErrors[#runtimeErrors].parent do
			table.insert(runtimeErrors, runtimeErrors[#runtimeErrors].parent)
		end

		return runtimeErrors
	end

	function Error:__tostring()
		local errorStrings = {
			string.format("-- Oath.Error(%s) --", self.kind or "?"),
		}

		for _, runtimeError in ipairs(self:GetErrorChain()) do
			table.insert(
				errorStrings,
				table.concat({
					runtimeError.trace or runtimeError.error,
					runtimeError.context,
				}, "\n")
			)
		end

		return table.concat(errorStrings, "\n")
	end
end

local function pack(...)
	return select("#", ...), { ... }
end

local function packResult(success, ...)
	return success, select("#", ...), { ... }
end

local function makeErrorHandler(traceback)
	assert(traceback ~= nil, "traceback is nil")

	return function(err)
		if type(err) == "table" then
			return err
		end

		return Error.new({
			error = err,
			kind = Error.Kind.ExecutionError,
			trace = debug.traceback(tostring(err), 2),
			context = "Oath created at:\n\n" .. traceback,
		})
	end
end

local function runExecutor(traceback, callback, ...)
	return packResult(xpcall(callback, makeErrorHandler(traceback), ...))
end

local function createAdvancer(traceback, callback, resolve, reject)
	return function(...)
		local ok, resultLength, result = runExecutor(traceback, callback, ...)

		if ok then
			resolve(unpack(result, 1, resultLength))
		else
			reject(result[1])
		end
	end
end

local function isEmpty(t)
	return next(t) == nil
end

local Oath = {
	Error = Error,
	Status = makeEnum("Oath.Status", { "Started", "Resolved", "Rejected", "Cancelled" }),
	_getTime = os.clock,
	_timeEvent = game:GetService("RunService").Heartbeat,
	_unhandledRejectionCallbacks = {},
}
Oath.prototype = {}
Oath.__index = Oath.prototype

function Oath._new(traceback, callback, parent)
	if parent ~= nil and not Oath.is(parent) then
		error("Argument #2 to Oath.new must be a oath or nil", 2)
	end

	local self = {
		_thread = nil,
		_source = traceback,
		_status = Oath.Status.Started,

		_values = nil,
		_valuesLength = -1,

		_unhandledRejection = true,

		_queuedResolve = {},
		_queuedReject = {},
		_queuedFinally = {},

		_cancellationHook = nil,

		_parent = parent,

		_consumers = setmetatable({}, modeKeyMetatable),
	}

	if parent and parent._status == Oath.Status.Started then
		parent._consumers[self] = true
	end

	setmetatable(self, Oath)

	local function resolve(...)
		self:_resolve(...)
	end

	local function reject(...)
		self:_reject(...)
	end

	local function onCancel(cancellationHook)
		if cancellationHook then
			if self._status == Oath.Status.Cancelled then
				cancellationHook()
			else
				self._cancellationHook = cancellationHook
			end
		end

		return self._status == Oath.Status.Cancelled
	end

	self._thread = coroutine.create(function()
		local ok, _, result = runExecutor(self._source, callback, resolve, reject, onCancel)

		if not ok then
			reject(result[1])
		end
	end)

	task.spawn(self._thread)

	return self
end

function Oath.new(executor)
	return Oath._new(debug.traceback(nil, 2), executor)
end

function Oath:__tostring()
	return string.format("Oath(%s)", self._status)
end

function Oath.Defer(executor)
	local traceback = debug.traceback(nil, 2)
	local oath
	oath = Oath._new(traceback, function(resolve, reject, onCancel)
		local connection
		connection = Oath._timeEvent:Connect(function()
			connection:Disconnect()
			local ok, _, result = runExecutor(traceback, executor, resolve, reject, onCancel)

			if not ok then
				reject(result[1])
			end
		end)
	end)

	return oath
end

Oath.async = Oath.Defer

function Oath.Resolve(...)
	local length, values = pack(...)
	return Oath._new(debug.traceback(nil, 2), function(resolve)
		resolve(unpack(values, 1, length))
	end)
end

function Oath.Reject(...)
	local length, values = pack(...)
	return Oath._new(debug.traceback(nil, 2), function(_, reject)
		reject(unpack(values, 1, length))
	end)
end

function Oath._try(traceback, callback, ...)
	local valuesLength, values = pack(...)

	return Oath._new(traceback, function(resolve)
		resolve(callback(unpack(values, 1, valuesLength)))
	end)
end

function Oath.Try(callback, ...)
	return Oath._try(debug.traceback(nil, 2), callback, ...)
end

function Oath._all(traceback, oaths, amount)
	if type(oaths) ~= "table" then
		error(string.format(errorNoList, "Oath.All"), 3)
	end

	for i, oath in pairs(oaths) do
		if not Oath.is(oath) then
			error(string.format(errorNoOathInList, "Oath.All", tostring(i)), 3)
		end
	end

	if #oaths == 0 or amount == 0 then
		return Oath.Resolve({})
	end

	return Oath._new(traceback, function(resolve, reject, onCancel)
		local resolvedValues = {}
		local newOaths = {}

		local resolvedCount = 0
		local rejectedCount = 0
		local done = false

		local function cancel()
			for _, oath in ipairs(newOaths) do
				oath:Cancel()
			end
		end

		local function resolveOne(i, ...)
			if done then
				return
			end

			resolvedCount = resolvedCount + 1

			if amount == nil then
				resolvedValues[i] = ...
			else
				resolvedValues[resolvedCount] = ...
			end

			if resolvedCount >= (amount or #oaths) then
				done = true
				resolve(resolvedValues)
				cancel()
			end
		end

		onCancel(cancel)

		for i, oath in ipairs(oaths) do
			newOaths[i] = oath:Follow(function(...)
				resolveOne(i, ...)
			end, function(...)
				rejectedCount = rejectedCount + 1

				if amount == nil or #oaths - rejectedCount < amount then
					cancel()
					done = true

					reject(...)
				end
			end)
		end

		if done then
			cancel()
		end
	end)
end

function Oath.All(oaths)
	return Oath._all(debug.traceback(nil, 2), oaths)
end

function Oath.Fold(list, reducer, initialValue)
	assert(type(list) == "table", "Bad argument #1 to Oath.Fold: must be a table")
	assert(isCallable(reducer), "Bad argument #2 to Oath.Fold: must be a function")

	local accumulator = Oath.Resolve(initialValue)
	return Oath.Each(list, function(resolvedElement, i)
		accumulator = accumulator:Follow(function(previousValueResolved)
			return reducer(previousValueResolved, resolvedElement, i)
		end)
	end):Follow(function()
		return accumulator
	end)
end

function Oath.Some(oaths, count)
	assert(type(count) == "number", "Bad argument #2 to Oath.some: must be a number")

	return Oath._all(debug.traceback(nil, 2), oaths, count)
end

function Oath.Any(oaths)
	return Oath._all(debug.traceback(nil, 2), oaths, 1):Follow(function(values)
		return values[1]
	end)
end

function Oath.AllSettled(oaths)
	if type(oaths) ~= "table" then
		error(string.format(errorNoList, "Oath.AllSettled"), 2)
	end

	for i, oath in pairs(oaths) do
		if not Oath.is(oath) then
			error(string.format(errorNoOathInList, "Oath.AllSettled", tostring(i)), 2)
		end
	end

	if #oaths == 0 then
		return Oath.Resolve({})
	end

	return Oath._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
		local fates = {}
		local newOaths = {}

		local finishedCount = 0

		local function resolveOne(i, ...)
			finishedCount = finishedCount + 1

			fates[i] = ...

			if finishedCount >= #oaths then
				resolve(fates)
			end
		end

		onCancel(function()
			for _, oath in ipairs(newOaths) do
				oath:Cancel()
			end
		end)

		for i, oath in ipairs(oaths) do
			newOaths[i] = oath:Finally(function(...)
				resolveOne(i, ...)
			end)
		end
	end)
end

function Oath.Race(oaths)
	assert(type(oaths) == "table", string.format(errorNoList, "Oath.Race"))

	for i, oath in pairs(oaths) do
		assert(Oath.is(oath), string.format(errorNoOathInList, "Oath.Race", tostring(i)))
	end

	return Oath._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
		local newOaths = {}
		local finished = false

		local function cancel()
			for _, oath in ipairs(newOaths) do
				oath:Cancel()
			end
		end

		local function finalize(callback)
			return function(...)
				cancel()
				finished = true
				return callback(...)
			end
		end

		if onCancel(finalize(reject)) then
			return
		end

		for i, oath in ipairs(oaths) do
			newOaths[i] = oath:Follow(finalize(resolve), finalize(reject))
		end

		if finished then
			cancel()
		end
	end)
end

function Oath.Each(list, predicate)
	assert(type(list) == "table", string.format(errorNoList, "Oath.Each"))
	assert(isCallable(predicate), string.format(errorNoFunction, "Oath.Each"))

	return Oath._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
		local results = {}
		local oathsToCancel = {}

		local cancelled = false

		local function cancel()
			for _, oathToCancel in ipairs(oathsToCancel) do
				oathToCancel:Cancel()
			end
		end

		onCancel(function()
			cancelled = true

			cancel()
		end)

		local preprocessedList = {}

		for index, value in ipairs(list) do
			if Oath.is(value) then
				if value:GetStatus() == Oath.Status.Cancelled then
					cancel()
					return reject(Error.new({
						error = "Oath is cancelled",
						kind = Error.Kind.AlreadyCancelled,
						context = string.format(
							"The Oath that was part of the array at index %d passed into Oath.Each was already cancelled when Oath.Each began.\n\nThat Oath was created at:\n\n%s",
							index,
							value._source
						),
					}))
				elseif value:GetStatus() == Oath.Status.Rejected then
					cancel()
					return reject(select(2, value:Await()))
				end

				local ourOath = value:Follow(function(...)
					return ...
				end)

				table.insert(oathsToCancel, ourOath)
				preprocessedList[index] = ourOath
			else
				preprocessedList[index] = value
			end
		end

		for index, value in ipairs(preprocessedList) do
			if Oath.is(value) then
				local success
				success, value = value:Await()

				if not success then
					cancel()
					return reject(value)
				end
			end

			if cancelled then
				return
			end

			local predicateOath = Oath.Resolve(predicate(value, index))

			table.insert(oathsToCancel, predicateOath)

			local success, result = predicateOath:Await()

			if not success then
				cancel()
				return reject(result)
			end

			results[index] = result
		end

		resolve(results)
	end)
end

function Oath.is(object)
	if type(object) ~= "table" then
		return false
	end

	local objectMetatable = getmetatable(object)

	if objectMetatable == Oath then
		return true
	elseif objectMetatable == nil then
		return isCallable(object.Follow)
	elseif
		type(objectMetatable) == "table"
		and type(rawget(objectMetatable, "__index")) == "table"
		and isCallable(rawget(rawget(objectMetatable, "__index"), "Follow"))
	then
		return true
	end

	return false
end

function Oath.oathify(callback)
	return function(...)
		return Oath._try(debug.traceback(nil, 2), callback, ...)
	end
end

do
	local first
	local connection

	function Oath.Delay(seconds)
		assert(type(seconds) == "number", "Bad argument #1 to Oath.delay, must be a number.")
		if not (seconds >= 1 / 60) or seconds == math.huge then
			seconds = 1 / 60
		end

		return Oath._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
			local startTime = Oath._getTime()
			local endTime = startTime + seconds

			local node = {
				resolve = resolve,
				startTime = startTime,
				endTime = endTime,
			}

			if connection == nil then
				first = node
				connection = Oath._timeEvent:Connect(function()
					local threadStart = Oath._getTime()

					while first ~= nil and first.endTime < threadStart do
						local current = first
						first = current.next

						if first == nil then
							connection:Disconnect()
							connection = nil
						else
							first.previous = nil
						end

						current.resolve(Oath._getTime() - current.startTime)
					end
				end)
			else
				if first.endTime < endTime then
					local current = first
					local next = current.next

					while next ~= nil and next.endTime < endTime do
						current = next
						next = current.next
					end

					current.next = node
					node.previous = current

					if next ~= nil then
						node.next = next
						next.previous = node
					end
				else
					node.next = first
					first.previous = node
					first = node
				end
			end

			onCancel(function()
				local next = node.next

				if first == node then
					if next == nil then
						connection:Disconnect()
						connection = nil
					else
						next.previous = nil
					end
					first = next
				else
					local previous = node.previous
					previous.next = next

					if next ~= nil then
						next.previous = previous
					end
				end
			end)
		end)
	end
end

function Oath.prototype:Timeout(seconds, rejectionValue)
	local traceback = debug.traceback(nil, 2)

	return Oath.Race({
		Oath.Delay(seconds):Follow(function()
			return Oath.Reject(rejectionValue == nil and Error.new({
				kind = Error.Kind.TimedOut,
				error = "Timed out",
				context = string.format(
					"Timeout of %d seconds exceeded.\n:Timeout() called at:\n\n%s",
					seconds,
					traceback
				),
			}) or rejectionValue)
		end),
		self,
	})
end

function Oath.prototype:getStatus()
	return self._status
end

function Oath.prototype:_andThen(traceback, successHandler, failureHandler)
	self._unhandledRejection = false

	if self._status == Oath.Status.Cancelled then
		local oath = Oath.new(function() end)
		oath:Cancel()

		return oath
	end

	return Oath._new(traceback, function(resolve, reject, onCancel)
		local successCallback = resolve
		if successHandler then
			successCallback = createAdvancer(traceback, successHandler, resolve, reject)
		end

		local failureCallback = reject
		if failureHandler then
			failureCallback = createAdvancer(traceback, failureHandler, resolve, reject)
		end

		if self._status == Oath.Status.Started then
			table.insert(self._queuedResolve, successCallback)
			table.insert(self._queuedReject, failureCallback)

			onCancel(function()
				if self._status == Oath.Status.Started then
					table.remove(self._queuedResolve, table.find(self._queuedResolve, successCallback))
					table.remove(self._queuedReject, table.find(self._queuedReject, failureCallback))
				end
			end)
		elseif self._status == Oath.Status.Resolved then
			successCallback(unpack(self._values, 1, self._valuesLength))
		elseif self._status == Oath.Status.Rejected then
			failureCallback(unpack(self._values, 1, self._valuesLength))
		end
	end, self)
end

function Oath.prototype:Follow(successHandler, failureHandler)
	assert(successHandler == nil or isCallable(successHandler), string.format(errorNoFunction, "Oath:Follow"))
	assert(failureHandler == nil or isCallable(failureHandler), string.format(errorNoFunction, "Oath:Follow"))

	return self:_andThen(debug.traceback(nil, 2), successHandler, failureHandler)
end

function Oath.prototype:Hook(failureHandler)
	assert(failureHandler == nil or isCallable(failureHandler), string.format(errorNoFunction, "Oath:Hook"))
	return self:_andThen(debug.traceback(nil, 2), nil, failureHandler)
end

function Oath.prototype:Tap(tapHandler)
	assert(isCallable(tapHandler), string.format(errorNoFunction, "Oath:Tap"))
	return self:_andThen(debug.traceback(nil, 2), function(...)
		local callbackReturn = tapHandler(...)

		if Oath.is(callbackReturn) then
			local length, values = pack(...)
			return callbackReturn:Follow(function()
				return unpack(values, 1, length)
			end)
		end

		return ...
	end)
end

function Oath.prototype:FollowCall(callback, ...)
	assert(isCallable(callback), string.format(errorNoFunction, "Oath:FollowCall"))
	local length, values = pack(...)
	return self:_andThen(debug.traceback(nil, 2), function()
		return callback(unpack(values, 1, length))
	end)
end

function Oath.prototype:FollowReturn(...)
	local length, values = pack(...)
	return self:_andThen(debug.traceback(nil, 2), function()
		return unpack(values, 1, length)
	end)
end

function Oath.prototype:Cancel()
	if self._status ~= Oath.Status.Started then
		return
	end

	self._status = Oath.Status.Cancelled

	if self._cancellationHook then
		self._cancellationHook()
	end

	coroutine.close(self._thread)

	if self._parent then
		self._parent:_consumerCancelled(self)
	end

	for child in pairs(self._consumers) do
		child:Cancel()
	end

	self:_finalize()
end

function Oath.prototype:_consumerCancelled(consumer)
	if self._status ~= Oath.Status.Started then
		return
	end

	self._consumers[consumer] = nil

	if next(self._consumers) == nil then
		self:Cancel()
	end
end

function Oath.prototype:_finally(traceback, finallyHandler)
	self._unhandledRejection = false

	local oath = Oath._new(traceback, function(resolve, reject, onCancel)
		local handlerOath

		onCancel(function()
			self:_consumerCancelled(self)

			if handlerOath then
				handlerOath:Cancel()
			end
		end)

		local finallyCallback = resolve
		if finallyHandler then
			finallyCallback = function(...)
				local callbackReturn = finallyHandler(...)

				if Oath.is(callbackReturn) then
					handlerOath = callbackReturn

					callbackReturn
						:Finally(function(status)
							if status ~= Oath.Status.Rejected then
								resolve(self)
							end
						end)
						:Hook(function(...)
							reject(...)
						end)
				else
					resolve(self)
				end
			end
		end

		if self._status == Oath.Status.Started then
			table.insert(self._queuedFinally, finallyCallback)
		else
			finallyCallback(self._status)
		end
	end)

	return oath
end

function Oath.prototype:Finally(finallyHandler)
	assert(finallyHandler == nil or isCallable(finallyHandler), string.format(errorNoFunction, "Oath:Finally"))
	return self:_finally(debug.traceback(nil, 2), finallyHandler)
end

function Oath.prototype:FinallyCall(callback, ...)
	assert(isCallable(callback), string.format(errorNoFunction, "Oath:FinallyCall"))
	local length, values = pack(...)
	return self:_finally(debug.traceback(nil, 2), function()
		return callback(unpack(values, 1, length))
	end)
end

function Oath.prototype:FinallyReturn(...)
	local length, values = pack(...)
	return self:_finally(debug.traceback(nil, 2), function()
		return unpack(values, 1, length)
	end)
end

function Oath.prototype:AwaitStatus()
	self._unhandledRejection = false

	if self._status == Oath.Status.Started then
		local thread = coroutine.running()

		self
			:Finally(function()
				task.spawn(thread)
			end)
			:Hook(
				function() end
			)

		coroutine.yield()
	end

	if self._status == Oath.Status.Resolved then
		return self._status, unpack(self._values, 1, self._valuesLength)
	elseif self._status == Oath.Status.Rejected then
		return self._status, unpack(self._values, 1, self._valuesLength)
	end

	return self._status
end

local function awaitHelper(status, ...)
	return status == Oath.Status.Resolved, ...
end

function Oath.prototype:Await()
	return awaitHelper(self:AwaitStatus())
end

local function expectHelper(status, ...)
	if status ~= Oath.Status.Resolved then
		error((...) == nil and "Expected Oath rejected with no value." or (...), 3)
	end

	return ...
end

function Oath.prototype:Expect()
	return expectHelper(self:AwaitStatus())
end

Oath.prototype.awaitValue = Oath.prototype.Expect

function Oath.prototype:_unwrap()
	if self._status == Oath.Status.Started then
		error("Oath has not resolved or rejected.", 2)
	end

	local success = self._status == Oath.Status.Resolved

	return success, unpack(self._values, 1, self._valuesLength)
end

function Oath.prototype:_resolve(...)
	if self._status ~= Oath.Status.Started then
		if Oath.is((...)) then
			(...):_consumerCancelled(self)
		end
		return
	end

	if Oath.is((...)) then
		if select("#", ...) > 1 then
			local message = string.format(
				"When returning a Oath from Follow, extra arguments are " .. "discarded! See:\n\n%s",
				self._source
			)
			warn(message)
		end

		local chainedOath = ...

		local oath = chainedOath:Follow(function(...)
			self:_resolve(...)
		end, function(...)
			local maybeRuntimeError = chainedOath._values[1]

			if chainedOath._error then
				maybeRuntimeError = Error.new({
					error = chainedOath._error,
					kind = Error.Kind.ExecutionError,
					context = "[No stack trace available as this Oath originated from an older version of the Oath library (< v2)]",
				})
			end

			if Error.isKind(maybeRuntimeError, Error.Kind.ExecutionError) then
				return self:_reject(maybeRuntimeError:Extend({
					error = "This Oath was chained to a Oath that errored.",
					trace = "",
					context = string.format(
						"The Oath at:\n\n%s\n...Rejected because it was chained to the following Oath, which encountered an error:\n",
						self._source
					),
				}))
			end

			self:_reject(...)
		end)

		if oath._status == Oath.Status.Cancelled then
			self:Cancel()
		elseif oath._status == Oath.Status.Started then
			self._parent = oath
			oath._consumers[self] = true
		end

		return
	end

	self._status = Oath.Status.Resolved
	self._valuesLength, self._values = pack(...)

	for _, callback in ipairs(self._queuedResolve) do
		coroutine.wrap(callback)(...)
	end

	self:_finalize()
end

function Oath.prototype:_reject(...)
	if self._status ~= Oath.Status.Started then
		return
	end

	self._status = Oath.Status.Rejected
	self._valuesLength, self._values = pack(...)

	if not isEmpty(self._queuedReject) then
		for _, callback in ipairs(self._queuedReject) do
			coroutine.wrap(callback)(...)
		end
	else
		local err = tostring((...))

		coroutine.wrap(function()
			Oath._timeEvent:Wait()

			if not self._unhandledRejection then
				return
			end

			local message = string.format("Unhandled Oath rejection:\n\n%s\n\n%s", err, self._source)

			for _, callback in ipairs(Oath._unhandledRejectionCallbacks) do
				task.spawn(callback, self, unpack(self._values, 1, self._valuesLength))
			end

			if Oath.TEST then
				return
			end

			warn(message)
		end)()
	end

	self:_finalize()
end

function Oath.prototype:_finalize()
	for _, callback in ipairs(self._queuedFinally) do
		coroutine.wrap(callback)(self._status)
	end

	self._queuedFinally = nil
	self._queuedReject = nil
	self._queuedResolve = nil

	if not Oath.TEST then
		self._parent = nil
		self._consumers = nil
	end

	task.defer(coroutine.close, self._thread)
end

function Oath.prototype:now(rejectionValue)
	local traceback = debug.traceback(nil, 2)
	if self._status == Oath.Status.Resolved then
		return self:_andThen(traceback, function(...)
			return ...
		end)
	else
		return Oath.Reject(rejectionValue == nil and Error.new({
			kind = Error.Kind.NotResolvedInTime,
			error = "This Oath was not resolved in time for :now()",
			context = ":Now() was called at:\n\n" .. traceback,
		}) or rejectionValue)
	end
end

function Oath.Retry(callback, times, ...)
	assert(isCallable(callback), "Parameter #1 to Oath.retry must be a function")
	assert(type(times) == "number", "Parameter #2 to Oath.retry must be a number")

	local args, length = { ... }, select("#", ...)

	return Oath.Resolve(callback(...)):Hook(function(...)
		if times > 0 then
			return Oath.Retry(callback, times - 1, unpack(args, 1, length))
		else
			return Oath.Reject(...)
		end
	end)
end

function Oath.RetryWithDelay(callback, times, seconds, ...)
	assert(isCallable(callback), "Parameter #1 to Oath.retry must be a function")
	assert(type(times) == "number", "Parameter #2 (times) to Oath.retry must be a number")
	assert(type(seconds) == "number", "Parameter #3 (seconds) to Oath.retry must be a number")

	local args, length = { ... }, select("#", ...)

	return Oath.Resolve(callback(...)):Hook(function(...)
		if times > 0 then
			Oath.Delay(seconds):Await()

			return Oath.RetryWithDelay(callback, times - 1, seconds, unpack(args, 1, length))
		else
			return Oath.Reject(...)
		end
	end)
end

function Oath.fromEvent(event, predicate)
	predicate = predicate or function()
		return true
	end

	return Oath._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
		local connection
		local shouldDisconnect = false

		local function disconnect()
			connection:Disconnect()
			connection = nil
		end

		connection = event:Connect(function(...)
			local callbackValue = predicate(...)

			if callbackValue == true then
				resolve(...)

				if connection then
					disconnect()
				else
					shouldDisconnect = true
				end
			elseif type(callbackValue) ~= "boolean" then
				error("Oath.fromEvent predicate should always return a boolean")
			end
		end)

		if shouldDisconnect and connection then
			return disconnect()
		end

		onCancel(disconnect)
	end)
end

function Oath.onUnhandledRejection(callback)
	table.insert(Oath._unhandledRejectionCallbacks, callback)

	return function()
		local index = table.find(Oath._unhandledRejectionCallbacks, callback)

		if index then
			table.remove(Oath._unhandledRejectionCallbacks, index)
		end
	end
end

return Oath