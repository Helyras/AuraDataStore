# AuraDataStore

AuraDataStore is designed to be simple and easy to use while providing more functionality.

# Contents

[Documentation](https://github.com/Zepherria/AuraDataStore#documentation)
[Functions](https://github.com/Zepherria/AuraDataStore#functions)
[Debugging](https://github.com/Zepherria/AuraDataStore#debugging)
[Example Use](https://github.com/Zepherria/AuraDataStore#example-use)

# Documentation

- ## Module

```lua
local AuraDataStore = require()
```

Requiring the module. Will throw an error if required on client.

- ## Configuration

```lua
AuraDataStore.SaveInStudio = false -- (default)
```

Enables or disables studio saving. Default is false.

```lua
AuraDataStore.BindToCloseEnabled = true -- (default, highly recommended)
```

Enables or disables game:BindToClose() function, which is necessary for saving data before shutting down server. If you are not going to write one yourself, keep this enabled. Automatically disabled in studio to not cause data store queue to fill up.

```lua
AuraDataStore.RetryCount = 5 -- (default)
```

This is how many times module will try to load data before giving up. If data cannot be loaded for some reason it will be provided as a warning. Refer to :GetAsync() for more information.

```lua
AuraDataStore.SessionLockTime = 1800 -- (default, 30 minutes)
```

How much time data is locked if there is another session. When other session ends, this time gate will be removed. This disables the ability to load the data in different servers.

# Functions

- ## AuraDataStore.CreateStore

```lua
local Template = {
    Cash = 0
}

local PlayerDataStore = AuraDataStore.CreateStore("PlayerDataStore", Template)
```

Returns Store object. This is where data is going to be saved. First paramater is the name of the data store, second paramater is the template for the data.

- ## Store_object:GetAsync

```lua
local Template = {
    Cash = 0
}

local PlayerDataStore = AuraDataStore.CreateStore("PlayerDataStore", Template)

game.Players.PlayerAdded:Connect(function(player)
    local key = "Player_" .. player.UserId

    local data, reason = PlayerDataStore:GetAsync(key)

    if not data then
        player:Kick(reason)
        return
    end
end)
```

```key``` is the key in the data store named ```"PlayerDataStore"```. Data will be loaded and saved from this key in this data store. Will yield the script.

```Store_object:GetAsync``` returns one value only, data or reason. If data exists everything is fine, if not then data will be ```nil``` and ```reason``` will exist. Player should be kicked because this can only happen if their data is session locked. Hence their data is already loaded somewhere else and it is not loaded.

```Store_object:GetAsync``` must be ran once when player has joined the server. If you want to access their data table from another scope or another script, refer to ```Store_object:FindDatabyKey```.

- ## Store_object:Reconcile

```lua
local key = "Player_" .. player.UserId
PlayerDataStore:Reconcile(key)
```

Returns *void*. It's purpose is to fill out missing values for the existing datas and completely optional.

Example: A player was playing your game before and only had the value "Cash". In the next update, you added "Biscuits" to the game and to the template. This function will add "Biscuits" to the existing players data.

- ## Store_object:FindDatabyKey
```lua
local key = "Player_" .. player.UserId
local data = PlayerDataStore:FindDatabyKey(key)
```
Will return the data inside of store object associated with the key if it exists.


- ## Store_object:Save

```lua
local key = "Player_" .. player.UserId
PlayerDataStore:Save(key, tblofIDs, isLeaving)
```

Returns *void*. Will *NOT* yield the script.

For general saving, it must be used as:

```lua
local key = "Player_" .. player.UserId
local tblofIDs = {player.UserId}
PlayerDataStore:Save(key, tblofIDs)
```

When used inside the ```PlayerRemoving``` it must be used as:

```lua
local key = "Player_" .. player.UserId
local tblofIDs = {player.UserId}
PlayerDataStore:Save(key, tblofIDs, true)
```

Third paramater is necessary when player leaves as it indicates that. It will unlock the session for it to be load later on.

```tblofIDs``` is *not* necessary (for now) and can be blank (```nil```). It is advised to be used for GDPR compliance.

- # Debugging

```lua
(Signal) AuraDataStore.DataStatus
```

Returns signal object.

```lua
AuraDataStore.DataStatus:Connect(function(info, key, name, response, retries, sessionLockCooldown)
    warn(info)
end)
```

Can be used for debugging to make sure everything is working as how it is supposed to be. ```info```, ```key``` and ```name``` will always exist.

- # Example Use

```lua
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
    PlayerDataStore:Save(key, {key}, true)
end)

AuraDataStore.DataStatus:Connect(function(info, key, name, response, retries, sessionLockCooldown)
    warn(info)
end)
```
#
***This module is still work in progress, bugs may occur. It is still being tested. If you encounter any bugs or errors please let me know. This is not the final result and everything is up to change.***