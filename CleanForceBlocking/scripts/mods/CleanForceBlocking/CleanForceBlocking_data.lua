local mod = get_mod("CleanForceBlocking")

return {
	name = "CleanForceBlocking",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "remove_blocking_sound",
				type = "checkbox",
				default_value = false,
			},
		}
	}
}
