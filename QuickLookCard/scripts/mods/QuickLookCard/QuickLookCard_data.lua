local mod = get_mod("QuickLookCard")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "opt_modifier_mode",
				type = "dropdown",
				default_value = "current",
				options = {
					{
						text = "opt_modifier_mode_current",
						value = "current",
					},
					{
						text = "opt_modifier_mode_potential",
						value = "potential",
					},
				},
			},
			{
				setting_id = "opt_highlight_dump_stat",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "opt_group_toggles",
				type = "group",
				sub_widgets = {
					{
						setting_id = "opt_base_level",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "opt_modifier",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "opt_blessing",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "opt_perk",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "opt_curio_blessing",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "opt_curio_perk",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		}
	}
}
