# v1.0.3

- # Wiping Data

This new function overwrites players current data and returns their old data just in case if you change your mind. Player must be kicked after this function to force a save by ```store_object:SaveOnLeave``` inside the ```PlayerRemoving``` or ```BindToClose```.

- # Changes to Session Locking

When a data is session locked, AuraDataStore will now yield and try again. This can be customized as how many times AuraDataStore will try and how many seconds it will yield between retries.