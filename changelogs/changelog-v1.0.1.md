# v1.0.1

- # Changes to Saving

Saving is easier to use and understand now. It has been separated to 3 functions:

```Store_object:Save()```, ```Store_object:ForceSave()``` and ```Store_object:SaveOnLeave()```.

- ## ```Store_object:Save(key, tblofIDs)```

Intended for general saving, will respect to ```CancelSaveIfSaved```.

- ## ```Store_object:ForceSave(key, tblofIDs)```

Intended for saving when it is ***necessary***, will ***not*** respect to ```CancelSaveIfSaved```.

Use cases can be when a player makes a purchase or reaches to a milestone. 

- ## ```Store_object:SaveOnLeave(key, tblofIDs)```

Intended for saving when the player leaves, will ***not*** respect to ```CancelSaveIfSaved```.

Must be only used inside the ```PlayerRemoving``` and not anywhere else.

- ## ```CancelSaveIfSaved``` & ```CancelSaveIfSavedInterval```

```lua
AuraDataStore.CancelSaveIfSaved = true -- (default)
AuraDataStore.CancelSaveIfSavedInterval = 60 -- (default)
```

Will fail ```:Save()``` if data is saved in the last ```60``` seconds and warn about when data is eligible to be saved by ```:Save()```. 

```:ForceSave()``` and ```:SaveOnLeave()``` are ***not*** affected.

It is completely optional and disabling it will only effect ```CancelSaveIfSaved```.