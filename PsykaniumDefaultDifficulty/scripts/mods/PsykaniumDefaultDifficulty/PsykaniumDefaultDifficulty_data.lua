local mod = get_mod("PsykaniumDefaultDifficulty")

return {
	name = "PsykaniumDefaultDifficulty",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "default_difficulty",
				type = "numeric",
				default_value = 3,
				range = {1, 5},
			},
			{
				setting_id = "interact_psykanium_option",
				type = "dropdown",
				default_value = 1,
				options = {
					{text = "opt_no_auto_join", value = 1, show_widgets = {}},
					{text = "opt_auto_choose", value = 2, show_widgets = {}},
					{text = "opt_auto_join", value = 3, show_widgets = {}},
				}
			},
		}
	}
}
