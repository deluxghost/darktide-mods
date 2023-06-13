local mod = get_mod("ManyMoreTry")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "private_game",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}
