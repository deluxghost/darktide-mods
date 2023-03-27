return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`CleanForceBlocking` encountered an error loading the Darktide Mod Framework.")

		new_mod("CleanForceBlocking", {
			mod_script       = "CleanForceBlocking/scripts/mods/CleanForceBlocking/CleanForceBlocking",
			mod_data         = "CleanForceBlocking/scripts/mods/CleanForceBlocking/CleanForceBlocking_data",
			mod_localization = "CleanForceBlocking/scripts/mods/CleanForceBlocking/CleanForceBlocking_localization",
		})
	end,
	packages = {},
}
