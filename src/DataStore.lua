--// Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Signals
local SuccessfullyLoadedSignal = Instance.new("BindableEvent")
local ErrorOnLoadingDataSignal = Instance.new("BindableEvent")

local LuckyDataStore = {
	-- Settings
	AutoSaveEnabled = true,
	AutoSaveCooldown = 180,
	DebugMessages = true,
	SaveInStudio = true,
	BindToCloseEnabled = true,
	-- Events
	SuccessfullyLoaded = SuccessfullyLoadedSignal.Event,
	ErrorOnLoadingData = ErrorOnLoadingDataSignal.Event,
}

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
	if LuckyDataStore.DebugMessages then
		warn(message)
	end
end

local function PlayerRemoving()
end

local function BindToClose()
end

game.Players.PlayerRemoving:Connect(PlayerRemoving)
game:BindToClose(BindToClose)

return LuckyDataStore