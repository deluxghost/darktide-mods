local mod = get_mod("ScoreboardExplosive")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "explosive_ignited",
				type = "checkbox",
				default_value = true,
			},
		},
	},
}
