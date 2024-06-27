return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ExampleCrosshairRemapPlugin` encountered an error loading the Darktide Mod Framework.")

		new_mod("ExampleCrosshairRemapPlugin", {
			mod_script       = "ExampleCrosshairRemapPlugin/scripts/mods/ExampleCrosshairRemapPlugin/ExampleCrosshairRemapPlugin",
			mod_data         = "ExampleCrosshairRemapPlugin/scripts/mods/ExampleCrosshairRemapPlugin/ExampleCrosshairRemapPlugin_data",
			mod_localization = "ExampleCrosshairRemapPlugin/scripts/mods/ExampleCrosshairRemapPlugin/ExampleCrosshairRemapPlugin_localization",
		})
	end,
	packages = {},
}
