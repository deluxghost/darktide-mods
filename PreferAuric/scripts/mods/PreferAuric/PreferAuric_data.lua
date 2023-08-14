local mod = get_mod("PreferAuric")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "mission_board_preference",
				type = "dropdown",
				default_value = "_last_selection",
				options = {
					{ text = "mission_board__last_selection", value = "_last_selection", show_widgets = {} },
					{ text = "mission_board_normal", value = "normal", show_widgets = {} },
					{ text = "mission_board_auric", value = "auric", show_widgets = {} },
				},
			},
		}
	}
}
