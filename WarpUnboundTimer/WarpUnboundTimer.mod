return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`WarpUnboundTimer` encountered an error loading the Darktide Mod Framework.")

		new_mod("WarpUnboundTimer", {
			mod_script       = "WarpUnboundTimer/scripts/mods/WarpUnboundTimer/WarpUnboundTimer",
			mod_data         = "WarpUnboundTimer/scripts/mods/WarpUnboundTimer/WarpUnboundTimer_data",
			mod_localization = "WarpUnboundTimer/scripts/mods/WarpUnboundTimer/WarpUnboundTimer_localization",
		})
	end,
	packages = {},
}
