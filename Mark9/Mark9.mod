return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Mark9` encountered an error loading the Darktide Mod Framework.")

		new_mod("Mark9", {
			mod_script       = "Mark9/scripts/mods/Mark9/Mark9",
			mod_data         = "Mark9/scripts/mods/Mark9/Mark9_data",
			mod_localization = "Mark9/scripts/mods/Mark9/Mark9_localization",
		})
	end,
	packages = {},
}
