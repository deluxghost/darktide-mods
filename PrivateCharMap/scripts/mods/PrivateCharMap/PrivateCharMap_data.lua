local mod = get_mod("PrivateCharMap")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "open_private_char_map",
				type = "button",
				button_text = "open",
				function_name = "open_private_char_map",
			},
		}
	}
}
