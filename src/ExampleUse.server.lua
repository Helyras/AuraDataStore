local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local AuraDataStore = require(ServerStorage:WaitForChild("AuraDataStore"))
AuraDataStore.SaveInStudio = true

local AuraTemplate = {
	Cash = 0
}

local PlayerDataStore = AuraDataStore.CreateStore("PlayerDataStore", AuraTemplate)

Players.PlayerAdded:Connect(function(player)
	local key = player.UserId
	local data, reason = PlayerDataStore:GetAsync(key)

	if not data then
		player:Kick(reason)
		return
	end

	PlayerDataStore:Reconcile(key) -- optional

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = folder

	cash.Value = data.Cash
	cash.Changed:Connect(function()
		data.Cash = cash.Value
	end)

	folder.Parent = player
end)

Players.PlayerRemoving:Connect(function(player)
	local key = player.UserId
	PlayerDataStore:SaveOnLeave(key, {key})
end)

AuraDataStore.DataStatus:Connect(function(info, key, name, response, retries, sessionLockCooldown)
	warn(info)
end)
