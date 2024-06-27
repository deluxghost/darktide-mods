-- all crosshair plugins must be placed before crosshair_remap in the mod order

-- initialize crosshair data in localization file
local mod = get_mod("ExampleCrosshairRemapPlugin")
-- you must define crosshair settings in `mod.crosshair_remap_crosshairs`
mod.crosshair_remap_crosshairs = {
	{
		-- crosshair name, should be unique
		name = "my_crosshair",
		-- crosshair definition path, should match your lua file path
		template = "ExampleCrosshairRemapPlugin/scripts/mods/ExampleCrosshairRemapPlugin/my_crosshair",
		-- localized name of the crosshair
		localization = {
			en = "My Custom Crosshair",
			["zh-cn"] = "我的自定义准星",
		}
	},
	-- you can keep adding more crosshairs here
}

-- normal localization section
return {
	mod_name = {
		en = "Example Crosshair Remap Plugin",
		["zh-cn"] = "准星自定义插件示例",
	},
	mod_description = {
		en = "Example Crosshair Remap Plugin",
		["zh-cn"] = "准星自定义插件示例",
	},
}
