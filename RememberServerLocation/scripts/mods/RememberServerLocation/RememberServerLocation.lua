local mod = get_mod("RememberServerLocation")
local MissionBoardView = require("scripts/ui/views/mission_board_view/mission_board_view")
local StoryMissionPlayView = require("scripts/ui/views/story_mission_play_view/story_mission_play_view")
local BackendUtilities = require("scripts/foundation/managers/backend/utilities/backend_utilities")
local Promise = require("scripts/foundation/utilities/promise")

mod.memory = mod:persistent_table("memory")

local function save_region()
	if BackendUtilities.prefered_mission_region ~= "" then
		mod:set("saved_server_location", BackendUtilities.prefered_mission_region)
	end
end

local function fetch_regions()
	local region_promise = Managers.backend.interfaces.region_latency:get_region_latencies()

	region_promise:next(function (regions_data)
		local prefered_region_promise = nil

		if BackendUtilities.prefered_mission_region == "" then
			prefered_region_promise = Managers.backend.interfaces.region_latency:get_preferred_reef()
		else
			prefered_region_promise = Promise.resolved()
		end

		prefered_region_promise:next(function (prefered_region)
			local prefered_mission_region = BackendUtilities.prefered_mission_region ~= "" and BackendUtilities.prefered_mission_region or prefered_region or regions_data[1].reefs[1]
			local regions_latency = Managers.backend.interfaces.region_latency:get_reef_info_based_on_region_latencies(regions_data)
			mod.memory.regions_latency = regions_latency
			if mod:is_enabled() then
				local saved_server_location = mod:get("saved_server_location")
				if saved_server_location then
					if regions_latency[saved_server_location] then
						prefered_mission_region = saved_server_location
					end
				end
				BackendUtilities.prefered_mission_region = prefered_mission_region
				save_region()
			end
		end)
	end)
end

mod.on_all_mods_loaded = function()
	if not mod.memory.regions_latency then
		fetch_regions()
	end
end

mod:hook_safe(MissionBoardView, "on_exit", function(self)
	save_region()
end)

mod:hook_safe(MissionBoardView, "_callback_close_options", function(self)
	save_region()
end)

mod:hook_safe(StoryMissionPlayView, "on_exit", function(self)
	save_region()
end)

mod:hook_safe(StoryMissionPlayView, "_callback_close_options", function(self)
	save_region()
end)
