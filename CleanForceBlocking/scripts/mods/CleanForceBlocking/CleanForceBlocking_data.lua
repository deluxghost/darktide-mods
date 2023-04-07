local mod = get_mod("CleanForceBlocking")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "remove_blocking_effect",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "remove_pushing_effect",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "remove_push_attack_effect",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "remove_blocking_sound",
				type = "checkbox",
				default_value = false,
			},
		}
	}
}
