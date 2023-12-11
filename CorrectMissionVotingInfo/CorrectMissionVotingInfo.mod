return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`CorrectMissionVotingInfo` encountered an error loading the Darktide Mod Framework.")

		new_mod("CorrectMissionVotingInfo", {
			mod_script       = "CorrectMissionVotingInfo/scripts/mods/CorrectMissionVotingInfo/CorrectMissionVotingInfo",
			mod_data         = "CorrectMissionVotingInfo/scripts/mods/CorrectMissionVotingInfo/CorrectMissionVotingInfo_data",
			mod_localization = "CorrectMissionVotingInfo/scripts/mods/CorrectMissionVotingInfo/CorrectMissionVotingInfo_localization",
		})
	end,
	packages = {},
}
