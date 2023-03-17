local mod = get_mod("PsykaniumDefaultDifficulty")

return {
	name = "PsykaniumDefaultDifficulty",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "default_difficulty",
				type = "numeric",
				default_value = 3,
				range = {1, 5},
			},
		}
	}
}
