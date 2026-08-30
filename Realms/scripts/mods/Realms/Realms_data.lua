local mod = get_mod("Realms")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "join_server",
				type = "button",
				button_text = "join_server_button",
				button_trigger = "pressed",
				function_name = "open_join_view",
			},
			{
				setting_id = "mission_preparation",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "private_mode",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "max_players",
				type = "numeric",
				default_value = 4,
				range = {2, 8},
			},
			{
				setting_id = "bot_fill_target",
				type = "numeric",
				default_value = 4,
				range = {1, 8},
			},
			{
				setting_id = "server_password",
				type = "text",
				default_value = "",
				validate = function (value)
					return #value <= 1024 and string.find(value, "%s") == nil
				end,
			},
		},
	},
}
