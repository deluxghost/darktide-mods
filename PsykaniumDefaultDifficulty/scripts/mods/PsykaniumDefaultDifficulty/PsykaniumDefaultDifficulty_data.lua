local mod = get_mod("PsykaniumDefaultDifficulty")

return {
	name = mod:localize("mod_name"),
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
				setting_id = "auto_select",
				type = "dropdown",
				default_value = "none",
				options = {
					{text = "opt_no_auto_select", value = "none", show_widgets = {}},
					{text = "opt_auto_horde", value = "horde", show_widgets = {}},
					{text = "opt_auto_shootingrange", value = "shootingrange", show_widgets = {}},
					{text = "opt_auto_shootingrange_skip", value = "shootingrange_skip", show_widgets = {}},
				}
			},
		}
	}
}
