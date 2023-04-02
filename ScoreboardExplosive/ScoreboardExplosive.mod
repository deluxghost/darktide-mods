return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ScoreboardExplosive` encountered an error loading the Darktide Mod Framework.")

		new_mod("ScoreboardExplosive", {
			mod_script       = "ScoreboardExplosive/scripts/mods/ScoreboardExplosive/ScoreboardExplosive",
			mod_data         = "ScoreboardExplosive/scripts/mods/ScoreboardExplosive/ScoreboardExplosive_data",
			mod_localization = "ScoreboardExplosive/scripts/mods/ScoreboardExplosive/ScoreboardExplosive_localization",
		})
	end,
	packages = {},
}
