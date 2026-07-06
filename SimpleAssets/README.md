# SimpleAssets

`SimpleAssets` is a local asset library for other Darktide mods. It loads local image files as game textures and supports batch texture loading.

## Quick Start

The examples below place image files in the calling mod's `assets` directory:

```text
mods/MyAssetMod/assets/icon.png
mods/MyAssetMod/assets/ui/frame.png
```

In the calling mod, wait until all mods are loaded before getting `SimpleAssets`:

```lua
local SimpleAssets

mod.on_all_mods_loaded = function()
	SimpleAssets = get_mod("SimpleAssets")

	if not SimpleAssets then
		mod:error("SimpleAssets is required.")
		return
	end

	SimpleAssets.load_texture("icon.png"):next(function(data)
		mod.icon_texture = data.texture
	end)
end
```

## Path Rules

Forward slashes and backslashes are accepted. Paths are normalized to forward slashes internally, and the examples below use forward slashes.

`SimpleAssets.load_texture("file.png")` reads from the calling mod's `assets` directory by default:

```lua
SimpleAssets.load_texture("icon.png")
-- mods/MyAssetMod/assets/icon.png

SimpleAssets.load_texture("ui/icon.png")
-- mods/MyAssetMod/assets/ui/icon.png
```

If the path starts with the calling mod name, it is resolved from that mod's root directory:

```lua
SimpleAssets.load_texture("MyAssetMod/textures/icon.png")
-- mods/MyAssetMod/textures/icon.png
```

If the path starts with `mods/`, it is resolved from Darktide's `mods` directory. This can be used to read files from another mod:

```lua
SimpleAssets.load_texture("mods/OtherAssetPack/assets/icon.png")
-- mods/OtherAssetPack/assets/icon.png
```

Windows absolute paths are used as-is:

```lua
SimpleAssets.load_texture("D:/Images/icon.png")
```

## Directories

```lua
local game_dir = SimpleAssets.get_game_dir()
local user_dir = SimpleAssets.get_user_dir()
```

- `get_game_dir`: Returns the Darktide game directory used for mod asset paths. On Microsoft Store / PC Game Pass, this may be the protected Windows package folder that contains the running executable, not the Xbox app content folder visible to the user.
- `get_user_dir`: Returns Darktide's user data directory.

Files outside these two directories cannot be loaded, including Windows absolute paths.

## Loading Textures

```lua
local promise = SimpleAssets.load_texture(asset_path)
```

Supported image formats are determined by the game texture loader.

Success value:

```lua
{
	is_ok = true,
	url = string,
	texture = userdata,
	width = number,
	height = number,
}
```

Failure error:

```lua
{
	is_ok = false,
	url = string,
}
```

Example:

```lua
SimpleAssets.load_texture("ui/icon.png"):next(function(data)
	local texture = data.texture
end)
```

## Loading Multiple Textures

```lua
local promise = SimpleAssets.load_textures(asset_paths)
```

`asset_paths` is an array. Each item uses the same path rules as `load_texture`. A single item failure does not reject the whole batch.

```lua
{
	["ui/icon.png"] = {
		is_ok = true,
		url = string,
		texture = userdata,
		width = number,
		height = number,
	},
	["ui/missing.png"] = {
		is_ok = false,
		url = string,
	},
}
```

Each value uses the same success or failure shape as `load_texture`.

Duplicate path strings are not allowed.

Example:

```lua
SimpleAssets.load_textures({
	"ui/icon.png",
	"ui/frame.png",
}):next(function(results)
	local icon = results["ui/icon.png"]

	if icon and icon.is_ok then
		mod.icon_texture = icon.texture
	end
end)
```

## Loading Textures From A Directory

```lua
local promise = SimpleAssets.load_textures_from_dir(asset_dir_path, recursive)
```

`asset_dir_path` is a directory path. It uses the same path rules as `load_texture`. Set `recursive` to `true` to include child directories.

The result uses the same value format as `load_textures`, but keys are relative paths from `asset_dir_path`.

Example:

```lua
SimpleAssets.load_textures_from_dir("textures", true):next(function(results)
	local a = results["a.png"]
	local b = results["aaa/bbb.png"]

	if a and a.is_ok then
		mod.a_texture = a.texture
	end
end)
```

All files in the directory are attempted. Files the game cannot decode are returned as failed items.
