-- !strict

-- Author: Alex/EnDarke
-- Description: Used to save data in secure ways while also having ease of access

--\\ Unite //--
local Unite = require(game:GetService("ReplicatedStorage").Unite.Unite)
local Collection = Unite.Collection
local Settings = Unite.Settings

--\\ Modules //--
local Util = require(Collection.Util)

--\\ Settings //--
local AccountSettings = Settings.Accounts

--\\ Code Connections //--
local AccountConnection do
	local AccountConnectionScriptSignal = {}

	local FreeRunnerThread = nil

	local function AcquireRunnerThreadAndCallEventHandler(fn, ...)
		local acquired_runner_thread = FreeRunnerThread
		FreeRunnerThread = nil
		fn(...)
		FreeRunnerThread = acquired_runner_thread
	end

	local function RunEventHandlerInFreeThread(...)
		AcquireRunnerThreadAndCallEventHandler(...)
		while true do
			AcquireRunnerThreadAndCallEventHandler(coroutine.yield())
		end
	end

	local ScriptConnection = {}
	ScriptConnection.__index = ScriptConnection

	function ScriptConnection:Disconnect()
		if self._is_connected == false then
			return
		end

		self._is_connected = false
		self._script_signal._listener_count -= 1

		if self._script_signal._head == self then
			self._script_signal._head = self._next
		else
			local prev = self._script_signal._head
			while prev ~= nil and prev._next ~= self do
				prev = prev._next
			end
			if prev ~= nil then
				prev._next = self._next
			end
		end

		if self._disconnect_listener ~= nil then
			if not FreeRunnerThread then
				FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
			end
			task.spawn(FreeRunnerThread, self._disconnect_listener, self._disconnect_param)
			self._disconnect_listener = nil
		end
	end

	local ScriptSignal = {}
	ScriptSignal.__index = ScriptSignal

	function ScriptSignal:Connect(listener, disconnect_listener, disconnect_param)
		local script_connection = {
			_listener = listener,
			_script_signal = self,
			_disconnect_listener = disconnect_listener,
			_disconnect_param = disconnect_param,

			_next = self._head,
			_is_connected = true,
		}
		setmetatable(script_connection, ScriptConnection)

		self._head = script_connection
		self._listener_count += 1

		return script_connection
	end

	function ScriptSignal:GetListenerCount()
		return self._listener_count
	end

	function ScriptSignal:Fire(...)
		local item = self._head
		while item ~= nil do
			if item._is_connected == true then
				if not FreeRunnerThread then
					FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
				end
				task.spawn(FreeRunnerThread, item._listener, ...)
			end
			item = item._next
		end
	end

	function ScriptSignal:FireUntil(continue_callback, ...)
		local item = self._head
		while item ~= nil do
			if item._is_connected == true then
				item._listener(...)
				if continue_callback() ~= true then
					return
				end
			end
			item = item._next
		end
	end

	function AccountConnectionScriptSignal.NewScriptSignal()
		return {
			_head = nil,
			_listener_count = 0,
			Connect = ScriptSignal.Connect,
			GetListenerCount = ScriptSignal.GetListenerCount,
			Fire = ScriptSignal.Fire,
			FireUntil = ScriptSignal.FireUntil,
		}
	end

	AccountConnection = {
		NewScriptSignal = AccountConnectionScriptSignal.NewScriptSignal,
		ConnectToOnClose = function(task, run_in_studio_mode)
			if game:GetService("RunService"):IsStudio() == false or run_in_studio_mode == true then
				game:BindToClose(task)
			end
		end,
	}
end

--\\ Module Code //--
local Accounts = {}
Accounts.ServiceLocked = false
Accounts.IssueSignal = AccountConnection.NewScriptSignal()
Accounts.CorruptionSignal = AccountConnection.NewScriptSignal()
Accounts.CriticalState = false
Accounts.CriticalStateSignal = AccountConnection.NewScriptSignal()
Accounts.ServiceIssueCount = 0
Accounts._active_account_stores = {}
Accounts._auto_save_list = {}
Accounts._issue_queue = {}
Accounts._critical_state_start = 0
Accounts._mock_data_store = {}
Accounts._user_mock_data_store = {}
Accounts._use_mock_data_store = false

--\\ Variables //--
local ActiveAccountStores = Accounts._active_account_stores
local AutoSaveList = Accounts._auto_save_list
local IssueQueue = Accounts._issue_queue

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PlaceId = game.PlaceId
local JobId = game.JobId

local AutoSaveIndex = 1
local LastAutoSave = os.clock()

local LoadIndex = 0

local ActiveAccountLoadJobs = 0
local ActiveAccountSaveJobs = 0

local CriticalStateStart = 0

local IsStudio = RunService:IsStudio()
local IsLiveCheckActive = false

local UseMockDataStore = false
local MockDataStore = Accounts._mock_data_store

local UserMockDataStore = Accounts._user_mock_data_store
local UseMockTag = {}

local CustomWriteQueue = {}

--\\ Local Utility Functions //--
local function IdentifyAccount(store_name: string, store_scope: string, key: string)
	return string.format(
		"[Store:\"%s\";%sKey:\"%s\"]",
		store_name,
		store_scope ~= nil and string.format("Scope:\"%s\";", store_scope) or "",
		key
	)
end

local function CustomWriteQueueCleanup(store: number, key: string)
	if CustomWriteQueue[store] ~= nil then
		CustomWriteQueue[store][key] = nil
		if next(CustomWriteQueue[store]) == nil then
			CustomWriteQueue[store] = nil
		end
	end
end

local function CustomWriteQueueMarkForCleanup(store: number, key: string)
	if CustomWriteQueue[store] ~= nil then
		if CustomWriteQueue[store][key] ~= nil then

			local queue_data = CustomWriteQueue[store][key]
			local queue = queue_data.Queue

			if queue_data.CleanupJob == nil then

				queue_data.CleanupJob = RunService.Heartbeat:Connect(function()
					if os.clock() - queue_data.LastWrite > AccountSettings.RobloxWriteDebounce and #queue == 0 then
						queue_data.CleanupJob:Disconnect()
						CustomWriteQueueCleanup(store, key)
					end
				end)

			end

		elseif next(CustomWriteQueue[store]) == nil then
			CustomWriteQueue[store] = nil
		end
	end
end

local function CustomWriteQueueAsync(callback: RBXScriptConnection, store: number, key: string)
	if CustomWriteQueue[store] == nil then
		CustomWriteQueue[store] = {}
	end

	if CustomWriteQueue[store][key] == nil then
		CustomWriteQueue[store][key] = {LastWrite = 0, Queue = {}, CleanupJob = nil}
	end

	local queue_data = CustomWriteQueue[store][key]
	local queue = queue_data.Queue

	if queue_data.CleanupJob ~= nil then
		queue_data.CleanupJob:Disconnect()
		queue_data.CleanupJob = nil
	end

	if os.clock() - queue_data.LastWrite > AccountSettings.RobloxWriteDebounce and #queue == 0 then
		queue_data.LastWrite = os.clock()
		return callback()
	else
		table.insert(queue, callback)
		while true do
			if os.clock() - queue_data.LastWrite > AccountSettings.RobloxWriteDebounce and queue[1] == callback then
				table.remove(queue, 1)
				queue_data.LastWrite = os.clock()
				return callback()
			end
			task.wait()
		end
	end
end

local function IsCustomWriteQueueEmptyFor(store: number, key: string)
	local lookup = CustomWriteQueue[store]
	if lookup ~= nil then
		lookup = lookup[key]
		return lookup == nil or #lookup.Queue == 0
	end
	return true
end

local function WaitForLiveAccessCheck()
	while IsLiveCheckActive == true do
		task.wait()
	end
end

local function WaitForPendingAccountStore(account_store: table)
	while account_store._is_pending == true do
		task.wait()
	end
end

local function RegisterIssue(error_message: string, store_name: string, store_scope: string, account_key: string)
	warn("[Accounts]: DataStore API error " .. IdentifyAccount(store_name, store_scope, account_key) .. " - \"" .. tostring(error_message) .. "\"")
	table.insert(IssueQueue, os.clock())
	Accounts.IssueSignal:Fire(tostring(error_message), store_name, account_key)
end

local function RegisterCorruption(store_name: string, store_scope: string, account_key: string)
	warn("[Accounts]: Resolved account corruption " .. IdentifyAccount(store_name, store_scope, account_key))
	Accounts.CorruptionSignal:Fire(store_name, account_key)
end

local function NewMockDataStoreKeyInfo(params)
	local version_id_string = tostring(params.VersionId or 0)
	local meta_data = params.MetaData or {}
	local user_ids = params.UserIds or {}

	return {
		CreatedTime = params.CreatedTime,
		UpdatedTime = params.UpdatedTime,
		Version = string.rep("0", 16) .. "."
			.. string.rep("0", 10 - string.len(version_id_string)) .. version_id_string
			.. "." .. string.rep("0", 16) .. "." .. "01",

		GetMetadata = function()
			return Util._deepCopy(meta_data)
		end,

		GetUserIds = function()
			return Util._deepCopy(user_ids)
		end,
	}
end

local function MockUpdateAsync(mock_data_store, account_store_name, key, transform_function, is_get_call)
	local account_store = mock_data_store[account_store_name]

	if account_store == nil then
		account_store = {}
		mock_data_store[account_store_name] = account_store
	end

	local epoch_time = math.floor(os.time() * 1000)
	local mock_entry = account_store[key]
	local mock_entry_was_nil = false

	if mock_entry == nil then
		mock_entry_was_nil = true
		if is_get_call ~= true then
			mock_entry = {
				Data = nil,
				CreatedTime = epoch_time,
				UpdatedTime = epoch_time,
				VersionId = 0,
				UserIds = {},
				MetaData = {},
			}
			account_store[key] = mock_entry
		end
	end

	local mock_key_info = mock_entry_was_nil == false and NewMockDataStoreKeyInfo(mock_entry) or nil

	local transform, user_ids, roblox_meta_data = transform_function(mock_entry and mock_entry.Data, mock_key_info)

	if transform == nil then
		return nil
	else
		if mock_entry ~= nil and is_get_call ~= true then
			mock_entry.Data = transform
			mock_entry.UserIds = Util._deepCopy(user_ids or {})
			mock_entry.MetaData = Util._deepCopy(roblox_meta_data or {})
			mock_entry.VersionId += 1
			mock_entry.UpdatedTime = epoch_time
		end

		return Util._deepCopy(transform), mock_entry ~= nil and NewMockDataStoreKeyInfo(mock_entry) or nil
	end
end

local function IsThisSession(session_tag)
	return session_tag[1] == PlaceId and session_tag[2] == JobId
end

local function StandardAccountUpdateAsyncDataStore(account_store, account_key, update_settings, is_user_mock, is_get_call, _version)
	local loaded_data, key_info
	local success, error_message = pcall(function()
		local transform_function = function(latest_data)

			local missing_account = false
			local data_corrupted = false
			local global_updates_data = {0, {}}

			if latest_data == nil then
				missing_account = true
			elseif type(latest_data) ~= "table" then
				missing_account = true
				data_corrupted = true
			end

			if type(latest_data) == "table" then
				if type(latest_data.Data) == "table"
					and type(latest_data.MetaData) == "table"
					and type(latest_data.GlobalUpdates) == "table" then

					latest_data.WasCorrupted = false
					global_updates_data = latest_data.GlobalUpdates
					if update_settings.ExistingAccountHandle ~= nil then
						update_settings.ExistingAccountHandle(latest_data)
					end
				elseif latest_data.Data == nil
					and latest_data.MetaData == nil
					and type(latest_data.GlobalUpdates) == "table" then

					latest_data.WasCorrupted = false
					global_updates_data = latest_data.GlobalUpdates or global_updates_data
					missing_account = true
				else
					missing_account = true
					data_corrupted = true
				end
			end

			if missing_account == true then
				latest_data = {
					GlobalUpdates = global_updates_data,
				}
				if update_settings.MissingAccountHandle ~= nil then
					update_settings.MissingAccountHandle(latest_data)
				end
			end

			if update_settings.EditAccount ~= nil then
				update_settings.EditAccount(latest_data)
			end

			if data_corrupted == true then
				latest_data.WasCorrupted = true
			end

			return latest_data, latest_data.UserIds, latest_data.RobloxMetaData
		end
		if is_user_mock == true then
			loaded_data, key_info = MockUpdateAsync(UserMockDataStore, account_store._account_store_lookup, account_key, transform_function, is_get_call)
			task.wait()
		elseif UseMockDataStore == true then
			loaded_data, key_info = MockUpdateAsync(MockDataStore, account_store._account_store_lookup, account_key, transform_function, is_get_call)
			task.wait()
		else
			loaded_data, key_info = CustomWriteQueueAsync(
				function()
					if is_get_call == true then
						local get_data, get_key_info
						if _version ~= nil then
							local success, error_message = pcall(function()
								get_data, get_key_info = account_store._global_data_store:GetVersionAsync(account_key, _version)
							end)
							if success == false and type(error_message) == "string" and string.find(error_message, "not valid") ~= nil then
								warn("[Accounts]: Passed version argument is not valid; Traceback:\n" .. debug.traceback())
							end
						else
							get_data, get_key_info = account_store._global_data_store:GetAsync(account_key)
						end
						get_data = transform_function(get_data)
						return get_data, get_key_info
					else
						return account_store._global_data_store:UpdateAsync(account_key, transform_function)
					end
				end,
				account_store._account_store_lookup,
				account_key
			)
		end
	end)
	if success == true and type(loaded_data) == "table" then
		if loaded_data.WasCorrupted == true and is_get_call ~= true then
			RegisterCorruption(
				account_store._account_store_name,
				account_store._account_store_scope,
				account_key
			)
		end
		return loaded_data, key_info
	else
		RegisterIssue(
			(error_message ~= nil) and error_message or "Undefined error",
			account_store._account_store_name,
			account_store._account_store_scope,
			account_key
		)
		return nil
	end
end

local function RemoveAccountFromAutoSave(account)
	local auto_save_index = table.find(AutoSaveList, account)
	if auto_save_index ~= nil then
		table.remove(AutoSaveList, auto_save_index)
		if auto_save_index < AutoSaveIndex then
			AutoSaveIndex = AutoSaveIndex - 1
		end
		if AutoSaveList[AutoSaveIndex] == nil then
			AutoSaveIndex = 1
		end
	end
end

local function AddAccountToAutoSave(account)
	table.insert(AutoSaveList, AutoSaveIndex, account)
	if #AutoSaveList > 1 then
		AutoSaveIndex = AutoSaveIndex + 1
	elseif #AutoSaveList == 1 then
		LastAutoSave = os.clock()
	end
end

local function ReleaseAccountInternally(account)
	local account_store = account._account_store
	local loaded_accounts = account._is_user_mock == true and account_store._mock_loaded_accounts or account_store._loaded_accounts
	loaded_accounts[account._account_key] = nil
	if next(account_store._loaded_accounts) == nil and next(account_store._mock_loaded_accounts) == nil then
		local index = table.find(ActiveAccountStores, account_store)
		if index ~= nil then
			table.remove(ActiveAccountStores, index)
		end
	end
	RemoveAccountFromAutoSave(account)
	local place_id
	local game_job_id
	local active_session = account.MetaData.ActiveSession
	if active_session ~= nil then
		place_id = active_session[1]
		game_job_id = active_session[2]
	end
	account._release_listeners:Fire(place_id, game_job_id)
end

local function CheckForNewGlobalUpdates(account, old_global_updates_data, new_global_updates_data)
	local global_updates_object = account.GlobalUpdates
	local pending_update_lock = global_updates_object._pending_update_lock
	local pending_update_clear = global_updates_object._pending_update_clear
	for _, new_global_update in ipairs(new_global_updates_data[2]) do
		local old_global_update
		for _, global_update in ipairs(old_global_updates_data[2]) do
			if global_update[1] == new_global_update[1] then
				old_global_update = global_update
				break
			end
		end
		local is_new = false
		if old_global_update == nil or new_global_update[2] > old_global_update[2] or new_global_update[3] ~= old_global_update[3] then
			is_new = true
		end
		if is_new == true then
			if new_global_update[3] == false then
				local is_pending_lock = false
				for _, update_id in ipairs(pending_update_lock) do
					if new_global_update[1] == update_id then
						is_pending_lock = true
						break
					end
				end
				if is_pending_lock == false then
					global_updates_object._new_active_update_listeners:Fire(new_global_update[1], new_global_update[4])
				end
			end
			if new_global_update[3] == true then
				local is_pending_clear = false
				for _, update_id in ipairs(pending_update_clear) do
					if new_global_update[1] == update_id then
						is_pending_clear = true
						break
					end
				end
				if is_pending_clear == false then
					global_updates_object._new_locked_update_listeners:FireUntil(
						function()
							return table.find(pending_update_clear, new_global_update[1]) == nil
						end,
						new_global_update[1], new_global_update[4]
					)

				end
			end
		end
	end
end

local function SaveAccountAsync(account, release_from_session, is_overwriting)
	if type(account.Data) ~= "table" then
		RegisterCorruption(
			account._account_store._account_store_name,
			account._account_store._account_store_scope,
			account._account_key
		)
		error("[Accounts]: ACCOUNT DATA CORRUPTED DURING RUNTIME! Account: " .. account:Identify())
	end
	if release_from_session == true and is_overwriting ~= true then
		ReleaseAccountInternally(account)
	end
	ActiveAccountSaveJobs = ActiveAccountSaveJobs + 1
	local last_session_load_count = account.MetaData.SessionLoadCount
	local repeat_save_flag = true
	while repeat_save_flag == true do
		if release_from_session ~= true then
			repeat_save_flag = false
		end
		local loaded_data, key_info = StandardAccountUpdateAsyncDataStore(
			account._account_store,
			account._account_key,
			{
				ExistingAccountHandle = nil,
				MissingAccountHandle = nil,
				EditAccount = function(latest_data)

					local session_owns_account = false
					local force_load_pending = false

					if is_overwriting ~= true then
						local active_session = latest_data.MetaData.ActiveSession
						local force_load_session = latest_data.MetaData.ForceLoadSession
						local session_load_count = latest_data.MetaData.SessionLoadCount

						if type(active_session) == "table" then
							session_owns_account = IsThisSession(active_session) and session_load_count == last_session_load_count
						end
						if type(force_load_session) == "table" then
							force_load_pending = not IsThisSession(force_load_session)
						end
					else
						session_owns_account = true
					end

					if session_owns_account == true then

						if is_overwriting ~= true then
							local latest_global_updates_data = latest_data.GlobalUpdates
							local latest_global_updates_list = latest_global_updates_data[2]

							local global_updates_object = account.GlobalUpdates
							local pending_update_lock = global_updates_object._pending_update_lock
							local pending_update_clear = global_updates_object._pending_update_clear
							for i = 1, #latest_global_updates_list do
								for _, lock_id in ipairs(pending_update_lock) do
									if latest_global_updates_list[i][1] == lock_id then
										latest_global_updates_list[i][3] = true
										break
									end
								end
							end
							for _, clear_id in ipairs(pending_update_clear) do
								for i = 1, #latest_global_updates_list do
									if latest_global_updates_list[i][1] == clear_id and latest_global_updates_list[i][3] == true then
										table.remove(latest_global_updates_list, i)
										break
									end
								end
							end
						end

						latest_data.Data = account.Data
						latest_data.RobloxMetaData = account.RobloxMetaData
						latest_data.UserIds = account.UserIds

						if is_overwriting ~= true then
							latest_data.MetaData.MetaTags = account.MetaData.MetaTags
							latest_data.MetaData.LastUpdate = os.time()
							if release_from_session == true or force_load_pending == true then
								latest_data.MetaData.ActiveSession = nil
							end
						else
							latest_data.MetaData = account.MetaData
							latest_data.MetaData.ActiveSession = nil
							latest_data.MetaData.ForceLoadSession = nil
							latest_data.GlobalUpdates = account.GlobalUpdates._updates_latest
						end

					end
				end,
			},
			account._is_user_mock
		)
		if loaded_data ~= nil and key_info ~= nil then
			if is_overwriting == true then
				break
			end
			repeat_save_flag = false
			account.KeyInfo = key_info
			local global_updates_object = account.GlobalUpdates
			local old_global_updates_data = global_updates_object._updates_latest
			local new_global_updates_data = loaded_data.GlobalUpdates
			global_updates_object._updates_latest = new_global_updates_data
			local session_meta_data = account.MetaData
			local latest_meta_data = loaded_data.MetaData
			for key in pairs(AccountSettings.MetaTagsUpdated) do
				session_meta_data[key] = latest_meta_data[key]
			end
			session_meta_data.MetaTagsLatest = latest_meta_data.MetaTags
			local active_session = loaded_data.MetaData.ActiveSession
			local session_load_count = loaded_data.MetaData.SessionLoadCount
			local session_owns_account = false
			if type(active_session) == "table" then
				session_owns_account = IsThisSession(active_session) and session_load_count == last_session_load_count
			end
			local is_active = account:IsActive()
			if session_owns_account == true then
				if is_active == true then
					CheckForNewGlobalUpdates(account, old_global_updates_data, new_global_updates_data)
				end
			else
				if is_active == true then
					ReleaseAccountInternally(account)
				end
				CustomWriteQueueMarkForCleanup(account._account_store._account_store_lookup, account._account_key)
				if account._hop_ready == false then
					account._hop_ready = true
					account._hop_ready_listeners:Fire()
				end
			end
			account.MetaTagsUpdated:Fire(account.MetaData.MetaTagsLatest)
			account.KeyInfoUpdated:Fire(key_info)
		elseif repeat_save_flag == true then
			task.wait()
		end
	end
	ActiveAccountSaveJobs = ActiveAccountSaveJobs - 1
end

--\\ GlobalUpdates Class //--
local GlobalUpdates = {}
GlobalUpdates.__index = GlobalUpdates

function GlobalUpdates:GetActiveUpdates()
	local query_list = {}
	for _, global_update in ipairs(self._updates_latest[2]) do
		if global_update[3] == false then
			local is_pending_lock = false
			if self._pending_update_lock ~= nil then
				for _, update_id in ipairs(self._pending_update_lock) do
					if global_update[1] == update_id then
						is_pending_lock = true
						break
					end
				end
			end
			if is_pending_lock == false then
				table.insert(query_list, {global_update[1], global_update[4]})
			end
		end
	end
	return query_list
end

function GlobalUpdates:GetLockedUpdates()
	local query_list = {}
	for _, global_update in ipairs(self._updates_latest[2]) do
		if global_update[3] == true then
			local is_pending_clear = false
			if self._pending_update_clear ~= nil then
				for _, update_id in ipairs(self._pending_update_clear) do
					if global_update[1] == update_id then
						is_pending_clear = true
						break
					end
				end
			end
			if is_pending_clear == false then
				table.insert(query_list, {global_update[1], global_update[4]})
			end
		end
	end
	return query_list
end

function GlobalUpdates:ListenToNewActiveUpdate(listener)
	if type(listener) ~= "function" then
		error("[Accounts]: Only a function can be set as listener in GlobalUpdates:ListenToNewActiveUpdate()")
	end
	local account = self._account
	if self._update_handler_mode == true then
		error("[Accounts]: Can't listen to new global updates in AccountStore:GlobalUpdateAccountAsync()")
	elseif self._new_active_update_listeners == nil then
		error("[Accounts]: Can't listen to new global updates in view mode")
	elseif account:IsActive() == false then
		return {
			Disconnect = function() end,
		}
	end
	return self._new_active_update_listeners:Connect(listener)
end

function GlobalUpdates:ListenToNewLockedUpdate(listener)
	if type(listener) ~= "function" then
		error("[Accounts]: Only a function can be set as listener in GlobalUpdates:ListenToNewLockedUpdate()")
	end
	local account = self._account
	if self._update_handler_mode == true then
		error("[Accounts]: Can't listen to new global updates in AccountStore:GlobalUpdateAccountAsync()")
	elseif self._new_locked_update_listeners == nil then
		error("[Accounts]: Can't listen to new global updates in view mode")
	elseif account:IsActive() == false then
		return {
			Disconnect = function() end,
		}
	end
	return self._new_locked_update_listeners:Connect(listener)
end

function GlobalUpdates:LockActiveUpdate(update_id)
	if type(update_id) ~= "number" then
		error("[Accounts]: Invalid update_id")
	end
	local account = self._account
	if self._update_handler_mode == true then
		error("[Accounts]: Can't lock active global updates in AccountStore:GlobalUpdateAccountAsync()")
	elseif self._pending_update_lock == nil then
		error("[Accounts]: Can't lock active global updates in view mode")
	elseif account:IsActive() == false then
		error("[Accounts]: ACCOUNT EXPIRED - Can't lock active global updates")
	end
	local global_update_exists = nil
	for _, global_update in ipairs(self._updates_latest[2]) do
		if global_update[1] == update_id then
			global_update_exists = global_update
			break
		end
	end
	if global_update_exists ~= nil then
		local is_pending_lock = false
		for _, lock_update_id in ipairs(self._pending_update_lock) do
			if update_id == lock_update_id then
				is_pending_lock = true
				break
			end
		end
		if is_pending_lock == false and global_update_exists[3] == false then
			table.insert(self._pending_update_lock, update_id)
		end
	else
		error("[Accounts]: Passed non-existant update_id")
	end
end

function GlobalUpdates:ClearLockedUpdate(update_id)
	if type(update_id) ~= "number" then
		error("[Accounts]: Invalid update_id")
	end
	local account = self._account
	if self._update_handler_mode == true then
		error("[Accounts]: Can't clear locked global updates in AccountStore:GlobalUpdateAccountAsync()")
	elseif self._pending_update_clear == nil then
		error("[Accounts]: Can't clear locked global updates in view mode")
	elseif account:IsActive() == false then
		error("[Accounts]: ACCOUNT EXPIRED - Can't clear locked global updates")
	end

	local global_update_exists = nil
	for _, global_update in ipairs(self._updates_latest[2]) do
		if global_update[1] == update_id then
			global_update_exists = global_update
			break
		end
	end
	if global_update_exists ~= nil then
		local is_pending_clear = false
		for _, clear_update_id in ipairs(self._pending_update_clear) do
			if update_id == clear_update_id then
				is_pending_clear = true
				break
			end
		end
		if is_pending_clear == false and global_update_exists[3] == true then
			table.insert(self._pending_update_clear, update_id)
		end
	else
		error("[Accounts]: Passed non-existant update_id")
	end
end

function GlobalUpdates:AddActiveUpdate(update_data)
	if type(update_data) ~= "table" then
		error("[Accounts]: Invalid update_data")
	end
	if self._new_active_update_listeners ~= nil then
		error("[Accounts]: Can't add active global updates in loaded Account; Use AccountStore:GlobalUpdateAccountAsync()")
	elseif self._update_handler_mode ~= true then
		error("[Accounts]: Can't add active global updates in view mode; Use AccountStore:GlobalUpdateAccountAsync()")
	end
	local updates_latest = self._updates_latest
	local update_index = updates_latest[1] + 1
	updates_latest[1] = update_index
	table.insert(updates_latest[2], {update_index, 1, false, update_data})
end

function GlobalUpdates:ChangeActiveUpdate(update_id, update_data)
	if type(update_id) ~= "number" then
		error("[Accounts]: Invalid update_id")
	end
	if type(update_data) ~= "table" then
		error("[Accounts]: Invalid update_data")
	end
	if self._new_active_update_listeners ~= nil then
		error("[Accounts]: Can't change active global updates in loaded Account; Use AccountStore:GlobalUpdateAccountAsync()")
	elseif self._update_handler_mode ~= true then
		error("[Accounts]: Can't change active global updates in view mode; Use AccountStore:GlobalUpdateAccountAsync()")
	end

	local updates_latest = self._updates_latest
	local get_global_update = nil
	for _, global_update in ipairs(updates_latest[2]) do
		if update_id == global_update[1] then
			get_global_update = global_update
			break
		end
	end
	if get_global_update ~= nil then
		if get_global_update[3] == true then
			error("[Accounts]: Can't change locked global update")
		end
		get_global_update[2] = get_global_update[2] + 1
		get_global_update[4] = update_data
	else
		error("[Accounts]: Passed non-existant update_id")
	end
end

function GlobalUpdates:ClearActiveUpdate(update_id)
	if type(update_id) ~= "number" then
		error("[Accounts]: Invalid update_id argument")
	end
	if self._new_active_update_listeners ~= nil then
		error("[Accounts]: Can't clear active global updates in loaded Account; Use AccountStore:GlobalUpdateAccountAsync()")
	elseif self._update_handler_mode ~= true then
		error("[Accounts]: Can't clear active global updates in view mode; Use AccountStore:GlobalUpdateAccountAsync()")
	end
	local updates_latest = self._updates_latest
	local get_global_update_index = nil
	local get_global_update = nil
	for index, global_update in ipairs(updates_latest[2]) do
		if update_id == global_update[1] then
			get_global_update_index = index
			get_global_update = global_update
			break
		end
	end
	if get_global_update ~= nil then
		if get_global_update[3] == true then
			error("[Accounts]: Can't clear locked global update")
		end
		table.remove(updates_latest[2], get_global_update_index)
	else
		error("[Accounts]: Passed non-existant update_id")
	end
end

--\\ Account Class //--
local Account = {}
Account.__index = Account

function Account:IsActive()
	local loaded_accounts = self._is_user_mock == true and self._account_store._mock_loaded_accounts or self._account_store._loaded_accounts
	return loaded_accounts[self._account_key] == self
end

function Account:GetMetaTag(tag_name)
	local meta_data = self.MetaData
	if meta_data == nil then
		return nil
	end
	return self.MetaData.MetaTags[tag_name]
end

function Account:SetMetaTag(tag_name, value)
	if type(tag_name) ~= "string" then
		error("[Accounts]: tag_name must be a string")
	elseif string.len(tag_name) == 0 then
		error("[Accounts]: Invalid tag_name")
	end
	self.MetaData.MetaTags[tag_name] = value
end

function Account:Reconcile()
	Util.reconcileTable(self.Data, self._account_store._account_template)
end

function Account:ListenToRelease(listener)
	if type(listener) ~= "function" then
		error("[Accounts]: Only a function can be set as listener in Account:ListenToRelease()")
	end
	if self._view_mode == true then
		return {Disconnect = function() end}
	end
	if self:IsActive() == false then
		local place_id
		local game_job_id
		local active_session = self.MetaData.ActiveSession
		if active_session ~= nil then
			place_id = active_session[1]
			game_job_id = active_session[2]
		end
		listener(place_id, game_job_id)
		return {Disconnect = function() end}
	else
		return self._release_listeners:Connect(listener)
	end
end

function Account:Save()
	if self._view_mode == true then
		error("[Accounts]: Can't save Account in view mode - Should you be calling :OverwriteAsync() instead?")
	end
	if self:IsActive() == false then
		warn("[Accounts]: Attempted saving an inactive account "
			.. self:Identify() .. "; Traceback:\n" .. debug.traceback())
		return
	end
	if IsCustomWriteQueueEmptyFor(self._account_store._account_store_lookup, self._account_key) == true then
		RemoveAccountFromAutoSave(self)
		AddAccountToAutoSave(self)
		task.spawn(SaveAccountAsync, self)
	end
end

function Account:Release()
	if self._view_mode == true then
		return
	end
	if self:IsActive() == true then
		task.spawn(SaveAccountAsync, self, true)
	end
end

function Account:ListenToHopReady(listener)
	if type(listener) ~= "function" then
		error("[Accounts]: Only a function can be set as listener in Account:ListenToHopReady()")
	end
	if self._view_mode == true then
		return {Disconnect = function() end}
	end
	if self._hop_ready == true then
		task.spawn(listener)
		return {Disconnect = function() end}
	else
		return self._hop_ready_listeners:Connect(listener)
	end
end

function Account:AddUserId(user_id)

	if type(user_id) ~= "number" or user_id % 1 ~= 0 then
		warn("[Accounts]: Invalid UserId argument for :AddUserId() ("
			.. tostring(user_id) .. "); Traceback:\n" .. debug.traceback())
		return
	end

	if user_id < 0 and self._is_user_mock ~= true and UseMockDataStore ~= true then
		return
	end

	if table.find(self.UserIds, user_id) == nil then
		table.insert(self.UserIds, user_id)
	end
	
end

function Account:RemoveUserId(user_id)

	if type(user_id) ~= "number" or user_id % 1 ~= 0 then
		warn("[Accounts]: Invalid UserId argument for :RemoveUserId() ("
			.. tostring(user_id) .. "); Traceback:\n" .. debug.traceback())
		return
	end
	
	local index = table.find(self.UserIds, user_id)

	if index ~= nil then
		table.remove(self.UserIds, index)
	end

end

function Account:Identify()
	return IdentifyAccount(
		self._account_store._account_store_name,
		self._account_store._account_store_scope,
		self._account_key
	)
end

function Account:ClearGlobalUpdates()

	if self._view_mode ~= true then
		error("[Accounts]: :ClearGlobalUpdates() can only be used in view mode")
	end

	local global_updates_object = {
		_updates_latest = {0, {}},
		_account = self,
	}
	setmetatable(global_updates_object, GlobalUpdates)

	self.GlobalUpdates = global_updates_object

end

function Account:OverwriteAsync()

	if self._view_mode ~= true then
		error("[Accounts]: :OverwriteAsync() can only be used in view mode")
	end

	SaveAccountAsync(self, nil, true)

end

--\\ AccountVersionQuery Class //--
local AccountVersionQuery = {}
AccountVersionQuery.__index = AccountVersionQuery

function AccountVersionQuery:_MoveQueue()
	while #self._query_queue > 0 do
		local queue_entry = table.remove(self._query_queue, 1)
		task.spawn(queue_entry)
		if self._is_query_yielded == true then
			break
		end
	end
end

function AccountVersionQuery:NextAsync(_is_stacking)

	if self._account_store == nil then
		return nil
	end

	local account
	local is_finished = false

	local function query_job()

		if self._query_failure == true then
			is_finished = true
			return
		end

		if self._query_pages == nil then

			self._is_query_yielded = true
			task.spawn(function()
				account = self:NextAsync(true)
				is_finished = true
			end)
			
			local list_success, error_message = pcall(function()
				self._query_pages = self._account_store._global_data_store:ListVersionsAsync(
					self._account_key,
					self._sort_direction,
					self._min_date,
					self._max_date
				)
				self._query_index = 0
			end)

			if list_success == false or self._query_pages == nil then
				warn("[Accounts]: Version query fail - " .. tostring(error_message))
				self._query_failure = true
			end

			self._is_query_yielded = false
			self:_MoveQueue()

			return

		end

		local current_page = self._query_pages:GetCurrentPage()
		local next_item = current_page[self._query_index + 1]
		
		if self._query_pages.IsFinished == true and next_item == nil then
			is_finished = true
			return
		end

		if next_item == nil then

			self._is_query_yielded = true
			task.spawn(function()
				account = self:NextAsync(true)
				is_finished = true
			end)

			local success = pcall(function()
				self._query_pages:AdvanceToNextPageAsync()
				self._query_index = 0
			end)

			if success == false or #self._query_pages:GetCurrentPage() == 0 then
				self._query_failure = true
			end

			self._is_query_yielded = false
			self:_MoveQueue()

			return

		end

		self._query_index += 1
		account = self._account_store:ViewAccountAsync(self._account_key, next_item.Version)
		is_finished = true

	end

	if self._is_query_yielded == false then
		query_job()
	else
		if _is_stacking == true then
			table.insert(self._query_queue, 1, query_job)
		else
			table.insert(self._query_queue, query_job)
		end
	end

	while is_finished == false do
		task.wait()
	end

	return account

end

--\\ AccountStore Class //--
local AccountStore = {}
AccountStore.__index = AccountStore

function AccountStore:LoadAccountAsync(account_key, not_released_handler, _use_mock)

	not_released_handler = not_released_handler or "ForceLoad"

	if self._account_template == nil then
		error("[Accounts]: Account template not set - AccountStore:LoadAccountAsync() locked for this AccountStore")
	end
	if type(account_key) ~= "string" then
		error("[Accounts]: account_key must be a string")
	elseif string.len(account_key) == 0 then
		error("[Accounts]: Invalid account_key")
	end
	if type(not_released_handler) ~= "function" and not_released_handler ~= "ForceLoad" and not_released_handler ~= "Steal" then
		error("[Accounts]: Invalid not_released_handler")
	end

	if Accounts.ServiceLocked == true then
		return nil
	end

	WaitForPendingAccountStore(self)

	local is_user_mock = _use_mock == UseMockTag

	for _, account_store in ipairs(ActiveAccountStores) do
		if account_store._account_store_lookup == self._account_store_lookup then
			local loaded_accounts = is_user_mock == true and account_store._mock_loaded_accounts or account_store._loaded_accounts
			if loaded_accounts[account_key] ~= nil then
				error("[Accounts]: Account " .. IdentifyAccount(self._account_store_name, self._account_store_scope, account_key) .. " is already loaded in this session")
			end
		end
	end

	ActiveAccountLoadJobs = ActiveAccountLoadJobs + 1
	local force_load = not_released_handler == "ForceLoad"
	local force_load_steps = 0
	local request_force_load = force_load
	local steal_session = false
	local aggressive_steal = not_released_handler == "Steal"
	while Accounts.ServiceLocked == false do
		local account_load_jobs = is_user_mock == true and self._mock_account_load_jobs or self._account_load_jobs
		local loaded_data, key_info
		local load_id = LoadIndex + 1
		LoadIndex = load_id
		local account_load_job = account_load_jobs[account_key]
		if account_load_job ~= nil then
			account_load_job[1] = load_id
			while account_load_job[2] == nil do
				task.wait()
			end
			if account_load_job[1] == load_id then
				loaded_data, key_info = table.unpack(account_load_job[2])
				account_load_jobs[account_key] = nil
			else
				ActiveAccountLoadJobs = ActiveAccountLoadJobs - 1
				return nil
			end
		else
			account_load_job = {load_id, nil}
			account_load_jobs[account_key] = account_load_job
			account_load_job[2] = table.pack(StandardAccountUpdateAsyncDataStore(
				self,
				account_key,
				{
					ExistingAccountHandle = function(latest_data)
						if Accounts.ServiceLocked == false then
							local active_session = latest_data.MetaData.ActiveSession
							local force_load_session = latest_data.MetaData.ForceLoadSession

							if active_session == nil then
								latest_data.MetaData.ActiveSession = {PlaceId, JobId}
								latest_data.MetaData.ForceLoadSession = nil
							elseif type(active_session) == "table" then
								if IsThisSession(active_session) == false then
									local last_update = latest_data.MetaData.LastUpdate
									if last_update ~= nil then
										if os.time() - last_update > AccountSettings.AssumeDeadSessionLock then
											latest_data.MetaData.ActiveSession = {PlaceId, JobId}
											latest_data.MetaData.ForceLoadSession = nil
											return
										end
									end
									if steal_session == true or aggressive_steal == true then
										local force_load_uninterrupted = false
										if force_load_session ~= nil then
											force_load_uninterrupted = IsThisSession(force_load_session)
										end
										if force_load_uninterrupted == true or aggressive_steal == true then
											latest_data.MetaData.ActiveSession = {PlaceId, JobId}
											latest_data.MetaData.ForceLoadSession = nil
										end
									elseif request_force_load == true then
										latest_data.MetaData.ForceLoadSession = {PlaceId, JobId}
									end
								else
									latest_data.MetaData.ForceLoadSession = nil
								end
							end
						end
					end,
					MissingAccountHandle = function(latest_data)
						latest_data.Data = Util._deepCopy(self._account_template)
						latest_data.MetaData = {
							AccountCreateTime = os.time(),
							SessionLoadCount = 0,
							ActiveSession = {PlaceId, JobId},
							ForceLoadSession = nil,
							MetaTags = {},
						}
					end,
					EditAccount = function(latest_data)
						if Accounts.ServiceLocked == false then
							local active_session = latest_data.MetaData.ActiveSession
							if active_session ~= nil and IsThisSession(active_session) == true then
								latest_data.MetaData.SessionLoadCount = latest_data.MetaData.SessionLoadCount + 1
								latest_data.MetaData.LastUpdate = os.time()
							end
						end
					end,
				},
				is_user_mock
			))
			if account_load_job[1] == load_id then
				loaded_data, key_info = table.unpack(account_load_job[2])
				account_load_jobs[account_key] = nil
			else
				ActiveAccountLoadJobs = ActiveAccountLoadJobs - 1
				return nil
			end
		end

		if loaded_data ~= nil and key_info ~= nil then
			local active_session = loaded_data.MetaData.ActiveSession
			if type(active_session) == "table" then
				if IsThisSession(active_session) == true then
					loaded_data.MetaData.MetaTagsLatest = Util._deepCopy(loaded_data.MetaData.MetaTags)
					local global_updates_object = {
						_updates_latest = loaded_data.GlobalUpdates,
						_pending_update_lock = {},
						_pending_update_clear = {},

						_new_active_update_listeners = AccountConnection.NewScriptSignal(),
						_new_locked_update_listeners = AccountConnection.NewScriptSignal(),

						_account = nil,
					}
					setmetatable(global_updates_object, GlobalUpdates)
					local account = {
						Data = loaded_data.Data,
						MetaData = loaded_data.MetaData,
						MetaTagsUpdated = AccountConnection.NewScriptSignal(),

						RobloxMetaData = loaded_data.RobloxMetaData or {},
						UserIds = loaded_data.UserIds or {},
						KeyInfo = key_info,
						KeyInfoUpdated = AccountConnection.NewScriptSignal(),

						GlobalUpdates = global_updates_object,

						_account_store = self,
						_account_key = account_key,

						_release_listeners = AccountConnection.NewScriptSignal(),
						_hop_ready_listeners = AccountConnection.NewScriptSignal(),
						_hop_ready = false,

						_load_timestamp = os.clock(),

						_is_user_mock = is_user_mock,
					}
					setmetatable(account, Account)
					global_updates_object._account = account
					if next(self._loaded_accounts) == nil and next(self._mock_loaded_accounts) == nil then
						table.insert(ActiveAccountStores, self)
					end
					if is_user_mock == true then
						self._mock_loaded_accounts[account_key] = account
					else
						self._loaded_accounts[account_key] = account
					end
					AddAccountToAutoSave(account)
					if Accounts.ServiceLocked == true then
						SaveAccountAsync(account, true)
						account = nil
					end
					ActiveAccountLoadJobs = ActiveAccountLoadJobs - 1
					return account
				else
					if force_load == true then
						local force_load_session = loaded_data.MetaData.ForceLoadSession
						local force_load_uninterrupted = false
						if force_load_session ~= nil then
							force_load_uninterrupted = IsThisSession(force_load_session)
						end
						if force_load_uninterrupted == true then
							if request_force_load == false then
								force_load_steps = force_load_steps + 1
								if force_load_steps == AccountSettings.ForceLoadMaxSteps then
									steal_session = true
								end
							end
							task.wait()
						else
							ActiveAccountLoadJobs = ActiveAccountLoadJobs - 1
							return nil
						end
						request_force_load = false
					elseif aggressive_steal == true then
						task.wait()
					else
						local handler_result = not_released_handler(active_session[1], active_session[2])
						if handler_result == "Repeat" then
							task.wait()
						elseif handler_result == "Cancel" then
							ActiveAccountLoadJobs = ActiveAccountLoadJobs - 1
							return nil
						elseif handler_result == "ForceLoad" then
							force_load = true
							request_force_load = true
							task.wait()
						elseif handler_result == "Steal" then
							aggressive_steal = true
							task.wait()
						else
							error(
								"[Accounts]: Invalid return from not_released_handler (\"" .. tostring(handler_result) .. "\")(" .. type(handler_result) .. ");" ..
									"\n" .. IdentifyAccount(self._account_store_name, self._account_store_scope, account_key) ..
									" Traceback:\n" .. debug.traceback()
							)
						end
					end
				end
			else
				ActiveAccountLoadJobs = ActiveAccountLoadJobs - 1
				return nil
			end
		else
			task.wait()
		end
	end
	ActiveAccountLoadJobs = ActiveAccountLoadJobs - 1
	return nil
end

function AccountStore:GlobalUpdateAccountAsync(account_key, update_handler, _use_mock)
	if type(account_key) ~= "string" or string.len(account_key) == 0 then
		error("[Accounts]: Invalid account_key")
	end
	if type(update_handler) ~= "function" then
		error("[Accounts]: Invalid update_handler")
	end

	if Accounts.ServiceLocked == true then
		return nil
	end

	WaitForPendingAccountStore(self)

	while Accounts.ServiceLocked == false do
		local loaded_data = StandardAccountUpdateAsyncDataStore(
			self,
			account_key,
			{
				ExistingAccountHandle = nil,
				MissingAccountHandle = nil,
				EditAccount = function(latest_data)
					local global_updates_object = {
						_updates_latest = latest_data.GlobalUpdates,
						_update_handler_mode = true,
					}
					setmetatable(global_updates_object, GlobalUpdates)
					update_handler(global_updates_object)
				end,
			},
			_use_mock == UseMockTag
		)
		CustomWriteQueueMarkForCleanup(self._account_store_lookup, account_key)
		if loaded_data ~= nil then
			local global_updates_object = {
				_updates_latest = loaded_data.GlobalUpdates,
			}
			setmetatable(global_updates_object, GlobalUpdates)
			return global_updates_object
		else
			task.wait()
		end
	end
	return nil
end

function AccountStore:ViewAccountAsync(account_key, version, _use_mock)
	if type(account_key) ~= "string" or string.len(account_key) == 0 then
		error("[Accounts]: Invalid account_key")
	end

	if Accounts.ServiceLocked == true then
		return nil
	end

	WaitForPendingAccountStore(self)

	if version ~= nil and (_use_mock == UseMockTag or UseMockDataStore == true) then
		return nil
	end

	while Accounts.ServiceLocked == false do
		local loaded_data, key_info = StandardAccountUpdateAsyncDataStore(
			self,
			account_key,
			{
				ExistingAccountHandle = nil,
				MissingAccountHandle = function(latest_data)
					latest_data.Data = Util._deepCopy(self._account_template)
					latest_data.MetaData = {
						AccountCreateTime = os.time(),
						SessionLoadCount = 0,
						ActiveSession = nil,
						ForceLoadSession = nil,
						MetaTags = {},
					}
				end,
				EditAccount = nil,
			},
			_use_mock == UseMockTag,
			true,
			version
		)
		CustomWriteQueueMarkForCleanup(self._account_store_lookup, account_key)
		if loaded_data ~= nil then
			if key_info == nil then
				return nil
			end
			local global_updates_object = {
				_updates_latest = loaded_data.GlobalUpdates,
				_account = nil,
			}
			setmetatable(global_updates_object, GlobalUpdates)
			local account = {
				Data = loaded_data.Data,
				MetaData = loaded_data.MetaData,
				MetaTagsUpdated = AccountConnection.NewScriptSignal(),

				RobloxMetaData = loaded_data.RobloxMetaData or {},
				UserIds = loaded_data.UserIds or {},
				KeyInfo = key_info,
				KeyInfoUpdated = AccountConnection.NewScriptSignal(),

				GlobalUpdates = global_updates_object,

				_account_store = self,
				_account_key = account_key,

				_view_mode = true,

				_load_timestamp = os.clock(),
			}
			setmetatable(account, Account)
			global_updates_object._account = account
			return account
		else
			task.wait()
		end
	end
	return nil
end

function AccountStore:AccountVersionQuery(account_key, sort_direction, min_date, max_date, _use_mock)
	if type(account_key) ~= "string" or string.len(account_key) == 0 then
		error("[Accounts]: Invalid account_key")
	end

	if Accounts.ServiceLocked == true then
		return setmetatable({}, AccountVersionQuery)
	end

	WaitForPendingAccountStore(self)

	if _use_mock == UseMockTag or UseMockDataStore == true then
		error("[Accounts]: :AccountVersionQuery() is not supported in mock mode")
	end

	if sort_direction ~= nil and (typeof(sort_direction) ~= "EnumItem"
		or sort_direction.EnumType ~= Enum.SortDirection) then
		error("[Accounts]: Invalid sort_direction (" .. tostring(sort_direction) .. ")")
	end

	if min_date ~= nil and typeof(min_date) ~= "DateTime" and typeof(min_date) ~= "number" then
		error("[Accounts]: Invalid min_date (" .. tostring(min_date) .. ")")
	end

	if max_date ~= nil and typeof(max_date) ~= "DateTime" and typeof(max_date) ~= "number" then
		error("[Accounts]: Invalid max_date (" .. tostring(max_date) .. ")")
	end

	min_date = typeof(min_date) == "DateTime" and min_date.UnixTimestampMillis or min_date
	max_date = typeof(max_date) == "DateTime" and max_date.UnixTimestampMillis or max_date

	local account_version_query = {
		_account_store = self,
		_account_key = account_key,
		_sort_direction = sort_direction,
		_min_date = min_date,
		_max_date = max_date,

		_query_pages = nil,
		_query_index = 0,
		_query_failure = false,

		_is_query_yielded = false,
		_query_queue = {},
	}
	setmetatable(account_version_query, AccountVersionQuery)

	return account_version_query

end

function AccountStore:WipeAccountAsync(account_key, _use_mock)
	if type(account_key) ~= "string" or string.len(account_key) == 0 then
		error("[Accounts]: Invalid account_key")
	end

	if Accounts.ServiceLocked == true then
		return false
	end

	WaitForPendingAccountStore(self)

	local wipe_status = false

	if _use_mock == UseMockTag then
		local mock_data_store = UserMockDataStore[self._account_store_lookup]
		if mock_data_store ~= nil then
			mock_data_store[account_key] = nil
		end
		wipe_status = true
		task.wait()
	elseif UseMockDataStore == true then
		local mock_data_store = MockDataStore[self._account_store_lookup]
		if mock_data_store ~= nil then
			mock_data_store[account_key] = nil
		end
		wipe_status = true
		task.wait()
	else
		wipe_status = pcall(function()
			self._global_data_store:RemoveAsync(account_key)
		end)
	end

	CustomWriteQueueMarkForCleanup(self._account_store_lookup, account_key)

	return wipe_status
end

function Accounts.GetAccountStore(account_store_index, account_template)

	local account_store_name
	local account_store_scope = nil

	if type(account_store_index) == "string" then
		account_store_name = account_store_index
	elseif type(account_store_index) == "table" then
		account_store_name = account_store_index.Name
		account_store_scope = account_store_index.Scope
	else
		error("[Accounts]: Invalid or missing account_store_index")
	end

	if account_store_name == nil or type(account_store_name) ~= "string" then
		error("[Accounts]: Missing or invalid \"Name\" parameter")
	elseif string.len(account_store_name) == 0 then
		error("[Accounts]: AccountStore name cannot be an empty string")
	end

	if account_store_scope ~= nil and (type(account_store_scope) ~= "string" or string.len(account_store_scope) == 0) then
		error("[Accounts]: Invalid \"Scope\" parameter")
	end

	if type(account_template) ~= "table" then
		error("[Accounts]: Invalid account_template")
	end

	local account_store
	account_store = {
		Mock = {
			LoadAccountAsync = function(_, account_key, not_released_handler)
				return account_store:LoadAccountAsync(account_key, not_released_handler, UseMockTag)
			end,
			GlobalUpdateAccountAsync = function(_, account_key, update_handler)
				return account_store:GlobalUpdateAccountAsync(account_key, update_handler, UseMockTag)
			end,
			ViewAccountAsync = function(_, account_key, version)
				return account_store:ViewAccountAsync(account_key, version, UseMockTag)
			end,
			FindAccountVersionAsync = function(_, account_key, sort_direction, min_date, max_date)
				return account_store:FindAccountVersionAsync(account_key, sort_direction, min_date, max_date, UseMockTag)
			end,
			WipeAccountAsync = function(_, account_key)
				return account_store:WipeAccountAsync(account_key, UseMockTag)
			end
		},

		_account_store_name = account_store_name,
		_account_store_scope = account_store_scope,
		_account_store_lookup = account_store_name .. "\0" .. (account_store_scope or ""),

		_account_template = account_template,
		_global_data_store = nil,
		_loaded_accounts = {},
		_account_load_jobs = {},
		_mock_loaded_accounts = {},
		_mock_account_load_jobs = {},
		_is_pending = false,
	}
	setmetatable(account_store, AccountStore)

	if IsLiveCheckActive == true then
		account_store._is_pending = true
		task.spawn(function()
			WaitForLiveAccessCheck()
			if UseMockDataStore == false then
				account_store._global_data_store = DataStoreService:GetDataStore(account_store_name, account_store_scope)
			end
			account_store._is_pending = false
		end)
	else
		if UseMockDataStore == false then
			account_store._global_data_store = DataStoreService:GetDataStore(account_store_name, account_store_scope)
		end
	end

	return account_store
end

function Accounts.IsLive()

	WaitForLiveAccessCheck()

	return UseMockDataStore == false

end

if IsStudio == true then
	IsLiveCheckActive = true
	task.spawn(function()
		local status, message = pcall(function()
			DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())
		end)
		local no_internet_access = status == false and string.find(message, "ConnectFail", 1, true) ~= nil
		if no_internet_access == true then
			warn("[Accounts]: No internet access - check your network connection")
		end
		if status == false and
			(string.find(message, "403", 1, true) ~= nil or
				string.find(message, "must publish", 1, true) ~= nil or
				no_internet_access == true) then

			UseMockDataStore = true
			Accounts._use_mock_data_store = true
			print("[Accounts]: Roblox API services unavailable - data will not be saved")
		else
			print("[Accounts]: Roblox API services available - data will be saved")
		end
		IsLiveCheckActive = false
	end)
end

RunService.Heartbeat:Connect(function()
	local auto_save_list_length = #AutoSaveList
	if auto_save_list_length > 0 then
		local auto_save_index_speed = AccountSettings.AutoSaveAccounts / auto_save_list_length
		local os_clock = os.clock()
		while os_clock - LastAutoSave > auto_save_index_speed do
			LastAutoSave = LastAutoSave + auto_save_index_speed
			local account = AutoSaveList[AutoSaveIndex]
			if os_clock - account._load_timestamp < AccountSettings.AutoSaveAccounts then
				account = nil
				for _ = 1, auto_save_list_length - 1 do
					AutoSaveIndex = AutoSaveIndex + 1
					if AutoSaveIndex > auto_save_list_length then
						AutoSaveIndex = 1
					end
					account = AutoSaveList[AutoSaveIndex]
					if os_clock - account._load_timestamp >= AccountSettings.AutoSaveAccounts then
						break
					else
						account = nil
					end
				end
			end
			AutoSaveIndex = AutoSaveIndex + 1
			if AutoSaveIndex > auto_save_list_length then
				AutoSaveIndex = 1
			end
			if account ~= nil then
				task.spawn(SaveAccountAsync, account)
			end
		end
	end
	if Accounts.CriticalState == false then
		if #IssueQueue >= AccountSettings.IssueCountForCriticalState then
			Accounts.CriticalState = true
			Accounts.CriticalStateSignal:Fire(true)
			CriticalStateStart = os.clock()
			warn("[Accounts]: Entered critical state")
		end
	else
		if #IssueQueue >= AccountSettings.IssueCountForCriticalState then
			CriticalStateStart = os.clock()
		elseif os.clock() - CriticalStateStart > AccountSettings.CriticalStateLast then
			Accounts.CriticalState = false
			Accounts.CriticalStateSignal:Fire(false)
			warn("[Accounts]: Critical state ended")
		end
	end
	while true do
		local issue_time = IssueQueue[1]
		if issue_time == nil then
			break
		elseif os.clock() - issue_time > AccountSettings.IssueLast then
			table.remove(IssueQueue, 1)
		else
			break
		end
	end
end)

task.spawn(function()
	WaitForLiveAccessCheck()
	AccountConnection.ConnectToOnClose(
		function()
			Accounts.ServiceLocked = true
			local on_close_save_job_count = 0
			local active_accounts = {}
			for index, account in ipairs(AutoSaveList) do
				active_accounts[index] = account
			end
			for _, account in ipairs(active_accounts) do
				if account:IsActive() == true then
					on_close_save_job_count = on_close_save_job_count + 1
					task.spawn(function()
						SaveAccountAsync(account, true)
						on_close_save_job_count = on_close_save_job_count - 1
					end)
				end
			end
			while on_close_save_job_count > 0 or ActiveAccountLoadJobs > 0 or ActiveAccountSaveJobs > 0 do
				task.wait()
			end
			return
		end,
		UseMockDataStore == false
	)
end)

return Accounts