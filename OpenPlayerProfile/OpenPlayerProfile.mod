return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`OpenPlayerProfile` encountered an error loading the Darktide Mod Framework.")

		new_mod("OpenPlayerProfile", {
			mod_script       = "OpenPlayerProfile/scripts/mods/OpenPlayerProfile/OpenPlayerProfile",
			mod_data         = "OpenPlayerProfile/scripts/mods/OpenPlayerProfile/OpenPlayerProfile_data",
			mod_localization = "OpenPlayerProfile/scripts/mods/OpenPlayerProfile/OpenPlayerProfile_localization",
		})
	end,
	packages = {},
}
