local mod = get_mod("SoloPlayStratagems")

local slot_options = {
	{
		text = "stratagem_none",
		value = "none",
	},
}
for _, template in ipairs(mod.templates.stratagems) do
	local pocketable = template.pocketable
	if pocketable ~= "" then
		slot_options[#slot_options + 1] = {
			text = "loc_stratagem_" .. pocketable,
			value = pocketable,
		}
	end
end

local stratagem_slot_widgets = {}
for index = 1, mod.templates.MAX_ACTIVE_STRATAGEMS do
	stratagem_slot_widgets[#stratagem_slot_widgets + 1] = {
		setting_id = "stratagem_slot_" .. index,
		type = "dropdown",
		default_value = mod.templates.default_stratagems[index],
		options = table.clone(slot_options),
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "group_stratagem_controls",
				type = "group",
				sub_widgets = {
					{
						setting_id = "stratagem_menu_keybind",
						type = "keybind",
						default_value = { "left alt" },
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "keybind_stratagem_menu",
					},
					{
						setting_id = "stratagem_menu_hold_mode",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "group_stratagems",
				type = "group",
				title = "stratagem_menu_title",
				sub_widgets = stratagem_slot_widgets,
			},
		},
	},
}
