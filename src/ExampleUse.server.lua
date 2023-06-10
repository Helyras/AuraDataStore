local ServerStorage = game:GetService("ServerStorage")

local AuraDataStore = require(ServerStorage:WaitForChild("AuraDataStore"))

local AuraTemplate = {
    Cash = 0,
    Test = 70,
    Tbl = {},
    TblWithData = {
        Test = 5,
        Tbl = {
            qwe = 12
        }
    }
}

local PlayerDataStore = AuraDataStore.CreateStore("PlayerDataStore", AuraTemplate)

game.Players.PlayerAdded:Connect(function(player)

    local key = player.UserId

    local data = PlayerDataStore:GetAsync(key)
    PlayerDataStore:Reconcile(key)
    task.wait(2)
    PlayerDataStore:Save(key, {player.UserId})
    data.Cash = 0
end)
