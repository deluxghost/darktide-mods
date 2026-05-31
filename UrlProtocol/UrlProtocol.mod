return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`UrlProtocol` encountered an error loading the Darktide Mod Framework.")

		new_mod("UrlProtocol", {
			mod_script       = "UrlProtocol/scripts/mods/UrlProtocol/UrlProtocol",
			mod_data         = "UrlProtocol/scripts/mods/UrlProtocol/UrlProtocol_data",
			mod_localization = "UrlProtocol/scripts/mods/UrlProtocol/UrlProtocol_localization",
		})
	end,
	packages = {},
}
