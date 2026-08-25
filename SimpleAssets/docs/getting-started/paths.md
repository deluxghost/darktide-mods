# Asset Paths and Resource Names

SimpleAssets uses two path kinds:

- `asset_path` and `asset_dir_path` identify files or directories that SimpleAssets may read. Relative paths use the calling mod's `assets` directory.
- `target_resource_path` identifies an engine resource to replace. It is already a virtual path and is not expanded relative to the calling mod.

A virtual path is a canonical, forward-slash path under the Darktide game or user mods namespace. It is not a physical Windows path. Examples include `mods/MyAssetMod/assets/ui/icon.png` and `content/characters/player/human/first_person/arms.unit`.

## Accepted path forms

Input paths may use forward slashes or backslashes. The examples below use forward slashes.

Relative paths start in the calling mod's `assets` directory:

```lua
SimpleAssets.load_texture("ui/icon.png")
-- mods/MyAssetMod/assets/ui/icon.png
```

Paths starting with the calling mod's name start in that mod's root directory:

```lua
SimpleAssets.load_texture("MyAssetMod/textures/icon.png")
-- mods/MyAssetMod/textures/icon.png
```

Paths starting with `mods/` start in Darktide's mods directory and may reference another mod:

```lua
SimpleAssets.load_texture("mods/OtherAssetPack/assets/icon.png")
-- mods/OtherAssetPack/assets/icon.png
```

Absolute Windows paths must be under either the Darktide game directory or the `mods` directory in the Darktide user data directory:

```lua
SimpleAssets.load_texture("C:/Users/User/AppData/Roaming/Fatshark/Darktide/mods/MyAssetMod/assets/icon.png")
-- mods/MyAssetMod/assets/icon.png
```

Paths outside these roots are rejected.

## Path normalization and file resolution

Before accessing a file, SimpleAssets converts the accepted input into the virtual asset path shown in the example comments above.

Files under the game directory are represented relative to that directory. Files under the user data `mods` directory are represented under the same `mods/...` namespace as files under the game directory.

SimpleAssets uses this path as the file's identity when generating resource names, detecting duplicate inputs, and resolving the physical file. Symbolic-link and junction targets are not resolved when paths are normalized or checked against the allowed roots.

Files under `mods/` are resolved in this order:

```text
<user_dir>/mods/...
<game_dir>/mods/...
```

When both locations contain the same virtual path, the file in the user directory is used. A primary resource and its companion files are always read from the same location.

## Target resource paths

Replacement functions accept the target engine resource as `target_resource_path`:

```lua
SimpleAssets.replace_unit(
	"content/units/example_target.unit",
	"units/example_source.unit"
)
```

The target path is normalized but is not resolved as a file. It must include the extension for the selected replacement function. Its resource name is the normalized path with that final extension removed; the example target resource name is `content/units/example_target`.

The source argument remains an `asset_path` and follows the file-resolution rules above.

## File extensions

All loading functions use the same path rules, but their final-extension requirements differ:

| Function                                             | Required final extension |
| ---------------------------------------------------- | ------------------------ |
| `load_texture` with PNG, JPEG, or DDS content        | None.                    |
| `load_texture` with a compiled `.texture` resource   | `.texture`               |
| `load_material`                                      | `.material`              |
| `load_particles`                                     | `.particles`             |
| `load_unit`                                          | `.unit`                  |
| `load_animation`                                     | `.animation`             |
| `load_font`                                          | `.slug`                  |
| `load_mouse_cursor`                                  | `.png`                   |
| `load_video`                                         | `.ivf` or `.bk2`         |
| `load_slug_album`                                    | `.slug`                  |

`load_texture` supports PNG, JPEG, and DDS files identified by their file signatures, and compiled `.texture` resources. Their Promise fields are documented under [Textures](../api/textures.md).

A companion `.stream` file is discovered from its primary `.texture` path and is not passed as an independent asset path.

A replacement target uses the compiled engine resource extension for its type. The source uses the extension accepted by the corresponding loading function. These extensions are the same except for `replace_mouse_cursor`, whose target ends in `.mouse_cursor` and whose PNG source ends in `.png`. `replace_texture` accepts only compiled `.texture` resources.

## Resource names

The resource name for a path-derived engine resource is generated in two steps:

1. Convert `asset_path` to its virtual asset path.
2. Remove the last `.` and everything after it from the final path segment.

For example:

```text
# asset_path
units/example.unit

# virtual asset path
mods/MyAssetMod/assets/units/example.unit

# resource name
mods/MyAssetMod/assets/units/example
```

Callers may apply this rule directly or use the convenience function:

```lua
local resource_name = SimpleAssets.get_resource_name("units/example.unit")
```

Loading functions return the path-derived name in `result.resource_name`. Replacement functions return both `target_resource_name` and `source_resource_name`. `load_font` also returns `font_type`, which is a separate UI font alias and does not affect the resource name.

The resource name may be calculated before loading, including before defining a UI pass that needs it, but the named engine resource may only be consumed after its loading Promise resolves.
