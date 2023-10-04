return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SpaceToContinue` encountered an error loading the Darktide Mod Framework.")

		new_mod("SpaceToContinue", {
			mod_script       = "SpaceToContinue/scripts/mods/SpaceToContinue/SpaceToContinue",
			mod_data         = "SpaceToContinue/scripts/mods/SpaceToContinue/SpaceToContinue_data",
			mod_localization = "SpaceToContinue/scripts/mods/SpaceToContinue/SpaceToContinue_localization",
		})
	end,
	packages = {},
}
