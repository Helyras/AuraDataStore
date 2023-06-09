local ServerStorage = game:GetService("ServerStorage")

local AuraDataStore = require(ServerStorage:WaitForChild("AuraDataStore"))

local AuraTemplate = {
    Cash = 0
}

local PlayerDataStore = AuraDataStore.CreateStore("PlayerDataStore", AuraTemplate)
