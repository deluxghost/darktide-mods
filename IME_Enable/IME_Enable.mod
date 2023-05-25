return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`IME_Enable` encountered an error loading the Darktide Mod Framework.")

		new_mod("IME_Enable", {
			mod_script       = "IME_Enable/scripts/mods/IME_Enable/IME_Enable",
			mod_data         = "IME_Enable/scripts/mods/IME_Enable/IME_Enable_data",
			mod_localization = "IME_Enable/scripts/mods/IME_Enable/IME_Enable_localization",
		})
	end,
	packages = {},
}
