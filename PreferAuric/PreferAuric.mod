return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PreferAuric` encountered an error loading the Darktide Mod Framework.")

		new_mod("PreferAuric", {
			mod_script       = "PreferAuric/scripts/mods/PreferAuric/PreferAuric",
			mod_data         = "PreferAuric/scripts/mods/PreferAuric/PreferAuric_data",
			mod_localization = "PreferAuric/scripts/mods/PreferAuric/PreferAuric_localization",
		})
	end,
	packages = {},
}
