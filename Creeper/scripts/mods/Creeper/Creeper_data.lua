local mod = get_mod("Creeper")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{ setting_id = "enable_alarm", type = "checkbox", default_value = true },
			{ setting_id = "replace_fuse_sound", type = "checkbox", default_value = true },
			{ setting_id = "replace_explosion_sound", type = "checkbox", default_value = true },
		},
	},
}
