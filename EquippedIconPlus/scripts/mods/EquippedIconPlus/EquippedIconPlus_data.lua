local mod = get_mod("EquippedIconPlus")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "opt_active_color",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_active_r",
						type = "numeric",
						default_value = 50,
						range = {0, 255},
					},
					{
						setting_id = "opt_active_g",
						type = "numeric",
						default_value = 245,
						range = {0, 255},
					},
					{
						setting_id = "opt_active_b",
						type = "numeric",
						default_value = 50,
						range = {0, 255},
					},
				},
			},
			{
				setting_id = "opt_inactive_color",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_inactive_r",
						type = "numeric",
						default_value = 230,
						range = {0, 255},
					},
					{
						setting_id = "opt_inactive_g",
						type = "numeric",
						default_value = 180,
						range = {0, 255},
					},
					{
						setting_id = "opt_inactive_b",
						type = "numeric",
						default_value = 20,
						range = {0, 255},
					},
				},
			},
		}
	}
}
