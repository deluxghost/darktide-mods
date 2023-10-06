return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ShareTalents` encountered an error loading the Darktide Mod Framework.")

		new_mod("ShareTalents", {
			mod_script       = "ShareTalents/scripts/mods/ShareTalents/ShareTalents",
			mod_data         = "ShareTalents/scripts/mods/ShareTalents/ShareTalents_data",
			mod_localization = "ShareTalents/scripts/mods/ShareTalents/ShareTalents_localization",
		})
	end,
	packages = {},
}
