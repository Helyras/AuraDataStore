# AuraDataStore

AuraDataStore is designed to be simple and easy to use while providing more functionality.

# Contents
- [Installation](https://github.com/Helyras/AuraDataStore#installation)
- [Documentation](https://github.com/Helyras/AuraDataStore#documentation)
- [Functions](https://github.com/Helyras/AuraDataStore#functions)
- [Debugging](https://github.com/Helyras/AuraDataStore#debugging)
- [Example Use](https://github.com/Helyras/AuraDataStore#example-use)

# Installation

- ## Method 1

Grab the [Roblox Model](https://www.roblox.com/library/13727205776/AuraDataStore) and insert it to your experience via toolbox.

- ## Method 2

```lua
local model = game:GetService("InsertService"):LoadAsset(13727205776)
model.AuraDataStore.Parent = game:GetService("ServerStorage")
```

Paste this command into the command bar to insert it into your experience.

# Documentation

- ## Module

```lua
local AuraDataStore = require(game:GetService("ServerStorage"):WaitForChild("AuraDataStore"))
-- Path to where your module is located
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

Enables or disables ```game:BindToClose()``` function, which is necessary for saving data before shutting down server. If you are not going to write one yourself, keep this enabled. Automatically disabled in studio to not cause data store queue to fill up.

```lua
AuraDataStore.RetryCount = 5 -- (default)
```

This is how many times module will try to load data before giving up. If data cannot be loaded for some reason it will be provided as a warning. Refer to [```AuraStore:GetAsync```](https://github.com/Helyras/AuraDataStore#aurastoregetasync) for more information.

```lua
AuraDataStore.SessionLockTime = 1800 -- (default, 30 minutes)
```

How much time data is locked if there is another session. When other session ends, this time gate will be removed. This disables the ability to load the data in different servers.

```lua
AuraDataStore.CheckForUpdate = true -- (default, highly recommended)
```

Will check for new updates on the github page. It is highly recommended to be aware of new updates and update the module.

```lua
AuraDataStore.CancelSaveIfSaved = true -- (default)
AuraDataStore.CancelSaveIfSavedInterval = 60 -- (default)
```

If data is saved in the last ```60``` seconds ```:Save()``` method will fail with a warning telling how much seconds left for data to be eligible to be saved by ```:Save()```.
```ForceSave()``` will ***not*** respect and save with resetting the interval.

```lua
AuraDataStore.MaxRetriesIfSessionLocked = 3 -- (default)
AuraDataStore.YieldTimeIfSessionLocked = 5 -- (default)
```

If data is session locked, AuraDataStore will try ```3``` times while waiting ```5``` seconds each. This is intented for experiences where players are teleported to a sub experience.

With current settings, when a player joins AuraDataStore will try loading their data. If it is session locked it will yield for 5 seconds with a warning message send to ```DataStatus``` signal. If this fails too then it will yield for 5 more seconds then will try for the last time. If it fails again it will return ```data``` as ```nil``` as usual and return a ```reason```.

# Functions

- ## ```AuraDataStore.CreateStore```

```lua
local Template = {
    Cash = 0
}

local PlayerDataStore = AuraDataStore.CreateStore("PlayerDataStore", Template)
```

Returns ```AuraStore```. This is where data is going to be saved. First paramater is the name of the data store, second paramater is the template for the data.

- ## ```AuraStore:GetAsync```

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

```AuraStore:GetAsync``` returns one value only, ```data``` or ```reason```. If ```data``` doesn't exist then ```reason``` will exist. Player should be kicked because this can only happen if their data is session locked. Hence their data is already loaded somewhere else and it is not loaded.

```AuraStore:GetAsync``` must be ran once when player has joined the server. If you want to access their data table from another scope or another script, refer to [```AuraStore:FindDatabyKey```](https://github.com/Helyras/AuraDataStore#aurastorefinddatabykey).

- ## ```AuraStore:Reconcile```

```lua
local key = "Player_" .. player.UserId
PlayerDataStore:Reconcile(key)
```

Returns *void*. It's purpose is to fill out missing values for the existing datas and completely optional.

Example: A player was playing your experience before and only had the value "Cash". In the next update, you added "Biscuits" to the experience and to the template. This function will add "Biscuits" to the existing players data.

- ## ```AuraStore:FindDatabyKey```

```lua
local key = "Player_" .. player.UserId
local data = PlayerDataStore:FindDatabyKey(key)
```

Will return the ```data``` inside of ```AuraStore``` associated with the ```key``` if it exists.


- ## ```AuraStore:Save```

***Will NOT yield your code and returns void.***

```lua
local key = "Player_" .. player.UserId
PlayerDataStore:Save(key, tblofIDs)
```

Should be used for general saving, will respect to ```CancelSaveIfSaved```.

```tblofIDs``` is *not* necessary (for now) and can be blank (```nil```). It is advised to be used for GDPR compliance.

- ## ```AuraStore:ForceSave```

***Will NOT yield your code and returns void.***

```lua
local key = "Player_" .. player.UserId
PlayerDataStore:ForceSave(key, tblofIDs)
```

Should be used for saving when it is necessary, will ***not*** respect to ```CancelSaveIfSaved```.

```tblofIDs``` is *not* necessary (for now) and can be blank (```nil```). It is advised to be used for GDPR compliance.

- ## ```AuraStore:SaveOnLeave```

***Will NOT yield your code and returns void.***

```lua
local key = "Player_" .. player.UserId
PlayerDataStore:SaveOnLeave(key, tblofIDs)
```

***Must*** be used when the player leaves, aka ```PlayerRemoving```. Will ***not*** respect to ```CancelSaveIfSaved```.

```tblofIDs``` is *not* necessary (for now) and can be blank (```nil```). It is advised to be used for GDPR compliance.

- ## ```AuraStore:GetLatestAction```

```lua
local key = "Player_" .. player.UserId
local latestAction = PlayerDataStore:GetLatestAction(key)

print(latestAction)

--[[
    {
        response = ..., :string
        status = ..., :string
        ok = ..., :boolean
        time = ... :number
    }
--]]
```

Will return information about the last action made. Return type is dictionary ```table```. Includes ```response```, ```status```, ```ok``` and ```time```.

- ## ```AuraStore:Wipe```

```lua
local key = "Player_" .. player.UserId
local ok, old_data = PlayerDataStore:Wipe(key)

if ok then
  player:Kick("Your data has been wiped >:(")
end 
```

When called, it will replace the data for that ```key``` with the template of ```AuraStore```. Player ***must*** be kicked afterwards to force a save by ```AuraStore:SaveOnLeave```.

```old_data``` will be their data before the replacement with the template. This will only exist if ```ok``` is ```true```.

# Debugging

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

Important warnings will still warn even if this connection doesn't exists.

# Example Use

```lua
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local AuraDataStore = require(ServerStorage:WaitForChild("AuraDataStore"))
AuraDataStore.SaveInStudio = true

local DataTemplate = {
  Cash = 0
}

local PlayerDataStore = AuraDataStore.CreateStore("PlayerDataStore", DataTemplate)

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

```
#
***This module is still work in progress, bugs may occur. It is still being tested. If you encounter any bugs or errors please let me know. This is not the final result and everything is up to change.***