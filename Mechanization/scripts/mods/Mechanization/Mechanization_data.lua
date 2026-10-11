local mod = get_mod("Mechanization")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "enabled",
				type = "checkbox",
				default_value = true,
			},
		},
	},
}
