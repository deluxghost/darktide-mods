return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Realms` encountered an error loading the Darktide Mod Framework.")

		new_mod("Realms", {
			mod_script       = "Realms/scripts/mods/Realms/Realms",
			mod_data         = "Realms/scripts/mods/Realms/Realms_data",
			mod_localization = "Realms/scripts/mods/Realms/Realms_localization",
		})
	end,
	packages = {
		"packages/ui/views/loading_view/loading_view",
		"packages/ui/views/loading_view/loading_screen_background",
	},
}
