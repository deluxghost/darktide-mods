return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SoloPlayStratagems` encountered an error loading the Darktide Mod Framework.")

		new_mod("SoloPlayStratagems", {
			mod_script       = "SoloPlayStratagems/scripts/mods/SoloPlayStratagems/SoloPlayStratagems",
			mod_data         = "SoloPlayStratagems/scripts/mods/SoloPlayStratagems/SoloPlayStratagems_data",
			mod_localization = "SoloPlayStratagems/scripts/mods/SoloPlayStratagems/SoloPlayStratagems_localization",
		})
	end,
	packages = {},
}
