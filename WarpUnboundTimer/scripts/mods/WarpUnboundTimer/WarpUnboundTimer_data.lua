local mod = get_mod("WarpUnboundTimer")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "hud_scale",
				type = "numeric",
				default_value = 1.0,
				range = { 1.0, 3.0 },
				decimals_number = 1,
			},
		}
	}
}
