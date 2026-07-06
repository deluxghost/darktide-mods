return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SimpleAssets` encountered an error loading the Darktide Mod Framework.")

		new_mod("SimpleAssets", {
			mod_script       = "SimpleAssets/scripts/mods/SimpleAssets/SimpleAssets",
			mod_data         = "SimpleAssets/scripts/mods/SimpleAssets/SimpleAssets_data",
			mod_localization = "SimpleAssets/scripts/mods/SimpleAssets/SimpleAssets_localization",
		})
	end,
	packages = {},
}
