local mod = get_mod("DifficultyColor")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "opt_color_1",
				type = "color",
				default_value = { 255, 169, 211, 158 },
			},
			{
				setting_id = "opt_color_2",
				type = "color",
				default_value = { 255, 169, 211, 158 },
			},
			{
				setting_id = "opt_color_3",
				type = "color",
				default_value = { 255, 228, 189, 81 },
			},
			{
				setting_id = "opt_color_4",
				type = "color",
				default_value = { 255, 228, 189, 81 },
			},
			{
				setting_id = "opt_color_5",
				type = "color",
				default_value = { 255, 233, 84, 84 },
			},
		}
	}
}
