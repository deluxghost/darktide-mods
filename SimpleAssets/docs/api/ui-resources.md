# Mouse Cursors, Videos, and Slug Albums

These functions use the generic named-resource result table.

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

## Mouse cursors

```lua
local promise = SimpleAssets.load_mouse_cursor(asset_path, hotspot_x, hotspot_y)
```

The source format is PNG. The zero-based hotspot coordinates define the cursor's click point and must be non-negative integers inside the image bounds.

```lua
SimpleAssets.load_mouse_cursor("cursors/aim.png", 9, 9):next(function(result)
	Window.set_cursor(result.resource_name)
end)
```

## Videos

```lua
local promise = SimpleAssets.load_video(asset_path)
```

The source must be either a standard IVF file containing an 8-bit VP8 YUV 4:2:0 stream at a constant positive integer frame rate, or a Bink 2 BK2 file. Audio and alpha are not supported.

```lua
SimpleAssets.load_video("videos/intro.ivf"):next(function(result)
	UIRenderer.create_video_player(ui_renderer, "intro", nil, result.resource_name, true)
end)
```

`result.resource_name` is passed to `UIRenderer.create_video_player`; it is not the value of a `video` UI pass. Destroy the player with `UIRenderer.destroy_video_player` when its view or HUD element exits. The source video file must remain accessible and unchanged while a video player uses it.

## Slug albums

```lua
local promise = SimpleAssets.load_slug_album(asset_path)
```

The asset must be a compiled Slug album. SVG source used to create an album must conform to SVG 1.1. After loading, `result.resource_name` may be used by a `slug_icon` or `multi_slug_icon` UI pass. `draw_index` selects an icon starting at `1`.
