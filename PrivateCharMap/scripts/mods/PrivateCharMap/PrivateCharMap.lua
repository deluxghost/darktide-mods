local mod = get_mod("PrivateCharMap")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")

mod:add_require_path("PrivateCharMap/scripts/mods/PrivateCharMap/private_char_map_view/private_char_map_view")
mod:register_view({
	view_name = "private_char_map_view",
	view_settings = {
		init_view_function = function (ingame_ui_context)
			return true
		end,
		state_bound = true,
		path = "PrivateCharMap/scripts/mods/PrivateCharMap/private_char_map_view/private_char_map_view",
		class = "PrivateCharMapView",
		disable_game_world = false,
		load_always = true,
		load_in_hub = true,
		game_world_blur = 1.1,
		enter_sound_events = {
			UISoundEvents.system_menu_enter,
		},
		exit_sound_events = {
			UISoundEvents.system_menu_exit,
		},
		wwise_states = {
			options = WwiseGameSyncSettings.state_groups.options.ingame_menu,
		},
		context = {
			use_item_categories = false,
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

mod:command("charmap", mod:localize("cmd_open_char_map"), function ()
	if not Managers.ui:view_instance("private_char_map_view") then
		Managers.ui:open_view("private_char_map_view", nil, nil, nil, nil, {})
	end
end)
