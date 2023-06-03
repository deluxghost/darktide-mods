return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SoloPlay` encountered an error loading the Darktide Mod Framework.")

		new_mod("SoloPlay", {
			mod_script       = "SoloPlay/scripts/mods/SoloPlay/SoloPlay",
			mod_data         = "SoloPlay/scripts/mods/SoloPlay/SoloPlay_data",
			mod_localization = "SoloPlay/scripts/mods/SoloPlay/SoloPlay_localization",
		})
	end,
	packages = {},
}
