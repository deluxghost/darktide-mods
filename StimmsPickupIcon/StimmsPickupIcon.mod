return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`StimmsPickupIcon` encountered an error loading the Darktide Mod Framework.")

		new_mod("StimmsPickupIcon", {
			mod_script       = "StimmsPickupIcon/scripts/mods/StimmsPickupIcon/StimmsPickupIcon",
			mod_data         = "StimmsPickupIcon/scripts/mods/StimmsPickupIcon/StimmsPickupIcon_data",
			mod_localization = "StimmsPickupIcon/scripts/mods/StimmsPickupIcon/StimmsPickupIcon_localization",
		})
	end,
	packages = {},
}
