local mod = get_mod("ChatFix")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "chat_join_leave_fix",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "chat_inactivity_timeout",
				type = "numeric",
				default_value = 10,
				range = {5, 50},
			},
			{
				setting_id = "chat_scroll_multiplier",
				type = "numeric",
				default_value = 1,
				range = {0.5, 3},
				decimals_number = 1,
			},
		}
	}
}
