--// Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

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

local DataStores = {}

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

AuraDataStore.CreateStore = function(name, template)
	DataStores[name] = { DataStoreService:GetDataStore(name), deepCopy(template) }
	return DataStores[name][1]
end

local function PlayerRemoving()
end

local function BindToClose()
end

Players.PlayerRemoving:Connect(PlayerRemoving)
game:BindToClose(BindToClose)

return AuraDataStore