return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Reconnect` encountered an error loading the Darktide Mod Framework.")

		new_mod("Reconnect", {
			mod_script       = "Reconnect/scripts/mods/Reconnect/Reconnect",
			mod_data         = "Reconnect/scripts/mods/Reconnect/Reconnect_data",
			mod_localization = "Reconnect/scripts/mods/Reconnect/Reconnect_localization",
		})
	end,
	packages = {},
}
