return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ChatFix` encountered an error loading the Darktide Mod Framework.")

		new_mod("ChatFix", {
			mod_script       = "ChatFix/scripts/mods/ChatFix/ChatFix",
			mod_data         = "ChatFix/scripts/mods/ChatFix/ChatFix_data",
			mod_localization = "ChatFix/scripts/mods/ChatFix/ChatFix_localization",
		})
	end,
	packages = {},
}
