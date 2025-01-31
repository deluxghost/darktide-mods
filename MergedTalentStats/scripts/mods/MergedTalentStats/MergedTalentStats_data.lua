local mod = get_mod("MergedTalentStats")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "show_stats_on_top",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}
