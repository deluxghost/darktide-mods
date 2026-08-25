# Textures

## `load_texture`

```lua
local promise = SimpleAssets.load_texture(asset_path)
```

`load_texture` supports PNG, JPEG, DDS, and compiled `.texture` resources. The file format determines which table the Promise returns:

- For a PNG, JPEG, or DDS signature, a successful result contains `url`, a `texture` object, `width`, and `height`.
- For a compiled `.texture` resource, a successful result contains `resource_name` and a string `texture` value.

### Files with a PNG, JPEG, or DDS signature

Success resolves with:

```lua
{
	is_ok = true,
	url = string,
	texture = userdata,
	width = number,
	height = number,
}
```

An image failure rejects with:

```lua
{
	is_ok = false,
	url = string,
}
```

### Compiled `.texture` resources

A compiled `.texture` resource resolves with:

```lua
{
	is_ok = true,
	resource_name = string,
	texture = string,
}
```

In this result, `texture` and `resource_name` contain the same engine resource name.

A failure rejects with:

```lua
{
	is_ok = false,
	resource_name = string,
	error = any,
}
```

File-header inspection, file-read, and unsupported-format failures reject with a table containing `is_ok = false` and `error`.

```lua
SimpleAssets.load_texture("ui/icon.png"):next(function(result)
	mod.icon_texture = result.texture
end)
```

A streamed `.texture` resource places its stream data at `<asset_path>.stream`, for example `frame.texture.stream`.

## `load_textures`

```lua
local promise = SimpleAssets.load_textures(asset_paths)
```

`asset_paths` must be a dense array. Inputs that normalize to the same virtual asset path are duplicates and cause an error before any loading starts.

The outer Promise resolves after every item settles. The result is keyed by each original input path, and each value is the exact success or failure table from the corresponding `load_texture` call:

```lua
SimpleAssets.load_textures({
	"ui/icon.png",
	"textures/frame.texture",
}):next(function(results)
	local icon = results["ui/icon.png"]

	if icon.is_ok then
		mod.icon_texture = icon.texture
	end
end)
```

An item failure does not reject the outer Promise.

## `load_textures_from_dir`

```lua
local promise = SimpleAssets.load_textures_from_dir(asset_dir_path, recursive)
```

An empty directory path selects the calling mod's `assets` directory. Subdirectories are included only when `recursive` is `true`.

The directory scan includes:

- files whose final suffix is `.texture`;
- files with a PNG, JPEG, or DDS signature.

`.texture.stream` files are not loaded as independent entries. Files in unsupported formats are not included.

The result is keyed by paths relative to `asset_dir_path`, and each value is the corresponding item result table. Item failures are stored in the result map. A directory enumeration or candidate-file inspection failure rejects the outer Promise.
