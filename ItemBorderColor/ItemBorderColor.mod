return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ItemBorderColor` encountered an error loading the Darktide Mod Framework.")

		new_mod("ItemBorderColor", {
			mod_script       = "ItemBorderColor/scripts/mods/ItemBorderColor/ItemBorderColor",
			mod_data         = "ItemBorderColor/scripts/mods/ItemBorderColor/ItemBorderColor_data",
			mod_localization = "ItemBorderColor/scripts/mods/ItemBorderColor/ItemBorderColor_localization",
		})
	end,
	packages = {},
}
