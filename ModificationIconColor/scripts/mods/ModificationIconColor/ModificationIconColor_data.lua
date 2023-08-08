local mod = get_mod("ModificationIconColor")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "opt_modified",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_modified_r",
						type = "numeric",
						default_value = 216,
						range = {0, 255},
					},
					{
						setting_id = "opt_modified_g",
						type = "numeric",
						default_value = 229,
						range = {0, 255},
					},
					{
						setting_id = "opt_modified_b",
						type = "numeric",
						default_value = 207,
						range = {0, 255},
					},
				},
			},
			{
				setting_id = "opt_locked",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_locked_r",
						type = "numeric",
						default_value = 255,
						range = {0, 255},
					},
					{
						setting_id = "opt_locked_g",
						type = "numeric",
						default_value = 54,
						range = {0, 255},
					},
					{
						setting_id = "opt_locked_b",
						type = "numeric",
						default_value = 36,
						range = {0, 255},
					},
				},
			},
		}
	}
}
