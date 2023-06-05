local mod = get_mod("OpenSteamProfile")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "use_steam_overlay",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}
