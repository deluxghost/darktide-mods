local mod = get_mod("DifficultyColor")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "opt_color_1",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_color_1_r",
						type = "numeric",
						default_value = 169,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_1_g",
						type = "numeric",
						default_value = 211,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_1_b",
						type = "numeric",
						default_value = 158,
						range = {0, 255},
					},
				},
			},
			{
				setting_id = "opt_color_2",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_color_2_r",
						type = "numeric",
						default_value = 169,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_2_g",
						type = "numeric",
						default_value = 211,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_2_b",
						type = "numeric",
						default_value = 158,
						range = {0, 255},
					},
				},
			},
			{
				setting_id = "opt_color_3",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_color_3_r",
						type = "numeric",
						default_value = 228,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_3_g",
						type = "numeric",
						default_value = 189,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_3_b",
						type = "numeric",
						default_value = 81,
						range = {0, 255},
					},
				},
			},
			{
				setting_id = "opt_color_4",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_color_4_r",
						type = "numeric",
						default_value = 228,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_4_g",
						type = "numeric",
						default_value = 189,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_4_b",
						type = "numeric",
						default_value = 81,
						range = {0, 255},
					},
				},
			},
			{
				setting_id = "opt_color_5",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_color_5_r",
						type = "numeric",
						default_value = 233,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_5_g",
						type = "numeric",
						default_value = 84,
						range = {0, 255},
					},
					{
						setting_id = "opt_color_5_b",
						type = "numeric",
						default_value = 84,
						range = {0, 255},
					},
				},
			},
		}
	}
}
