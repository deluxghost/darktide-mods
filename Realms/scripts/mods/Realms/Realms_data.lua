local mod = get_mod("Realms")

local function validate_listen_port(value)
	if value == "" then
		return true
	end

	local port = string.match(value, "^%d+$") and tonumber(value)

	return port ~= nil and port >= 1 and port <= 65535
end

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
				setting_id = "hide_join_server_address",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "server_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_server",
						type = "checkbox",
						default_value = true,
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
						setting_id = "listen_port",
						type = "text",
						default_value = "",
						validate = validate_listen_port,
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
			{
				setting_id = "shooting_range_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "shooting_range_sync_invulnerability",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "shooting_range_sync_invisibility",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "shooting_range_sync_sound_muffling",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		},
	},
}
