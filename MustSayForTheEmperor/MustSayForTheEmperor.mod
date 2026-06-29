return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MustSayForTheEmperor` encountered an error loading the Darktide Mod Framework.")

		new_mod("MustSayForTheEmperor", {
			mod_script       = "MustSayForTheEmperor/scripts/mods/MustSayForTheEmperor/MustSayForTheEmperor",
			mod_data         = "MustSayForTheEmperor/scripts/mods/MustSayForTheEmperor/MustSayForTheEmperor_data",
			mod_localization = "MustSayForTheEmperor/scripts/mods/MustSayForTheEmperor/MustSayForTheEmperor_localization",
		})
	end,
	packages = {},
}
