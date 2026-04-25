local mod = get_mod("SoloPlayStratagems")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "group_stratagem_controls",
				type = "group",
				sub_widgets = {
					{
						setting_id = "stratagem_menu_keybind",
						type = "keybind",
						default_value = { "left alt" },
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "keybind_stratagem_menu",
					},
					{
						setting_id = "stratagem_menu_hold_mode",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		},
	},
}
