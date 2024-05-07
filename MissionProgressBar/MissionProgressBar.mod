return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MissionProgressBar` encountered an error loading the Darktide Mod Framework.")

		new_mod("MissionProgressBar", {
			mod_script       = "MissionProgressBar/scripts/mods/MissionProgressBar/MissionProgressBar",
			mod_data         = "MissionProgressBar/scripts/mods/MissionProgressBar/MissionProgressBar_data",
			mod_localization = "MissionProgressBar/scripts/mods/MissionProgressBar/MissionProgressBar_localization",
		})
	end,
	packages = {},
}
