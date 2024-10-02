local mod = get_mod("ShowMeRealWeaponStats")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "max_modifier_score",
				type = "numeric",
				default_value = 80,
				range = {0, 100},
				decimals_number = 0
			},
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
			{
				setting_id = "show_potential_breakdown",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}
