return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`M1GalvanicRifle` encountered an error loading the Darktide Mod Framework.")

		new_mod("M1GalvanicRifle", {
			mod_script       = "M1GalvanicRifle/scripts/mods/M1GalvanicRifle/M1GalvanicRifle",
			mod_data         = "M1GalvanicRifle/scripts/mods/M1GalvanicRifle/M1GalvanicRifle_data",
			mod_localization = "M1GalvanicRifle/scripts/mods/M1GalvanicRifle/M1GalvanicRifle_localization",
		})
	end,
	packages = {},
}
