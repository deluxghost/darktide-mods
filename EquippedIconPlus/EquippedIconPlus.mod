return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`EquippedIconPlus` encountered an error loading the Darktide Mod Framework.")

		new_mod("EquippedIconPlus", {
			mod_script       = "EquippedIconPlus/scripts/mods/EquippedIconPlus/EquippedIconPlus",
			mod_data         = "EquippedIconPlus/scripts/mods/EquippedIconPlus/EquippedIconPlus_data",
			mod_localization = "EquippedIconPlus/scripts/mods/EquippedIconPlus/EquippedIconPlus_localization",
		})
	end,
	packages = {},
}
