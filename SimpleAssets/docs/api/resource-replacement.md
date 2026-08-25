# Resource Replacement

Replacement functions load a source asset and then replace future engine lookups of a target resource:

```lua
SimpleAssets.replace_animation(target_resource_path, source_asset_path)
SimpleAssets.replace_font(target_resource_path, source_asset_path)
SimpleAssets.replace_material(target_resource_path, source_asset_path)
SimpleAssets.replace_mouse_cursor(target_resource_path, source_asset_path, hotspot_x, hotspot_y)
SimpleAssets.replace_particles(target_resource_path, source_asset_path)
SimpleAssets.replace_slug_album(target_resource_path, source_asset_path)
SimpleAssets.replace_texture(target_resource_path, source_asset_path)
SimpleAssets.replace_unit(target_resource_path, source_asset_path)
SimpleAssets.replace_video(target_resource_path, source_asset_path)
```

The target and source must represent the same resource type. Target paths use that type's compiled engine resource extension, while source paths use the corresponding loading format. For `replace_video`, both paths must end in `.ivf` or both must end in `.bk2`. For `replace_mouse_cursor`, the target ends in `.mouse_cursor` and the source ends in `.png`. `replace_texture` accepts compiled `.texture` resources, not PNG, JPEG, or DDS files. `replace_font` replaces a Slug font resource; it does not accept or register a `font_type` UI alias.

Success resolves with:

```lua
{
	is_ok = true,
	target_resource_name = string,
	source_resource_name = string,
}
```

Failure rejects with:

```lua
{
	is_ok = false,
	target_resource_name = string,
	source_resource_name = string,
	error = any,
}
```

The replacement may be registered after the target resource has already loaded. Once the Promise resolves, later resource lookups use the source resource. Calling the same replacement function again for the same target updates later lookups to the new source.

Objects that already acquired the target resource are not rebuilt. For example, `replace_unit` affects units spawned after its Promise resolves; it does not change a unit that is already present in a world.

```lua
SimpleAssets.replace_unit(
	"content/units/example_target.unit",
	"units/example_source.unit"
):next(function(result)
	local unit = World.spawn_unit_ex(world, result.target_resource_name)
end)
```
