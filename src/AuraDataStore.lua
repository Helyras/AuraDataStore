--// Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

--// Modules
local Promise = require(script:WaitForChild("Promise"))
local Trove = require(script:WaitForChild("Trove"))
local Signal = require(script:WaitForChild("Signal"))

local AuraDataStore = {
	-- Settings
	AutoSaveEnabled = true,
	AutoSaveInterval = 180,
	DebugMessages = true,
	SaveInStudio = false,
	BindToCloseEnabled = true,
	-- Events
	SuccessfullyLoaded = Signal.new(),
	ErrorOnLoadingData = Signal.new(),
}

local Database = {}
local Cache = {}

local Stores = {}

local DataStore = {}
DataStore.__index = DataStore

--// Local Functions
local function CheckTableEquality(t1, t2)
    for i,v in next, t1 do
        if typeof(v) == "table" then
            return CheckTableEquality(t2[i], v)
        end
		if t2[i] ~= v then
			return false
		end 
	end
    for i,v in next, t2 do
        if typeof(v) == "table" then
            return CheckTableEquality(t1[i], v)
        end
		if t1[i] ~= v then
			return false
		end
	end
    return true
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

local function WaitForRequestBudget()
	local currentBudget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	while currentBudget < 1 do
		currentBudget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		task.wait(5)
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

	if CheckTableEquality(Database[key], self._template) then
		SendMessage("Data is equal to template")
		return true
	end

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
		Cache[key] = deepCopy(Database[key])
	end)
	:catch(function(err)
		warn(err)
	end)

	if _isLeaving then
		Database[key] = nil
		Cache[key] = nil
	end
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