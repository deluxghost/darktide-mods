local mod = get_mod("M1GalvanicRifle")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "replace_firing_sound",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "firing_sound_volume",
				type = "numeric",
				default_value = 100,
				range = {1, 200},
			},
			{
				setting_id = "replace_reload_sound",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "reload_sound_volume",
				type = "numeric",
				default_value = 100,
				range = {1, 200},
			},
			{
				setting_id = "replace_teammate_sounds",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "teammate_sound_volume",
				type = "numeric",
				default_value = 100,
				range = {1, 200},
			},
		}
	}
}
