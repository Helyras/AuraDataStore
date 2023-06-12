local module_version = 1

--// Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	error("AuraDataStore must ran on server.")
end

--// Modules
local Promise = require(script:WaitForChild("Promise"))
local Signal = require(script:WaitForChild("Signal"))

local AuraDataStore = {
	--// Settings
	SaveInStudio = false,
	BindToCloseEnabled = true,
	RetryCount = 5,
	SessionLockTime = 1800,
	--// Events
	DataStatus = Signal.new(),
}

--// Variables
local s_format = string.format

local Stores = {}

local DataStore = {}
DataStore.__index = DataStore

--// Local Functions
local function CheckVersion(_retries)
	if not _retries then
		_retries = 1
	end
	
	local HttpService = game:GetService("HttpService")
	local success, response = pcall(HttpService.GetAsync, HttpService, "https://raw.githubusercontent.com/Zepherria/AuraDataStore/master/version.json")
	if success then
		response = HttpService:JSONDecode(response)
		for i, v in pairs(response) do
			if tonumber(i) > module_version then
				warn(s_format("You are currently using"))
			end
		end
	else
		if _retries > 2 then
			warn(s_format("Http request has failed while checking version. Reason: %s", response))
			return
		else
			CheckVersion(_retries + 1)
		end
	end
end

CheckVersion()

local function CheckTableEquality(t1, t2)
	if type(t1) == "table" and type(t2) == "table" then
		local function subset(a, b)
			for key, value in pairs(a) do
				if typeof(value) == "table" then
					if not CheckTableEquality(b[key], value) then
						return false
					end
				else
					if b[key] ~= value then
						return false
					end
				end
			end
			return true
		end
		return subset(t1, t2) and subset(t2, t1)
	end
end

local function deepCopy(original)
	if type(original) == "table" then
		local copy = {}
		for k, v in pairs(original) do
			if type(v) == "table" then
				v = deepCopy(v)
			end
			copy[k] = v
		end
		return copy
	end
end

local function Reconcile(tbl, template)
	if type(tbl) == "table" and type(template) == "table" then
		for k, v in pairs(template) do
			if type(k) == "string" then
				if tbl[k] == nil then
					if type(v) == "table" then
						tbl[k] = deepCopy(v)
					else
						tbl[k] = v
					end
				elseif type(tbl[k]) == "table" and type(v) == "table" then
					Reconcile(tbl[k], v)
				end
			end
		end
	end
end

--// Data Store Functions
AuraDataStore.CreateStore = function(name, template)
	local store = setmetatable({
		_store = DataStoreService:GetDataStore(name),
		_template = deepCopy(template),
		_database = {},
		_cache = {},
		_name = name
	}, DataStore)
	table.insert(Stores, store)
	return store
end

function DataStore:Reconcile(key)
	if self._database[key] then
		Reconcile(self._database[key], self._template)
	end
end

function DataStore:FindDatabyKey(key)
	return self._database[key]
end

function DataStore:GetAsync(key, _retries)

	if self._database[key] then
		return self._database[key]
	end

	if not _retries then
		_retries = 0
	end

	local success, response, keyInfo = pcall(self._store.GetAsync, self._store, key)
	if success then
		if response then
			if keyInfo:GetMetadata().SessionLock then
				local secondsPassed = os.time() - keyInfo:GetMetadata().SessionLock
				if secondsPassed < AuraDataStore.SessionLockTime then
					AuraDataStore.DataStatus:Fire(s_format("Loading data failed for key: '%s', name: '%s', after %s retries. Reason: Data is session locked, try again in %d seconds. (%s~ minutes)", key, self._name, _retries + 1, AuraDataStore.SessionLockTime - secondsPassed, math.floor((AuraDataStore.SessionLockTime - secondsPassed)/60)), key, self._name, nil, _retries + 1, AuraDataStore.SessionLockTime - secondsPassed)
					return nil, s_format("Data is session locked, try again in %d seconds. (%s~ minutes)", AuraDataStore.SessionLockTime - secondsPassed, math.floor((AuraDataStore.SessionLockTime - secondsPassed)/60))
				end
			end
			self._database[key] = response
			self._cache[key] = deepCopy(response)
		else
			self._database[key] = deepCopy(self._template)
			self._cache[key] = deepCopy(self._template)
		end

		AuraDataStore.DataStatus:Fire(s_format("Loading data succeed for key: '%s', name: '%s', after %s retries.", key, self._name, _retries + 1), key, self._name, nil, _retries + 1)
		self:Save(key, nil, nil, true)
		return self._database[key]
	else
		_retries += 1
		if _retries < AuraDataStore.RetryCount then
			AuraDataStore.DataStatus:Fire(s_format("Loading data failed for key: '%s', name: '%s', retrying. Retries: %s", key, self._name, _retries), key, self._name, nil, _retries)
			return self:GetAsync(key, _retries)
		else
			AuraDataStore.DataStatus:Fire(s_format("Loading data failed for key: '%s', name: '%s' after %s retries. Reason:\n%s", key, self._name, _retries, response), key, self._name, response, _retries)
			self._database[key] = deepCopy(self._template)
			self._cache[key] = deepCopy(self._template)
			self._database[key]["DontSave"] = response
			self._cache[key]["DontSave"] = response
			return self._database[key]
		end
	end
end

function DataStore:Save(key, tblofIDs, isLeaving, forceSave)

	if not AuraDataStore.SaveInStudio and RunService:IsStudio() then
		if not forceSave then
			warn(s_format("Did not saved data for key: '%s', name: '%s'. Reason: SaveInStudio is not enabled.", key, self._name))
		end
		return
	end

	if not self._database[key] then
		AuraDataStore.DataStatus:Fire(s_format("Saving data failed for key: '%s', name: '%s'. Reason: Data was session locked and did not loaded.", key, self._name), key, self._name)
		return
	end

	if self._database[key]["DontSave"] then
		if not forceSave then
			warn(s_format("Saving data failed for key: '%s', name: '%s'. Reason:\n%s", key, self._name, self._database[key]["DontSave"]))
		end
		return
	end

	if not forceSave and not isLeaving then
		if CheckTableEquality(self._database[key], self._cache[key]) then
			AuraDataStore.DataStatus:Fire(s_format("Data is not saved for key: '%s', name: '%s'. Reason: Data is identical.", key, self._name), key, self._name)
			return
		end
	end

	if not tblofIDs and not forceSave then
		tblofIDs = {}
		warn(s_format("Table of UserIds is not provided for key: '%s', name: '%s'. For GDPR compliance please refer to documentation.", key, self._name))
	end

	Promise.new(function(resolve, reject)

		local setOptions = Instance.new("DataStoreSetOptions")
		if not isLeaving then
			setOptions:SetMetadata({["SessionLock"] = os.time()})
		else
			setOptions:SetMetadata({})
		end

		local success, response = pcall(self._store.SetAsync, self._store, key, self._database[key], tblofIDs, setOptions)
		if success then
			resolve(response)
		else
			reject(response)
			AuraDataStore.DataStatus:Fire(s_format("Saving data failed for key: '%s', name: '%s'. Reason:\n%s", key, self._name, response), key, self._name, response)
			self:Save(key, tblofIDs)
		end
	end)
	:andThen(function()
		if not forceSave or (isLeaving and forceSave) then
			AuraDataStore.DataStatus:Fire(s_format("Saving data succeed for key: '%s', name: '%s'.", key, self._name), key, self._name)
		end
		if isLeaving then
			self._database[key] = nil
			self._cache[key] = nil
		else
			self._cache[key] = deepCopy(self._database[key])
		end
	end)
end

local function BindToClose()
	if AuraDataStore.BindToCloseEnabled and not RunService:IsStudio() then
		for _, self in pairs(Stores) do
			for i, _ in pairs(self._database) do
				self:Save(i, nil, true)
			end
		end
		task.wait(20)
	end
end

game:BindToClose(BindToClose)
return AuraDataStore
