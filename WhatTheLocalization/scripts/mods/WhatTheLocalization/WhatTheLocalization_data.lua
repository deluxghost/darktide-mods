local mod = get_mod("WhatTheLocalization")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "enable_debug_mode",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "toggle_debug_mode",
				type = "keybind",
				default_value = {},
				keybind_global = true,
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "toggle_debug_mode",
			},
			{
				setting_id = "loc_command_output_visualize",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}
