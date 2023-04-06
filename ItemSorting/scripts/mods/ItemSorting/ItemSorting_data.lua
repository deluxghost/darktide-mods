local mod = get_mod("ItemSorting")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "remember_sort_index",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "group_custom_sort",
				type = "group",
				sub_widgets = {
					{
						setting_id = "custom_sort_category",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "custom_sort_rarity",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "custom_sort_base_level",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		}
	}
}
