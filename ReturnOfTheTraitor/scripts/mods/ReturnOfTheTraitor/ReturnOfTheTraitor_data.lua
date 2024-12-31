local mod = get_mod("ReturnOfTheTraitor")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "commissary_vendor",
				type = "dropdown",
				default_value = "traitor",
				options = {
					{ text = "opt_traitor", value = "traitor" },
					{ text = "opt_servitor", value = "servitor" },
				},
			},
		}
	}
}
