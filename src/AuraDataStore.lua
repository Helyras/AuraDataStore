--// Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

--// Modules
local Promise = require(script:WaitForChild("Promise"))
local Trove = require(script:WaitForChild("Trove"))
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

local Database = {}
local Cache = {}
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
		_template = deepCopy(template)
	}, DataStore)
	Stores[store] = {}
	return store
end

AuraDataStore.FindDatabyKey = function(key)
	return Database[key]
end

function DataStore:Reconcile(key)
	for k, v in pairs(self._template) do
        if type(k) == "string" then
            if Database[key][k] == nil then
                if type(v) == "table" then
                    Database[key][k] = deepCopy(v)
                else
                    Database[key][k] = v
                end
            elseif type(Database[key][k]) == "table" and type(v) == "table" then
                Reconcile(Database[key][k], v)
            end
        end
    end
end

function DataStore:GetAsync(key)

	if not table.find(Stores[self], key) then
		table.insert(Stores[self], key)
	end

	local success, response = pcall(self._store.GetAsync, self._store, key)
	if success then

		if response then
			Database[key] = response
			Cache[key] = deepCopy(response)
		else
			Database[key] = deepCopy(self._template)
			Cache[key] = deepCopy(self._template)
		end

		return Database[key]
	else
		return response
	end
end

function DataStore:Save(key, _isLeaving)

	if CheckTableEquality(Database[key], Cache[key]) then
		SendMessage("Data not saving, identical")
		return true
	end

	Promise.new(function(resolve, reject)
		local success, response = pcall(self._store.SetAsync, self._store, key, Database[key])
		if success then
			resolve(response)
		else
			reject(response)
			self:Save(key)
		end
	end)
	:andThen(function()
		SendMessage("saved")
		if _isLeaving then
			Database[key] = nil
			Cache[key] = nil
		else
			Cache[key] = deepCopy(Database[key])
		end
	end)
	:catch(function(err)
		warn(err)
	end)
end

local function BindToClose()
	if AuraDataStore.BindToCloseEnabled then
		for self, keys in pairs(Stores) do
			for _, key in pairs(keys) do
				self:Save(key)
			end
		end
	end
end

game:BindToClose(BindToClose)
return AuraDataStore