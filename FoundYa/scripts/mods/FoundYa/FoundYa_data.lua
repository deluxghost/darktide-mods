local mod = get_mod("FoundYa")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "max_tag_distance",
				type = "numeric",
				default_value = 15,
				range = {10, 80},
			},
			{
				setting_id = "max_distance",
				type = "group",
				sub_widgets = {
					{
						setting_id = "max_distance_supply",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_chest",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_button",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_station",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_luggable",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_vendor",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_book",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_material",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
				},
			},
		}
	}
}
