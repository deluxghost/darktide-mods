return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Creeper` encountered an error loading the Darktide Mod Framework.")

		new_mod("Creeper", {
			mod_script       = "Creeper/scripts/mods/Creeper/Creeper",
			mod_data         = "Creeper/scripts/mods/Creeper/Creeper_data",
			mod_localization = "Creeper/scripts/mods/Creeper/Creeper_localization",
		})
	end,
	packages = {},
}
