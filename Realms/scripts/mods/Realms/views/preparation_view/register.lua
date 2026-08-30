local mod = get_mod("Realms")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")
local ViewPackages = mod:io_dofile("Realms/scripts/mods/Realms/views/view_packages")

mod:add_require_path("Realms/scripts/mods/Realms/views/preparation_view/preparation_view")
mod:register_view({
	view_name = "realms_preparation_view",
	view_settings = {
		class = "RealmsPreparationView",
		disable_game_world = true,
		game_world_blur = 1.1,
		init_view_function = function ()
			return true
		end,
		load_always = true,
		load_in_hub = true,
		package = ViewPackages.for_view("preparation"),
		path = "Realms/scripts/mods/Realms/views/preparation_view/preparation_view",
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
})
