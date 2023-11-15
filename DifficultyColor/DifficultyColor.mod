return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DifficultyColor` encountered an error loading the Darktide Mod Framework.")

		new_mod("DifficultyColor", {
			mod_script       = "DifficultyColor/scripts/mods/DifficultyColor/DifficultyColor",
			mod_data         = "DifficultyColor/scripts/mods/DifficultyColor/DifficultyColor_data",
			mod_localization = "DifficultyColor/scripts/mods/DifficultyColor/DifficultyColor_localization",
		})
	end,
	packages = {},
}
