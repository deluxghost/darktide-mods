return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MyFavorites` encountered an error loading the Darktide Mod Framework.")

		new_mod("MyFavorites", {
			mod_script       = "MyFavorites/scripts/mods/MyFavorites/MyFavorites",
			mod_data         = "MyFavorites/scripts/mods/MyFavorites/MyFavorites_data",
			mod_localization = "MyFavorites/scripts/mods/MyFavorites/MyFavorites_localization",
		})
	end,
	packages = {},
}
