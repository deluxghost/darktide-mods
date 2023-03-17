return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PsykaniumInvHotkey` encountered an error loading the Darktide Mod Framework.")

		new_mod("PsykaniumInvHotkey", {
			mod_script       = "PsykaniumInvHotkey/scripts/mods/PsykaniumInvHotkey/PsykaniumInvHotkey",
			mod_data         = "PsykaniumInvHotkey/scripts/mods/PsykaniumInvHotkey/PsykaniumInvHotkey_data",
			mod_localization = "PsykaniumInvHotkey/scripts/mods/PsykaniumInvHotkey/PsykaniumInvHotkey_localization",
		})
	end,
	packages = {},
}
