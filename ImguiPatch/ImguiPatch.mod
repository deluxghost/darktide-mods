return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ImguiPatch` encountered an error loading the Darktide Mod Framework.")

		new_mod("ImguiPatch", {
			mod_script       = "ImguiPatch/scripts/mods/ImguiPatch/ImguiPatch",
			mod_data         = "ImguiPatch/scripts/mods/ImguiPatch/ImguiPatch_data",
			mod_localization = "ImguiPatch/scripts/mods/ImguiPatch/ImguiPatch_localization",
		})
	end,
	packages = {},
	version = "1.0.1",
	author = "deluxghost",
}
