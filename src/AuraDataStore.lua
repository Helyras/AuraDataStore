--// Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

--// Modules
local Promise = require(script:WaitForChild("Promise"))
local Signal = require(script:WaitForChild("Signal"))

local AuraDataStore = {
	--// Settings
	AutoSaveEnabled = true,
	AutoSaveInterval = 180,
	DebugMessages = true,
	SaveInStudio = false,
	BindToCloseEnabled = true,
	--// Events
	SuccessfullyLoaded = Signal.new(),
	ErrorOnLoadingData = Signal.new(),
}

if not RunService:IsServer() then
	error("must be on server")
end

local Stores = {}

local DataStore = {}
DataStore.__index = DataStore

--// Local Functions
local function CheckTableEquality(t1, t2)
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

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

local function Reconcile(tbl, template)
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

local function SendMessage(message)
	if AuraDataStore.DebugMessages then
		warn(message)
	end
end

--// Data Store Functions
AuraDataStore.CreateStore = function(name, template)
	local store = setmetatable({
		_store = DataStoreService:GetDataStore(name),
		_template = deepCopy(template),
		_Database = {},
		_Cache = {}
	}, DataStore)
	table.insert(Stores, store)
	return store
end

function DataStore:Reconcile(key)
	if self._Database[key] then
		Reconcile(self._Database[key], self._template)
	end
end

function DataStore:GetAsync(key)

	local success, response = pcall(self._store.GetAsync, self._store, key)
	if success then

		if response then
			self._Database[key] = response
			self._Cache[key] = deepCopy(response)
		else
			self._Database[key] = deepCopy(self._template)
			self._Cache[key] = deepCopy(self._template)
		end

		return self._Database[key]
	else
		return self:GetAsync(key)
	end
end

function DataStore:Save(key, tblofIDs, isLeaving)

	if CheckTableEquality(self._Database[key], self._Cache[key]) then
		SendMessage("Data not saving, identical")
		return true
	end

	if not tblofIDs then
		tblofIDs = {}
	end

	Promise.new(function(resolve, reject)
		local success, response = pcall(self._store.SetAsync, self._store, key, self._Database[key], tblofIDs)
		if success then
			resolve(response)
		else
			reject(response)
			self:Save(key, tblofIDs)
		end
	end)
	:andThen(function()
		SendMessage("Saved successfully")
		if isLeaving then
			self._Database[key] = nil
			self._Cache[key] = nil
		else
			self._Cache[key] = deepCopy(self._Database[key])
		end
	end)
	:catch(function(err)
		warn(err)
	end)
end

local function BindToClose()
	if AuraDataStore.BindToCloseEnabled then
		for _, self in pairs(Stores) do
			for i, _ in pairs(self._Database) do
				self:Save(i)
			end
		end
	end
	task.wait(20)
end

game:BindToClose(BindToClose)
return AuraDataStore
