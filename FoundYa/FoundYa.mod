return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`FoundYa` encountered an error loading the Darktide Mod Framework.")

		new_mod("FoundYa", {
			mod_script       = "FoundYa/scripts/mods/FoundYa/FoundYa",
			mod_data         = "FoundYa/scripts/mods/FoundYa/FoundYa_data",
			mod_localization = "FoundYa/scripts/mods/FoundYa/FoundYa_localization",
		})
	end,
	packages = {},
}
