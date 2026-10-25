return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SimpleAudio` encountered an error loading the Darktide Mod Framework.")

		new_mod("SimpleAudio", {
			mod_script       = "SimpleAudio/scripts/mods/SimpleAudio/SimpleAudio",
			mod_data         = "SimpleAudio/scripts/mods/SimpleAudio/SimpleAudio_data",
			mod_localization = "SimpleAudio/scripts/mods/SimpleAudio/SimpleAudio_localization",
		})
	end,
	packages = {},
}
