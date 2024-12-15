local mod = get_mod("SoloPlay")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "solo_keybind",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "keybind_open_solo_view",
			},
			{
				setting_id = "group_modifiers",
				type = "group",
				sub_widgets = {
					{
						setting_id = "friendly_fire_enabled",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "random_side_mission_seed",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		}
	}
}

