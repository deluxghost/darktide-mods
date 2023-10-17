local mod = get_mod("ShowMeRealWeaponStats")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "show_full_bar",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_real_max_breakdown",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}
