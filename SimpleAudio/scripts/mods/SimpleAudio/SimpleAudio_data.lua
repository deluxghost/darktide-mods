local mod = get_mod("SimpleAudio")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "log_wwise",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "log_wwise_ui",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "log_wwise_common",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "log_silenced",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "log_wwise_verbose",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "log_to_chat",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}
