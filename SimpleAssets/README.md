# SimpleAssets

`SimpleAssets` lets other Darktide mods load external assets at runtime without packaging them into bundle patches.

It currently supports:

- Loading image files as game textures.
- Loading preconverted `.slug` files as UI fonts.
- Loading `.png` files as mouse cursor resources.
- Loading VP8 `.ivf` files as video resources.
- Loading Slug `.slug` albums as vector icon resources.

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

All asset file and directory paths accepted by this API use the rules below.

Forward slashes and backslashes are accepted. Paths are normalized to forward slashes internally, and the examples below use forward slashes.

Relative asset paths are resolved from the calling mod's `assets` directory by default:

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

Windows absolute paths are accepted, but remain subject to the allowed roots below:

```lua
SimpleAssets.load_texture("C:/Users/User/AppData/Roaming/Fatshark/Darktide/assets/icon.png")
```

The resolved path must be inside either Darktide's game directory or user data directory. Paths outside both directories are rejected, including Windows absolute paths.

## Directories

```lua
local game_dir = SimpleAssets.get_game_dir()
local user_dir = SimpleAssets.get_user_dir()
```

- `get_game_dir`: Returns the Darktide game directory used for mod asset paths. On Microsoft Store / PC Game Pass, this may be the protected Windows package folder that contains the running executable, not the Xbox app content folder visible to the user.
- `get_user_dir`: Returns Darktide's user data directory.

## Engine Resource Names

The following resource types require a mod-local `name` and a final engine resource name:

- `mouse_cursor`
- `video`
- `slug_album`

Obtain that resource name before defining UI passes:

```lua
local name = "intro"
local resource_name = SimpleAssets.get_resource_name(resource_type, name)
```

`resource_type` is one of the types listed above. `name` may contain lowercase letters, digits, underscores, hyphens, dots, and forward slashes. SimpleAssets returns this stable engine resource name:

```text
simple_assets/<calling_mod_name>/<resource_type>/<name>
```

Always use `get_resource_name` instead of constructing the prefix. Pass the original mod-local `name` to the corresponding loader; the loader produces the same final resource name internally. Each loader section specifies which engine API accepts that name.

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

`asset_paths` is an array of asset paths. A single item failure does not reject the whole batch.

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

`asset_dir_path` is an asset directory path. Use an empty string to load from the calling mod's `assets` directory.

`recursive` controls whether child directories are included. Set it to `true` to include them.

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

## Loading Fonts

```lua
local promise = SimpleAssets.load_font(font_type, asset_path)
```

`asset_path` must refer to a preconverted `.slug` file. `font_type` is available to UI definitions immediately because the caller supplies it. Do not render text with it until the promise resolves. The promise resolves to the same `font_type` after the engine resource is ready.

```lua
SimpleAssets.load_font("my_ui_font", "fonts/my_ui_font.slug"):next(function(font_type)
	widget.style.text.font_type = font_type
end)
```

Font names are global in the UI font manager. Existing names and names already registered to another file are rejected.

## Loading Mouse Cursors

```lua
local promise = SimpleAssets.load_mouse_cursor(name, asset_path, hotspot_x, hotspot_y)
```

`name` is the mod-local resource name. `asset_path` must refer to a `.png` file. `hotspot_x` and `hotspot_y` are zero-based pixel coordinates inside the image that define the click point. After the promise resolves, the final `resource_name` can be passed to `Window.set_cursor`.

```lua
local cursor_name = "main"
local promise = SimpleAssets.load_mouse_cursor(cursor_name, "mouse_cursors/my_cursor.png", 9, 9)

promise:next(function()
	Window.set_cursor(SimpleAssets.get_resource_name("mouse_cursor", cursor_name))
end)
```

## Loading Videos

```lua
local promise = SimpleAssets.load_video(name, asset_path)
```

`name` is the mod-local resource name. `asset_path` must refer to a standard VP8 `.ivf` file with a positive whole-number frame rate. The final `resource_name` is passed to `UIRenderer.create_video_player` after the promise resolves.

```lua
local name = "intro"
local resource_name = SimpleAssets.get_resource_name("video", name)
local promise = SimpleAssets.load_video(name, "videos/my_video.ivf")

promise:next(function()
	UIRenderer.create_video_player(ui_renderer, "my_mod_video", nil, resource_name, true)
end)
```

`resource_name` is not the value of a `video` UI pass. Destroy the player with `UIRenderer.destroy_video_player` when its view or HUD element exits. The `.ivf` file must remain accessible and unchanged while a video player uses it.

## Loading Slug Albums

```lua
local promise = SimpleAssets.load_slug_album(name, asset_path)
```

`name` is the mod-local resource name. `asset_path` must refer to a preconverted Slug album `.slug` file. When creating a Slug album from SVG, the source file must conform to SVG 1.1.

After the promise resolves, use the final `resource_name` in a `slug_icon` or `multi_slug_icon` UI pass.

```lua
local name = "icons"
local resource_name = SimpleAssets.get_resource_name("slug_album", name)
local promise = SimpleAssets.load_slug_album(name, "slug_albums/my_icons.slug")

local passes = {
	{
		pass_type = "slug_icon",
		value = resource_name,
		style = {
			draw_index = 1,
		},
	},
}
```

`draw_index` selects the icon inside the album and starts at `1`.
