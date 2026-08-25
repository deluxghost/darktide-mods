# Compiled Engine Resources

These functions load compiled resources for the current Darktide version:

```lua
SimpleAssets.load_material(asset_path)
SimpleAssets.load_particles(asset_path)
SimpleAssets.load_unit(asset_path)
SimpleAssets.load_animation(asset_path)
```

Success resolves with:

```lua
{
	is_ok = true,
	resource_name = string,
}
```

Failure rejects with:

```lua
{
	is_ok = false,
	resource_name = string,
	error = any,
}
```

A unit may have an optional same-stem `.bones` file. An animation requires a same-stem `.bones` file. Companion files are loaded automatically.

```lua
SimpleAssets.load_unit("units/example.unit"):next(function(result)
	World.spawn_unit_ex(world, result.resource_name)
end)
```
