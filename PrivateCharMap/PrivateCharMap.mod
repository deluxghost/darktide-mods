return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PrivateCharMap` encountered an error loading the Darktide Mod Framework.")

		new_mod("PrivateCharMap", {
			mod_script       = "PrivateCharMap/scripts/mods/PrivateCharMap/PrivateCharMap",
			mod_data         = "PrivateCharMap/scripts/mods/PrivateCharMap/PrivateCharMap_data",
			mod_localization = "PrivateCharMap/scripts/mods/PrivateCharMap/PrivateCharMap_localization",
		})
	end,
	packages = {},
}
