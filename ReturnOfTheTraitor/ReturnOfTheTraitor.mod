return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ReturnOfTheTraitor` encountered an error loading the Darktide Mod Framework.")

		new_mod("ReturnOfTheTraitor", {
			mod_script       = "ReturnOfTheTraitor/scripts/mods/ReturnOfTheTraitor/ReturnOfTheTraitor",
			mod_data         = "ReturnOfTheTraitor/scripts/mods/ReturnOfTheTraitor/ReturnOfTheTraitor_data",
			mod_localization = "ReturnOfTheTraitor/scripts/mods/ReturnOfTheTraitor/ReturnOfTheTraitor_localization",
		})
	end,
	packages = {},
}
