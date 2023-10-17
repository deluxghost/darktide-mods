return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ShowMeRealWeaponStats` encountered an error loading the Darktide Mod Framework.")

		new_mod("ShowMeRealWeaponStats", {
			mod_script       = "ShowMeRealWeaponStats/scripts/mods/ShowMeRealWeaponStats/ShowMeRealWeaponStats",
			mod_data         = "ShowMeRealWeaponStats/scripts/mods/ShowMeRealWeaponStats/ShowMeRealWeaponStats_data",
			mod_localization = "ShowMeRealWeaponStats/scripts/mods/ShowMeRealWeaponStats/ShowMeRealWeaponStats_localization",
		})
	end,
	packages = {},
}
