# Quick Start

Place assets in the calling mod's `assets` directory:

```text
mods/MyAssetMod/assets/icon.png
mods/MyAssetMod/assets/ui/frame.png
```

Load a texture with `SimpleAssets`:

```lua
local SimpleAssets

mod.on_all_mods_loaded = function()
	SimpleAssets = get_mod("SimpleAssets")

	if not SimpleAssets then
		mod:error("SimpleAssets is required.")
		return
	end

	SimpleAssets.load_texture("icon.png"):next(function(result)
		mod.icon_texture = result.texture
	end)
end
```

After synchronous argument validation, every loading function returns a Promise. Use a loaded asset only after that Promise resolves.
