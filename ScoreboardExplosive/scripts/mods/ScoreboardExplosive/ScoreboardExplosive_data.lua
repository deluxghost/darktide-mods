local mod = get_mod("ScoreboardExplosive")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "option_explosive_ignited",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "option_message_explosive_ignited",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "option_message_explosive_detonated",
				type = "checkbox",
				default_value = true,
			},
		},
	},
}
