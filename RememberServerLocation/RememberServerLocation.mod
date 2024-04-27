return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`RememberServerLocation` encountered an error loading the Darktide Mod Framework.")

		new_mod("RememberServerLocation", {
			mod_script       = "RememberServerLocation/scripts/mods/RememberServerLocation/RememberServerLocation",
			mod_data         = "RememberServerLocation/scripts/mods/RememberServerLocation/RememberServerLocation_data",
			mod_localization = "RememberServerLocation/scripts/mods/RememberServerLocation/RememberServerLocation_localization",
		})
	end,
	packages = {},
}
