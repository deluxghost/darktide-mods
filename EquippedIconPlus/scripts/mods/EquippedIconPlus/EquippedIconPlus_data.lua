local mod = get_mod("EquippedIconPlus")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "opt_active_color",
				type = "color",
				default_value = { 255, 50, 245, 50 },
			},
			{
				setting_id = "opt_inactive_color",
				type = "color",
				default_value = { 255, 230, 180, 20 },
			},
		}
	}
}
