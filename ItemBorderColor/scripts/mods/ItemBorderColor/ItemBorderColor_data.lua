local mod = get_mod("ItemBorderColor")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "opt_selected_color",
				type = "color",
				default_value = { 255, 250, 189, 73 },
			},
		}
	}
}
