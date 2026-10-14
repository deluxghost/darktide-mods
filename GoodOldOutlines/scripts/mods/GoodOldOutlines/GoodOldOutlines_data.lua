local mod = get_mod("GoodOldOutlines")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "hide_mesh",
				type = "checkbox",
				default_value = true,
				tooltip = "hide_mesh_description",
			},
			{
				setting_id = "highlight_tagged_items",
				type = "checkbox",
				default_value = true,
				tooltip = "highlight_tagged_items_description",
				sub_widgets = {
					{
						setting_id = "item_outline_color",
						type = "color",
						default_value = { 255, 0, 255, 255 },
						has_alpha = false,
					},
				},
			},
		},
	},
}
