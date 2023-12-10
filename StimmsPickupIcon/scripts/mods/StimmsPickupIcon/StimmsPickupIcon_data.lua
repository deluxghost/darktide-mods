local mod = get_mod("StimmsPickupIcon")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "show_pickup_color",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_team_panel_color",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_self_weapon_color",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "use_recolor_stimms_mod",
				type = "checkbox",
				default_value = false,
			},
		}
	}
}
