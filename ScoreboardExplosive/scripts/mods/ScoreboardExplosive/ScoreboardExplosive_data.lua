local mod = get_mod("ScoreboardExplosive")

return {
	name = "ScoreboardExplosive",
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
