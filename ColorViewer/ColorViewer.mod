return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ColorViewer` encountered an error loading the Darktide Mod Framework.")

		new_mod("ColorViewer", {
			mod_script       = "ColorViewer/scripts/mods/ColorViewer/ColorViewer",
			mod_data         = "ColorViewer/scripts/mods/ColorViewer/ColorViewer_data",
			mod_localization = "ColorViewer/scripts/mods/ColorViewer/ColorViewer_localization",
		})
	end,
	packages = {},
}
