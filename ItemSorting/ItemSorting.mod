return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ItemSorting` encountered an error loading the Darktide Mod Framework.")

		new_mod("ItemSorting", {
			mod_script       = "ItemSorting/scripts/mods/ItemSorting/ItemSorting",
			mod_data         = "ItemSorting/scripts/mods/ItemSorting/ItemSorting_data",
			mod_localization = "ItemSorting/scripts/mods/ItemSorting/ItemSorting_localization",
		})
	end,
	packages = {},
}
