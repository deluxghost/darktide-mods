return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`OneMoreTry` encountered an error loading the Darktide Mod Framework.")

		new_mod("OneMoreTry", {
			mod_script       = "OneMoreTry/scripts/mods/OneMoreTry/OneMoreTry",
			mod_data         = "OneMoreTry/scripts/mods/OneMoreTry/OneMoreTry_data",
			mod_localization = "OneMoreTry/scripts/mods/OneMoreTry/OneMoreTry_localization",
		})
	end,
	packages = {},
}
