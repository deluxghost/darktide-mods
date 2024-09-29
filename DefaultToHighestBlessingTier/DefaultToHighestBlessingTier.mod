return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DefaultToHighestBlessingTier` encountered an error loading the Darktide Mod Framework.")

		new_mod("DefaultToHighestBlessingTier", {
			mod_script       = "DefaultToHighestBlessingTier/scripts/mods/DefaultToHighestBlessingTier/DefaultToHighestBlessingTier",
			mod_data         = "DefaultToHighestBlessingTier/scripts/mods/DefaultToHighestBlessingTier/DefaultToHighestBlessingTier_data",
			mod_localization = "DefaultToHighestBlessingTier/scripts/mods/DefaultToHighestBlessingTier/DefaultToHighestBlessingTier_localization",
		})
	end,
	packages = {},
}
