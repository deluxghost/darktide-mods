local mod = get_mod("ItemSorting")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "group_always_on_top",
				type = "group",
				sub_widgets = {
					{
						setting_id = "always_on_top_curio",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "always_on_top_new",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "always_on_top_equipped",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "always_on_top_myfav",
						type = "checkbox",
						default_value = false,
					},
				},
			},
			{
				setting_id = "group_always_on_top_options",
				type = "group",
				sub_widgets = {
					{
						setting_id = "entire_category_on_top",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "on_top_of_category",
						type = "checkbox",
						default_value = true,
					},
				},
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
						setting_id = "custom_sort_category_mark",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "custom_sort_base_level_desc",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "custom_sort_base_level_asc",
						type = "checkbox",
						default_value = false,
					},
				},
			},
			{
				setting_id = "group_enable_vanilla_sort",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_vanilla_level_desc",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_vanilla_level_asc",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "enable_vanilla_rarity_desc",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_vanilla_rarity_asc",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "enable_vanilla_price_asc",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "enable_vanilla_price_desc",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "enable_vanilla_name_asc",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_vanilla_name_desc",
						type = "checkbox",
						default_value = false,
					},
				},
			},
		}
	}
}
