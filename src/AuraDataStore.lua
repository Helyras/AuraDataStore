--// Version
local module_version = 5

--// Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

if not RunService:IsServer() then
  error("AuraDataStore must ran on server.")
end

--// Modules
local Promise = require(script:WaitForChild("Promise"))
local Signal = require(script:WaitForChild("Signal"))

--// Variables
local s_format = string.format

local Stores = {}

local DataStore = {}
DataStore.__index = DataStore

--// Types
export type AuraStore = typeof(setmetatable({}, DataStore))
export type Module = {
	--[[ Configuration ]]--
	SaveInStudio: boolean,
	BindToCloseEnabled: boolean,
	RetryCount: number,
	SessionLockTime: number,
	CheckForUpdate: boolean,
	--[[ --- ]]--
	CancelSaveIfSaved: boolean,
	CancelSaveIfSavedInterval: number,
	--[[ Session Lock ]]--
	MaxRetriesIfSessionLocked: number,
	YieldTimeIfSessionLocked: number,
	--[[ Signals ]]--
	DataStatus: typeof(Signal.new()),
} & {
	CreateStore: (name: string, template: {}) -> AuraStore,
}

--	Wipe: (self: AuraStore, key: string) -> boolean,
--	Reconcile: (self: AuraStore, key: string) -> nil,
--	FindDatabyKey: (self: AuraStore, key: string) -> {}?,
--	GetLatestAction: (self: AuraStore, key: string) -> {}?,
--  GetAsync: (self: AuraStore, key: string) -> {}?,
--	Save: (self: AuraStore, key: string, tblofIDs: {}?) -> nil,
--	ForceSave: (self: AuraStore, key: string, tblofIDs: {}?) -> nil,
--	SaveOnLeave: (self: AuraStore, key: string, tblofIDs: {}?) -> nil

--// DeepCopy
local function deepCopy(original: {}): {}
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

--// AuraDataStore
local AuraDataStore: Module = {
  --[[ Configuration ]]--
  SaveInStudio = false,
  BindToCloseEnabled = true,
  RetryCount = 5,
  SessionLockTime = 1800,
  CheckForUpdate = true,
  --[[ --- ]]--
  CancelSaveIfSaved = true,
  CancelSaveIfSavedInterval = 60,
  --[[ About Session Lock ]]--
  MaxRetriesIfSessionLocked = 3,
  YieldTimeIfSessionLocked = 5,
  --[[ Signals ]]--
	DataStatus = Signal.new(),
	--// Main Function
	CreateStore = function(name: string, template: {}): AuraStore
		local self = setmetatable({}, DataStore)
		Stores[self] = {
			_store = DataStoreService:GetDataStore(name),
			_template = deepCopy(template),
			_database = {},
			_cache = {},
			_lastAction = {},
			_name = name
		}
		return self
	end,
}

--// Local Functions
local function CheckVersion(_retries: number)
  Promise.new(function(resolve, reject)
		_retries += 1
    local HttpService = game:GetService("HttpService")
    local success, response = pcall(HttpService.GetAsync, HttpService, "https://raw.githubusercontent.com/Helyras/AuraDataStore/master/version.json")
    if success then
      response = HttpService:JSONDecode(response)
      local highest_version
      for i, _ in pairs(response) do
        i = tonumber(i)
        if highest_version then
          if i > highest_version then
            highest_version = i
          end
        else
          highest_version = i
        end
      end
      if highest_version > module_version then
        resolve(s_format("You are currently using version '%s', there is a new '%s' version with changelog below.\nhttps://github.com/Zepherria/AuraDataStore/blob/master/changelogs/changelog-v%s.md", response[tostring(module_version)], response[tostring(highest_version)], response[tostring(highest_version)]))
      end
    else
      if _retries > 2 then
        reject(s_format("Http request has failed while checking version. Reason: %s", response))
        return
      else
        CheckVersion(_retries + 1)
      end
    end
  end)
  :andThen(function(response)
    warn(response)
  end)
end

local function CheckTableEquality(t1: {}, t2: {})
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

local function Reconcile(tbl: {}, template: {})
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

local function updateLastAction(main_tbl: {}, key: string, response: string, status: string, ok: boolean, time: number)
  if not main_tbl[key] then
    main_tbl[key] = {}
  end
  main_tbl[key].response = response
  main_tbl[key].status = status
  main_tbl[key].ok = ok
  main_tbl[key].time = time
end

--// Checking for Updates
if AuraDataStore.CheckForUpdate then
  CheckVersion(0)
end

--// Data Store Functions
local function Save(self: AuraStore, key: string, tblofIDs: {}?, isLeaving: boolean, forceSave: boolean, _isAutoSave: boolean)

  if not AuraDataStore.SaveInStudio and RunService:IsStudio() then
    if not forceSave then
      warn(s_format("Did not saved data for key: '%s', name: '%s'. Reason: SaveInStudio is not enabled.", key, Stores[self]._name))
    end
    return
  end

  if AuraDataStore.CancelSaveIfSaved and not isLeaving and not forceSave then
    local lastAction = Stores[self]._lastAction[key]
    if lastAction and lastAction.status == "SaveSuccess" or lastAction.status == "AutoSaveSuccess" then
      local secondsPassed = os.time() - lastAction.time
      if secondsPassed < AuraDataStore.CancelSaveIfSavedInterval then
        warn(s_format("Did not saved data for key: '%s', name: '%s'. Reason: Data will be eligible to be saved in %d seconds.", key, Stores[self]._name, AuraDataStore.CancelSaveIfSavedInterval - secondsPassed))
        return
      end
    end
  end

  if not Stores[self]._database[key] then
    AuraDataStore.DataStatus:Fire(s_format("Saving data failed for key: '%s', name: '%s'. Reason: Data does not exist.", key, Stores[self]._name), key, Stores[self]._name)
    return
  end

  if Stores[self]._database[key]["DontSave"] then
    warn(s_format("Saving data failed for key: '%s', name: '%s'. Reason:\n%s", key, Stores[self]._name, Stores[self]._database[key]["DontSave"]))
    return
  end

  if not forceSave and not isLeaving then
    if CheckTableEquality(Stores[self]._database[key], Stores[self]._cache[key]) then
      AuraDataStore.DataStatus:Fire(s_format("Data is not saved for key: '%s', name: '%s'. Reason: Data is identical.", key, Stores[self]._name), key, Stores[self]._name)
      return
    end
  end

  if not tblofIDs and not forceSave then
    tblofIDs = {}
    warn(s_format("Table of UserIds is not provided for key: '%s', name: '%s'. For GDPR compliance please refer to documentation.", key, Stores[self]._name))
  end

  Promise.new(function(resolve, reject)

    local setOptions = Instance.new("DataStoreSetOptions")
    if not isLeaving then
      setOptions:SetMetadata({["SessionLock"] = os.time()})
    else
      setOptions:SetMetadata({})
    end

    local success, response = pcall(Stores[self]._store.SetAsync, Stores[self]._store, key, Stores[self]._database[key], tblofIDs, setOptions)
    if success then
      resolve(response)
    else
      reject(response)

      if _isAutoSave then
        updateLastAction(Stores[self]._lastAction, key, "Auto-save has failed.", "AutoSaveFail", false, os.time())
        AuraDataStore.DataStatus:Fire(s_format("Auto-save failed for key: '%s', name: '%s'.", key, Stores[self]._name), key, Stores[self]._name)
      else
        updateLastAction(Stores[self]._lastAction, key, response, "SaveFail", false, os.time())
        AuraDataStore.DataStatus:Fire(s_format("Saving data failed for key: '%s', name: '%s'. Reason:\n%s", key, Stores[self]._name, response), key, Stores[self]._name, response)
      end

      self:Save(key, tblofIDs)
    end
  end)
  :andThen(function()

    if (forceSave and _isAutoSave) or _isAutoSave then
      updateLastAction(Stores[self]._lastAction, key, "Auto-saving data succeed.", "AutoSaveSuccess", true, os.time())
      AuraDataStore.DataStatus:Fire(s_format("Auto-save succeed for key: '%s', name: '%s'.", key, Stores[self]._name), key, Stores[self]._name)
    elseif not forceSave then
      updateLastAction(Stores[self]._lastAction, key, "Saving data succeed.", "SaveSuccess", true, os.time())
      AuraDataStore.DataStatus:Fire(s_format("Saving data succeed for key: '%s', name: '%s'.", key, Stores[self]._name), key, Stores[self]._name)
    end
    
    if isLeaving then
      Stores[self]._database[key] = nil
      Stores[self]._cache[key] = nil
      Stores[self]._lastAction[key] = nil
    else
      Stores[self]._cache[key] = deepCopy(Stores[self]._database[key])
    end
  end)
end

local function _GetAsync(self: AuraStore, key: string, _retries: number): ({}?, string?)

  if Stores[self]._database[key] then
    return Stores[self]._database[key]
  end

  local success, response, keyInfo = pcall(Stores[self]._store.GetAsync, Stores[self]._store, key)

  if success then
    if response then

      if keyInfo:GetMetadata().SessionLock then
        local secondsPassed = os.time() - keyInfo:GetMetadata().SessionLock
        if secondsPassed < AuraDataStore.SessionLockTime then
          if _retries + 1 >= (AuraDataStore.MaxRetriesIfSessionLocked or 3) then
						AuraDataStore.DataStatus:Fire(s_format("Loading data failed for key: '%s', name: '%s', after %s retries. Reason: Data is session locked, try again in %d seconds. (%s~ minutes)", key, Stores[self]._name, tostring(_retries + 1), AuraDataStore.SessionLockTime - secondsPassed, tostring(math.floor((AuraDataStore.SessionLockTime - secondsPassed)/60))), key, Stores[self]._name, nil, _retries + 1, AuraDataStore.SessionLockTime - secondsPassed)
						return nil, s_format("Data is session locked, try again in %d seconds. (%s~ minutes)", AuraDataStore.SessionLockTime - secondsPassed, tostring(math.floor((AuraDataStore.SessionLockTime - secondsPassed)/60)))
          else
            _retries += 1
						AuraDataStore.DataStatus:Fire(s_format("Loading data failed for key: '%s', name: '%s', retries: %s. Reason: Data is session locked, retrying in %s seconds.", key, Stores[self]._name, tostring(_retries), tostring(AuraDataStore.YieldTimeIfSessionLocked or 5)))
            task.wait(AuraDataStore.YieldTimeIfSessionLocked or 5)
            return _GetAsync(self, key, _retries)
          end
        end
      end

      Stores[self]._database[key] = response
      Stores[self]._cache[key] = deepCopy(response)

      updateLastAction(Stores[self]._lastAction, key, "Data has been loaded successfully.", "LoadSuccess", true, os.time())
    else
      Stores[self]._database[key] = deepCopy(Stores[self]._template)
      Stores[self]._cache[key] = deepCopy(Stores[self]._template)

      updateLastAction(Stores[self]._lastAction, key, "Default data has been loaded.", "NewData", true, os.time())
    end

		AuraDataStore.DataStatus:Fire(s_format("Loading data succeed for key: '%s', name: '%s', after %s retries.", key, Stores[self]._name, tostring(_retries + 1)), key, Stores[self]._name, nil, _retries + 1)
    Save(self, key, nil, false, true, false)
    return Stores[self]._database[key]
  else
    _retries += 1
    if _retries < AuraDataStore.RetryCount then
			AuraDataStore.DataStatus:Fire(s_format("Loading data failed for key: '%s', name: '%s', retrying. Retries: %s", key, Stores[self]._name, tostring(_retries)), key, Stores[self]._name, nil, _retries)
      return _GetAsync(self, key, _retries)
    else
      updateLastAction(Stores[self]._lastAction, key, response, "LoadFail", false, os.time())

      Stores[self]._database[key] = deepCopy(Stores[self]._template)
      Stores[self]._cache[key] = deepCopy(Stores[self]._template)
      Stores[self]._database[key]["DontSave"] = response
      Stores[self]._cache[key]["DontSave"] = response

			AuraDataStore.DataStatus:Fire(s_format("Loading data failed for key: '%s', name: '%s' after %s retries. Reason:\n%s", key, Stores[self]._name, tostring(_retries), response), key, Stores[self]._name, response, _retries)
      
      return Stores[self]._database[key]
    end
  end
end

local function Wipe(self: AuraStore, key: string): boolean
  if Stores[self]._database[key] then
    local old_data = Stores[self]._database[key]
    Stores[self]._database[key] = deepCopy(Stores[self]._template)
    return true, old_data
  end
  return false
end

function DataStore.Wipe(self: AuraStore, key: string): boolean
  return Wipe(self, key)
end

function DataStore.Reconcile(self: AuraStore, key: string): nil
  if Stores[self]._database[key] then
    Reconcile(Stores[self]._database[key], Stores[self]._template)
	end
	return nil
end

function DataStore.FindDatabyKey(self: AuraStore, key: string): {}
  return Stores[self]._database[key]
end

function DataStore.GetLatestAction(self: AuraStore, key: string): {}?
  if Stores[self]._lastAction[key] then
    return deepCopy(Stores[self]._lastAction[key])
	end
	return nil
end

function DataStore.GetAsync(self: AuraStore, key: string): ({}?, string?)
  return _GetAsync(self, key, 0)
end

function DataStore.Save(self: AuraStore, key: string, tblofIDs: {}?): nil
	return Save(self, key, tblofIDs, false, false, false)
end

function DataStore.ForceSave(self: AuraStore, key: string, tblofIDs: {}?): nil
	return Save(self, key, tblofIDs, false, true, false)
end

function DataStore.SaveOnLeave(self: AuraStore, key: string, tblofIDs: {}?): nil
  return Save(self, key, tblofIDs, true, false, false)
end

game:BindToClose(function()
  if AuraDataStore.BindToCloseEnabled and not RunService:IsStudio() then
    for self, value in pairs(Stores) do
      for i, _ in pairs(value._database) do
        Save(self, i, nil, true, false, false)
      end
    end
    task.wait(20)
  end
end)

--// Auto-saving for session locking
coroutine.wrap(function()
  while task.wait(AuraDataStore.SessionLockTime / 3) do
    AuraDataStore.DataStatus:Fire("Starting auto-save..")
    for self, value in pairs(Stores) do
      for i, _ in pairs(value._database) do
        Save(self, i, nil, false, true, true)
      end
    end
    AuraDataStore.DataStatus:Fire("Finished auto-save.")
  end
end)()

return AuraDataStore
