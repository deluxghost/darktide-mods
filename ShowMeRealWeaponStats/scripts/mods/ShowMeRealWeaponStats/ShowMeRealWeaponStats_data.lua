local mod = get_mod("ShowMeRealWeaponStats")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "group_value_override",
				type = "group",
				sub_widgets = {
					{
						setting_id = "max_modifier_score",
						type = "numeric",
						default_value = 80,
						range = { 0, 100 },
						decimals_number = 0,
					},
					{
						setting_id = "max_dump_modifier_score",
						type = "numeric",
						default_value = 60,
						range = { 0, 100 },
						decimals_number = 0,
					},
				},
			},
			{
				setting_id = "group_inspect_view",
				type = "group",
				sub_widgets = {
					{
						setting_id = "current_substats_display_mode",
						type = "dropdown",
						default_value = "current",
						options = {
							{
								text = "current_substats_display_mode_default",
								value = "current",
							},
							{
								text = "current_substats_display_mode_potential",
								value = "potential",
							},
						},
					},
					{
						setting_id = "substats_range_display_mode",
						type = "dropdown",
						default_value = "0_80",
						options = {
							{
								text = "substats_range_display_mode_0_100",
								value = "0_100",
							},
							{
								text = "substats_range_display_mode_0_80",
								value = "0_80",
							},
							{
								text = "substats_range_display_mode_60_80",
								value = "60_80",
							},
						},
					},
				},
			},
			{
				setting_id = "group_weapon_card",
				type = "group",
				sub_widgets = {
					{
						setting_id = "show_full_bar",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		}
	}
}
