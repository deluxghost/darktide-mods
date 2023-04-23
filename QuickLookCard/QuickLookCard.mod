return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`QuickLookCard` encountered an error loading the Darktide Mod Framework.")

		new_mod("QuickLookCard", {
			mod_script       = "QuickLookCard/scripts/mods/QuickLookCard/QuickLookCard",
			mod_data         = "QuickLookCard/scripts/mods/QuickLookCard/QuickLookCard_data",
			mod_localization = "QuickLookCard/scripts/mods/QuickLookCard/QuickLookCard_localization",
		})
	end,
	packages = {},
}
