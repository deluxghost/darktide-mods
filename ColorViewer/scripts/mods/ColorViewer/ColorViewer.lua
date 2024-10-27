local mod = get_mod("ColorViewer")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")

mod.argb_to_hex = function(color)
	local a, r, g, b = color[1], color[2], color[3], color[4]
	return string.format("#%02X%02X%02X%02X", a, r, g, b)
end

mod:add_require_path("ColorViewer/scripts/mods/ColorViewer/color_viewer_view/color_viewer_view")
mod:register_view({
	view_name = "color_viewer_view",
	view_settings = {
		init_view_function = function(ingame_ui_context)
			return true
		end,
		state_bound = true,
		path = "ColorViewer/scripts/mods/ColorViewer/color_viewer_view/color_viewer_view",
		class = "ColorViewerView",
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

mod:command("colorview", mod:localize("cmd_open_color_viewer"), function()
	if not Managers.ui:view_instance("color_viewer_view") then
		Managers.ui:open_view("color_viewer_view", nil, nil, nil, nil, {})
	end
end)
