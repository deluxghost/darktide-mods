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
				setting_id = "alter_icons",
				type = "group",
				sub_widgets = {
					{
						setting_id = "alter_chest_icon",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "alter_luggable_icon",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "alter_large_ammo_icon",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "alter_skull_icon",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "max_distance",
				type = "group",
				sub_widgets = {
					{
						setting_id = "max_distance_material",
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
						setting_id = "max_distance_device",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_penance",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_event",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
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
						setting_id = "max_distance_luggable",
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
						setting_id = "max_distance_vendor",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
					{
						setting_id = "max_distance_unknown",
						type = "numeric",
						default_value = 15,
						range = {10, 80},
					},
				},
			},
		}
	}
}
