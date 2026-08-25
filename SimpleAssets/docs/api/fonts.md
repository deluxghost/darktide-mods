# Fonts

```lua
local promise = SimpleAssets.load_font(font_type, asset_path)
```

The asset must be a compiled Slug font. `font_type` is the name registered with the UI font manager. Because the caller supplies this name, it may be placed in UI definitions immediately. Do not render text with the font until the Promise resolves.

Success resolves with:

```lua
{
	is_ok = true,
	resource_name = string,
	font_type = string,
}
```

Failure rejects with:

```lua
{
	is_ok = false,
	resource_name = string,
	font_type = string,
	error = any,
}
```

`font_type` aliases are global. An alias that conflicts with an existing engine font or another external font is rejected.

```lua
SimpleAssets.load_font("my_ui_font", "fonts/my_ui_font.slug"):next(function(result)
	widget.style.text.font_type = result.font_type
end)
```
