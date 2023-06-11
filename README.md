# AuraDataStore

AuraDataStore is designed to be simple and easy to use while providing more functionality.

# Documentation

- ## Module
```lua
local AuraDataStore = require()
```
Requiring the module. Will throw an error if required on client.

- ## Configuration

```lua
AuraDataStore.SaveInStudio = false (default)
```

Enables or disables studio saving. Default is false.

```lua
AuraDataStore.BindToCloseEnabled = true (default, highly recommended)
```

Enables or disables game:BindToClose() function, which is necessary for saving data before shutting down server. If you are not going to write one yourself, keep this enabled. Automatically disabled in studio to not cause data store queue to fill up.

```lua
AuraDataStore.RetryCount = 5 (default)
```

This is how many times module will try to load data before giving up. If data cannot be loaded for some reason it will be provided as a warning. Refer to :GetAsync() for more information.

```lua
AuraDataStore.SessionLockTime = 1800 (default, 30 minutes)
```

How much time data is locked if there is another session. When other session ends, this time gate will be removed. This disables the ability to load the data in different servers.

- ## Debugging
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

# Functions

- ## AuraDataStore.CreateStore
