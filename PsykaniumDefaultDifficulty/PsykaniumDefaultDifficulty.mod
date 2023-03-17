return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PsykaniumDefaultDifficulty` encountered an error loading the Darktide Mod Framework.")

		new_mod("PsykaniumDefaultDifficulty", {
			mod_script       = "PsykaniumDefaultDifficulty/scripts/mods/PsykaniumDefaultDifficulty/PsykaniumDefaultDifficulty",
			mod_data         = "PsykaniumDefaultDifficulty/scripts/mods/PsykaniumDefaultDifficulty/PsykaniumDefaultDifficulty_data",
			mod_localization = "PsykaniumDefaultDifficulty/scripts/mods/PsykaniumDefaultDifficulty/PsykaniumDefaultDifficulty_localization",
		})
	end,
	packages = {},
}
