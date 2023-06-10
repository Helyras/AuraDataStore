local ServerStorage = game:GetService("ServerStorage")

local AuraDataStore = require(ServerStorage:WaitForChild("AuraDataStore"))

local AuraTemplate = {
    Cash = 0
}

local PlayerDataStore = AuraDataStore.CreateStore("PlayerDataStore", AuraTemplate)

game.Players.PlayerAdded:Connect(function(player)
    local data = PlayerDataStore:GetAsync(player.UserId)
    data.Cash = 5

    task.wait(5)

    PlayerDataStore:Save(player.UserId)
end)
