local mod = get_mod("ItemSorting")

return {
	name = "ItemSorting",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "add_extra_sort",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "remember_sort_index",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}
