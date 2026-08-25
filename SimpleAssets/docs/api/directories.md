# Directories

```lua
local game_dir = SimpleAssets.get_game_dir()
local user_dir = SimpleAssets.get_user_dir()
```

`get_game_dir()` returns the Darktide game directory used to resolve asset paths. On Microsoft Store or PC Game Pass, this may be the protected Windows package directory containing the running executable rather than the Xbox app content directory shown to the user.

`get_user_dir()` returns the Darktide user data directory.
