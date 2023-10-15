local mod = get_mod("ItemBorderColor")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "opt_selected_color",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_selected_r",
						type = "numeric",
						default_value = 250,
						range = {0, 255},
					},
					{
						setting_id = "opt_selected_g",
						type = "numeric",
						default_value = 189,
						range = {0, 255},
					},
					{
						setting_id = "opt_selected_b",
						type = "numeric",
						default_value = 73,
						range = {0, 255},
					},
				},
			},
		}
	}
}
