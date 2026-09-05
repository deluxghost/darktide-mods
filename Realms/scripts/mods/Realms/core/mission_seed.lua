local mod = get_mod("Realms")
local GameplayStateInit = require("scripts/game_states/game/gameplay_sub_states/gameplay_state_init")
local MissionTemplates = require("scripts/settings/mission/mission_templates")

local MissionSeed = {}

function MissionSeed.install(Session)
	mod:hook(GameplayStateInit, "on_enter", function (func, self, parent, params)
		local shared_state = params.shared_state

		if Session.is_active() and not GameParameters.level_seed and not MissionTemplates[shared_state.mission_name].is_hub then
			local loading_manager = Managers.loading
			local mission_seed

			if shared_state.is_server then
				mission_seed = loading_manager._loading_host._mission_seed
			else
				mission_seed = loading_manager._loading_client._shared_state.mission_seed
			end

			-- Reused connections keep their session seed, but loading generates and synchronizes a seed for each mission.
			shared_state.level_seed = assert(mission_seed, "Realms mission seed is missing during gameplay initialization")
		end

		return func(self, parent, params)
	end)
end

return MissionSeed
