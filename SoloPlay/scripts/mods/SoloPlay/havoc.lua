local mod = get_mod("SoloPlay")
local HavocSettings = require("scripts/settings/havoc_settings")
local HavocModifierConfig = require("scripts/settings/havoc/havoc_modifier_config")

local SEED = 2023062419930608

local function _random(...)
	local seed, value = math.next_random(SEED, ...)
	SEED = seed
	return value
end

mod.gen_havoc_data = function (havoc_rank)
	local seed = math.random(23062419930608, 2023062419930608)
	SEED = seed

	local data = {
		circumstance2 = "default",
		theme_circumstance = "default",
		difficulty_circumstance = "default",
		modifiers = {},
	}

	local themes = HavocSettings.themes
	local chance_for_default_theme = HavocSettings.chance_for_default_theme
	local forced_themes_ranks = HavocSettings.forced_themes_ranks
	local circumstances_per_theme = HavocSettings.circumstances_per_theme

	local use_theme = false
	for i = 1, #forced_themes_ranks do
		local checked_rank = forced_themes_ranks[i]
		if havoc_rank == checked_rank then
			use_theme = true
			break
		end
	end
	local value = _random(0, 100)
	value = value * 0.01
	if chance_for_default_theme < value then
		use_theme = true
	end

	local theme
	if use_theme then
		theme = "default"
	else
		theme = themes[_random(1, #themes)]
		local possible_circumstances = circumstances_per_theme[theme]
		data.theme_circumstance = possible_circumstances[_random(1, #possible_circumstances)]
	end

	local missions = HavocSettings.missions[theme]
	data.mission = missions[_random(1, #missions)]
	local factions = HavocSettings.factions
	data.faction = factions[_random(1, #factions)]

	if havoc_rank >= 16 and havoc_rank <= 29 then
		data.difficulty_circumstance = "mutator_increased_difficulty"
	elseif havoc_rank >= 30 then
		data.difficulty_circumstance = "mutator_highest_difficulty"
	end

	local num_circumstances = math.min(math.floor(havoc_rank / HavocSettings.num_ranks_per_circumstance) + 1, HavocSettings.max_circumstances)
	local circumstances = table.clone(HavocSettings.circumstances)
	local circumstance1_index = _random(1, #circumstances)
	data.circumstance1 = circumstances[circumstance1_index]
	table.remove(circumstances, circumstance1_index)
	if num_circumstances > 1 then
		data.circumstance2 = circumstances[_random(1, #circumstances)]
	end

	local modifier_config = HavocModifierConfig[havoc_rank]
	for name, tier_level in pairs(modifier_config) do
		data.modifiers[#data.modifiers+1] = {
			name = name,
			level = tier_level,
		}
	end

	return data
end
