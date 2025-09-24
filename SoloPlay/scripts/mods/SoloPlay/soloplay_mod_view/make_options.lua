local mod = get_mod("SoloPlay")
local SoloPlaySettings = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/SoloPlaySettings")

local HAVOC_LOC = Localize("loc_havoc_name")

local make_options = {}

make_options.normal_mission = function (current)
	local options = {}
	for _, mission_name in ipairs(SoloPlaySettings.order.missions) do
		local option = {
			ignore_localization = true,
			display_name = SoloPlaySettings.loc.missions[mission_name],
			id = mission_name,
			value = mission_name,
		}
		options[#options+1] = option
	end
	return options
end

make_options.normal_side_mission = function (current)
	local options = {
		{
			ignore_localization = true,
			display_name = mod:localize("default_text_none"),
			id = "default",
			value = "default",
		},
	}
	for _, side_mission_name in ipairs(SoloPlaySettings.order.side_missions) do
		local option = {
			ignore_localization = true,
			display_name = SoloPlaySettings.loc.side_missions[side_mission_name],
			id = side_mission_name,
			value = side_mission_name,
		}
		options[#options+1] = option
	end
	return options
end

make_options.normal_circumstance = function (current)
	local options = {
		{
			ignore_localization = true,
			display_name = mod:localize("default_text_none"),
			id = "default",
			value = "default",
		},
	}
	local allow_list = SoloPlaySettings.lookup.circumstances_of_missions[current.normal_mission]
	for _, circumstance_name in ipairs(SoloPlaySettings.order.circumstances) do
		if not allow_list or allow_list[circumstance_name] then
			local final_display_name = SoloPlaySettings.loc.circumstances[circumstance_name]
			if SoloPlaySettings.lookup.havoc_circumstances[circumstance_name] or table.array_contains(SoloPlaySettings.order.havoc_difficulty_circumstances, circumstance_name) then
				final_display_name = string.format("%s: %s", HAVOC_LOC, final_display_name)
			end
			local option = {
				ignore_localization = true,
				display_name = final_display_name,
				id = circumstance_name,
				value = circumstance_name,
			}
			options[#options+1] = option
		end
	end
	return options
end

make_options.normal_mission_giver = function (current)
	local options = {
		{
			ignore_localization = true,
			display_name = mod:localize("default_text"),
			id = "default",
			value = "default",
		},
	}
	local allow_list = SoloPlaySettings.lookup.mission_givers_of_missions[current.normal_mission]
	for _, mission_giver_name in ipairs(SoloPlaySettings.order.mission_givers) do
		if not allow_list or allow_list[mission_giver_name] then
			local option = {
				ignore_localization = true,
				display_name = SoloPlaySettings.loc.mission_givers[mission_giver_name],
				id = mission_giver_name,
				value = mission_giver_name,
			}
			options[#options+1] = option
		end
	end
	return options
end

make_options.havoc_mission = function (current)
	local options = {}
	for _, mission_name in ipairs(SoloPlaySettings.order.missions) do
		if SoloPlaySettings.lookup.theme_circumstances_of_havoc_missions[mission_name] then
			local option = {
				ignore_localization = true,
				display_name = SoloPlaySettings.loc.missions[mission_name],
				id = mission_name,
				value = mission_name,
			}
			options[#options+1] = option
		end
	end
	return options
end

make_options.havoc_faction = function (current)
	local options = {}
	for _, faction_name in ipairs(SoloPlaySettings.order.havoc_factions) do
		local option = {
			ignore_localization = true,
			display_name = mod:localize("havoc_faction_" .. faction_name),
			id = faction_name,
			value = faction_name,
		}
		options[#options+1] = option
	end
	return options
end

make_options.havoc_mission_giver = function (current)
	local options = {
		{
			ignore_localization = true,
			display_name = mod:localize("default_text"),
			id = "default",
			value = "default",
		},
	}
	local allow_list = SoloPlaySettings.lookup.mission_givers_of_missions[current.havoc_mission]
	for _, mission_giver_name in ipairs(SoloPlaySettings.order.mission_givers) do
		if not allow_list or allow_list[mission_giver_name] then
			local option = {
				ignore_localization = true,
				display_name = SoloPlaySettings.loc.mission_givers[mission_giver_name],
				id = mission_giver_name,
				value = mission_giver_name,
			}
			options[#options+1] = option
		end
	end
	return options
end

local havoc_circumstance = function (current, with_default)
	local options = {}
	if with_default then
		options[#options+1] = {
			ignore_localization = true,
			display_name = mod:localize("default_text_none"),
			id = "default",
			value = "default",
		}
	end
	for _, circumstance_name in ipairs(SoloPlaySettings.order.havoc_circumstances) do
		local option = {
			ignore_localization = true,
			display_name = SoloPlaySettings.loc.circumstances[circumstance_name],
			id = circumstance_name,
			value = circumstance_name,
		}
		options[#options+1] = option
	end
	return options
end

make_options.havoc_circumstance1 = function (current)
	return havoc_circumstance(current, false)
end

make_options.havoc_circumstance2 = function (current)
	return havoc_circumstance(current, true)
end

make_options.havoc_theme_circumstance = function (current)
	local options = {
		{
			ignore_localization = true,
			display_name = mod:localize("default_text_none"),
			id = "default",
			value = "default",
		},
	}
	for _, circumstance_name in ipairs(SoloPlaySettings.order.havoc_theme_circumstances) do
		if SoloPlaySettings.lookup.theme_circumstances_of_havoc_missions[current.havoc_mission][circumstance_name] then
			local option = {
				ignore_localization = true,
				display_name = SoloPlaySettings.loc.circumstances[circumstance_name],
				id = circumstance_name,
				value = circumstance_name,
			}
			options[#options+1] = option
		end
	end
	return options
end

make_options.havoc_difficulty_circumstance = function (current)
	local options = {
		{
			ignore_localization = true,
			display_name = mod:localize("default_text_none"),
			id = "default",
			value = "default",
		},
	}
	for _, circumstance_name in ipairs(SoloPlaySettings.order.havoc_difficulty_circumstances) do
		local option = {
			ignore_localization = true,
			display_name = SoloPlaySettings.loc.circumstances[circumstance_name],
			id = circumstance_name,
			value = circumstance_name,
		}
		options[#options+1] = option
	end
	return options
end

return make_options
