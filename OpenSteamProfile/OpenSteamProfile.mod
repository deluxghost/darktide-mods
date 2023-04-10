return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`OpenSteamProfile` encountered an error loading the Darktide Mod Framework.")

		new_mod("OpenSteamProfile", {
			mod_script       = "OpenSteamProfile/scripts/mods/OpenSteamProfile/OpenSteamProfile",
			mod_data         = "OpenSteamProfile/scripts/mods/OpenSteamProfile/OpenSteamProfile_data",
			mod_localization = "OpenSteamProfile/scripts/mods/OpenSteamProfile/OpenSteamProfile_localization",
		})
	end,
	packages = {},
}
