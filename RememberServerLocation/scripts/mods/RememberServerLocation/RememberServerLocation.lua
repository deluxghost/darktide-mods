local mod = get_mod("RememberServerLocation")
local MissionBoardView = require("scripts/ui/views/mission_board_view_pj/mission_board_view")
local HordePlayView = require("scripts/ui/views/horde_play_view/horde_play_view")
local BackendUtilities = require("scripts/foundation/managers/backend/utilities/backend_utilities")
local Promise = require("scripts/foundation/utilities/promise")
local RegionLocalizationMappings = require("scripts/settings/backend/region_localization")

mod.memory = mod:persistent_table("memory")

local function save_region()
	if BackendUtilities.prefered_mission_region ~= "" then
		mod:info("save server region " .. (BackendUtilities.prefered_mission_region or ""))
		mod:set("saved_server_location", BackendUtilities.prefered_mission_region)
	end
end

local function fetch_regions()
	Promise.until_true(function ()
		return Managers.backend:authenticated()
	end):next(function ()
		mod:info("start fetching regions")
		local region_promise = Managers.backend.interfaces.region_latency:get_region_latencies()
		region_promise:next(function (regions_data)
			local prefered_region_promise = Managers.backend.interfaces.region_latency:get_preferred_reef()
			prefered_region_promise:next(function (prefered_region)
				local prefered_mission_region = prefered_region or regions_data[1].reefs[1] or ""
				local regions_latency = Managers.backend.interfaces.region_latency:get_reef_info_based_on_region_latencies(regions_data)
				mod:dump(regions_latency, "rsl_regions_latency", 3)
				mod.memory.regions_latency = regions_latency
				if mod:is_enabled() then
					local saved_server_location = mod:get("saved_server_location")
					if saved_server_location then
						if regions_latency[saved_server_location] then
							prefered_mission_region = saved_server_location
							mod:info("load server region " .. saved_server_location)
						end
					end
					BackendUtilities.prefered_mission_region = prefered_mission_region
					mod:info("apply server region " .. prefered_mission_region)
					save_region()
				end
			end)
		end)
	end)
end

mod.on_all_mods_loaded = function ()
	local saved_server_location = mod:get("saved_server_location") or ""
	if not RegionLocalizationMappings[saved_server_location] then
		mod:info("clear unknown server region " .. saved_server_location)
		saved_server_location = ""
		mod:set("saved_server_location", saved_server_location)
	end
	BackendUtilities.prefered_mission_region = saved_server_location
	if not mod.memory.regions_latency then
		fetch_regions()
	end

	local mod_loading = true
	mod:hook_require("scripts/ui/views/havoc_play_view/havoc_play_view", function (HavocPlayView)
		if mod_loading then
			mod:hook_safe(HavocPlayView, "on_exit", function (self)
				mod:info("exit havoc view")
				save_region()
			end)

			mod:hook_safe(HavocPlayView, "_callback_close_options", function (self)
				mod:info("exit havoc view options")
				save_region()
			end)
			mod_loading = false
		end
	end)
end

mod:hook_safe(MissionBoardView, "on_exit", function (self)
	mod:info("exit mission board")
	save_region()
end)

mod:hook_safe(MissionBoardView, "_destroy_options_element", function (self)
	mod:info("exit mission board options")
	save_region()
end)

mod:hook_safe(HordePlayView, "on_exit", function (self)
	mod:info("exit horde view")
	save_region()
end)

mod:hook_safe(HordePlayView, "_callback_close_options", function (self)
	mod:info("exit horde view options")
	save_region()
end)
