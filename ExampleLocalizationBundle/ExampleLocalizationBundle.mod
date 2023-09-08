return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ExampleLocalizationBundle` encountered an error loading the Darktide Mod Framework.")

		new_mod("ExampleLocalizationBundle", {
			mod_script       = "ExampleLocalizationBundle/scripts/mods/ExampleLocalizationBundle/ExampleLocalizationBundle",
			mod_data         = "ExampleLocalizationBundle/scripts/mods/ExampleLocalizationBundle/ExampleLocalizationBundle_data",
			mod_localization = "ExampleLocalizationBundle/scripts/mods/ExampleLocalizationBundle/ExampleLocalizationBundle_localization",
		})
	end,
	packages = {},
}
