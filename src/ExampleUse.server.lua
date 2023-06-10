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
    local data = PlayerDataStore:GetAsync(player.UserId)
    PlayerDataStore:Reconcile(player.UserId)
    task.wait(2)
    PlayerDataStore:Save(player.UserId)
end)
