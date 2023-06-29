local mod = get_mod("OpenPlayerProfile")

local data = {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
}

if HAS_STEAM then
	data.options = {
		widgets = {
			{
				setting_id = "use_steam_overlay",
				type = "checkbox",
				default_value = true,
			},
		}
	}
end

return data
