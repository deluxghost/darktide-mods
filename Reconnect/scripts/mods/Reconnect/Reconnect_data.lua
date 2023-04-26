local mod = get_mod("Reconnect")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "handle_rejoin_popup",
				type = "dropdown",
				default_value = "none",
				options = {
					{text = "opt_do_nothing", value = "none", show_widgets = {}},
					{text = "opt_auto_rejoin", value = "rejoin", show_widgets = {}},
					{text = "opt_auto_leave", value = "leave", show_widgets = {}},
				}
			},
			{
				setting_id      = "retry_keybind",
				type            = "keybind",
				default_value   = {},
				keybind_trigger = "pressed",
				keybind_type    = "function_call",
				function_name   = "retry_keybind_func",
			},
		}
	}
}
