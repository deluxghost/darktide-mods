return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MergedTalentStats` encountered an error loading the Darktide Mod Framework.")

		new_mod("MergedTalentStats", {
			mod_script       = "MergedTalentStats/scripts/mods/MergedTalentStats/MergedTalentStats",
			mod_data         = "MergedTalentStats/scripts/mods/MergedTalentStats/MergedTalentStats_data",
			mod_localization = "MergedTalentStats/scripts/mods/MergedTalentStats/MergedTalentStats_localization",
		})
	end,
	packages = {},
}
