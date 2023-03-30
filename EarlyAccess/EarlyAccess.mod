return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`EarlyAccess` encountered an error loading the Darktide Mod Framework.")

		new_mod("EarlyAccess", {
			mod_script       = "EarlyAccess/scripts/mods/EarlyAccess/EarlyAccess",
			mod_data         = "EarlyAccess/scripts/mods/EarlyAccess/EarlyAccess_data",
			mod_localization = "EarlyAccess/scripts/mods/EarlyAccess/EarlyAccess_localization",
		})
	end,
	packages = {},
}
