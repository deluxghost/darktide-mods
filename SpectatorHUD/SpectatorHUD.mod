return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SpectatorHUD` encountered an error loading the Darktide Mod Framework.")

		new_mod("SpectatorHUD", {
			mod_script       = "SpectatorHUD/scripts/mods/SpectatorHUD/SpectatorHUD",
			mod_data         = "SpectatorHUD/scripts/mods/SpectatorHUD/SpectatorHUD_data",
			mod_localization = "SpectatorHUD/scripts/mods/SpectatorHUD/SpectatorHUD_localization",
		})
	end,
	packages = {},
}
