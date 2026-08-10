return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LuaExec` encountered an error loading the Darktide Mod Framework.")

		new_mod("LuaExec", {
			mod_script = "LuaExec/scripts/mods/LuaExec/LuaExec",
			mod_data = "LuaExec/scripts/mods/LuaExec/LuaExec_data",
			mod_localization = "LuaExec/scripts/mods/LuaExec/LuaExec_localization",
		})
	end,
	packages = {},
	version = "2.0.1",
	author = "deluxghost",
}
