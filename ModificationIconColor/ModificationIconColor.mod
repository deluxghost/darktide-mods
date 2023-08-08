return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ModificationIconColor` encountered an error loading the Darktide Mod Framework.")

		new_mod("ModificationIconColor", {
			mod_script       = "ModificationIconColor/scripts/mods/ModificationIconColor/ModificationIconColor",
			mod_data         = "ModificationIconColor/scripts/mods/ModificationIconColor/ModificationIconColor_data",
			mod_localization = "ModificationIconColor/scripts/mods/ModificationIconColor/ModificationIconColor_localization",
		})
	end,
	packages = {},
}
