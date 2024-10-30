return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SimpleSpeedMeter` encountered an error loading the Darktide Mod Framework.")

		new_mod("SimpleSpeedMeter", {
			mod_script       = "SimpleSpeedMeter/scripts/mods/SimpleSpeedMeter/SimpleSpeedMeter",
			mod_data         = "SimpleSpeedMeter/scripts/mods/SimpleSpeedMeter/SimpleSpeedMeter_data",
			mod_localization = "SimpleSpeedMeter/scripts/mods/SimpleSpeedMeter/SimpleSpeedMeter_localization",
		})
	end,
	packages = {},
}
