return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`GoodOldOutlines` encountered an error loading the Darktide Mod Framework.")

		new_mod("GoodOldOutlines", {
			mod_script       = "GoodOldOutlines/scripts/mods/GoodOldOutlines/GoodOldOutlines",
			mod_data         = "GoodOldOutlines/scripts/mods/GoodOldOutlines/GoodOldOutlines_data",
			mod_localization = "GoodOldOutlines/scripts/mods/GoodOldOutlines/GoodOldOutlines_localization",
		})
	end,
	packages = {},
}
