local mod = get_mod("FoundYa")

return {
	name = "FoundYa",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "max_distance",
				type = "numeric",
				default_value = 15,
				range = {10, 80},
			},
			{
				setting_id = "max_tag_distance",
				type = "numeric",
				default_value = 15,
				range = {10, 80},
			},
		}
	}
}
