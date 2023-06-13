return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ManyMoreTry` encountered an error loading the Darktide Mod Framework.")

		new_mod("ManyMoreTry", {
			mod_script       = "ManyMoreTry/scripts/mods/ManyMoreTry/ManyMoreTry",
			mod_data         = "ManyMoreTry/scripts/mods/ManyMoreTry/ManyMoreTry_data",
			mod_localization = "ManyMoreTry/scripts/mods/ManyMoreTry/ManyMoreTry_localization",
		})
	end,
	packages = {},
}
