local mod = get_mod("Realms")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")
local ViewPackages = mod:io_dofile("Realms/scripts/mods/Realms/views/view_packages")

local VIEW_NAME = "realms_join_view"
local VIEW_PATH = "Realms/scripts/mods/Realms/views/join_view/join_view"

mod:add_require_path(VIEW_PATH)
mod:register_view({
	view_name = VIEW_NAME,
	view_settings = {
		class = "RealmsJoinView",
		disable_game_world = true,
		game_world_blur = 1.1,
		init_view_function = function ()
			return true
		end,
		load_always = true,
		load_in_hub = true,
		package = ViewPackages.for_view("join"),
		path = VIEW_PATH,
		throttle_frame_rate = false,
		use_transition_ui = true,
		enter_sound_events = {
			UISoundEvents.system_menu_enter,
		},
		exit_sound_events = {
			UISoundEvents.system_menu_exit,
		},
		wwise_states = {
			options = WwiseGameSyncSettings.state_groups.options.ingame_menu,
		},
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod.open_join_view = function ()
	if not Managers.ui:view_instance(VIEW_NAME) then
		Managers.ui:open_view(VIEW_NAME, nil, nil, nil, nil, {})
	end
end
