local mod = get_mod("SoloPlay")
local SoloPlaySettings = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/SoloPlaySettings")

local mission_options = {}
for _, mission in ipairs(SoloPlaySettings.missions) do
	table.insert(mission_options, {
		text = mission.loc_key,
		value = mission.data,
	})
end

local side_mission_options = {
	{ text = "default_text_none", value = "default" },
}
for _, side_mission in ipairs(SoloPlaySettings.side_missions) do
	table.insert(side_mission_options, {
		text = side_mission.loc_key,
		value = side_mission.data,
	})
end

local circumstance_options = {
	{ text = "default_text_none", value = "default" },
}
for _, circumstance in ipairs(SoloPlaySettings.circumstances) do
	table.insert(circumstance_options, {
		text = circumstance.loc_key,
		value = circumstance.data,
	})
end

local mission_giver_options = {
	{ text = "default_text", value = "default" },
}
for _, mission_giver in ipairs(SoloPlaySettings.mission_givers) do
	table.insert(mission_giver_options, {
		text = mission_giver.loc_key,
		value = mission_giver.data,
	})
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "group_mission_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "choose_mission",
						type = "dropdown",
						default_value = "prologue",
						options = mission_options,
					},
					{
						setting_id = "choose_difficulty",
						type = "numeric",
						default_value = 3,
						range = { 1, 5 },
					},
					{
						setting_id = "choose_side_mission",
						type = "dropdown",
						default_value = "default",
						options = side_mission_options,
					},
					{
						setting_id = "choose_circumstance",
						type = "dropdown",
						default_value = "default",
						options = circumstance_options,
					},
					{
						setting_id = "choose_mission_giver",
						type = "dropdown",
						default_value = "default",
						options = mission_giver_options,
					},
				},
			},
			{
				setting_id = "group_modifiers",
				type = "group",
				sub_widgets = {
					{
						setting_id = "friendly_fire_enabled",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "random_side_mission_seed",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		}
	}
}

