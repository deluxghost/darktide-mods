local mod = get_mod("ColorViewer")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "open_color_viewer",
				type = "button",
				button_text = "open",
				function_name = "open_color_viewer",
			},
		}
	}
}
