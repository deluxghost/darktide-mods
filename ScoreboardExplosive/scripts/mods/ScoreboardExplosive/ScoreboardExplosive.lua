local mod = get_mod("ScoreboardExplosive")
local scoreboard = get_mod("scoreboard")
local TextUtilities = require("scripts/utilities/ui/text")

local explosive_cache = mod:persistent_table("explosive_cache")

mod.on_enabled = function(initial_call)
	if mod:get("explosive_ignited") == false then
		mod:set("option_explosive_detonated", false, false)
	end
	mod:set("explosive_ignited", nil, false)
end

mod.on_game_state_changed = function(status, state_name)
	if state_name ~= "StateGameplay" then
		return
	end
	table.clear(explosive_cache)
end

local function player_from_unit(unit)
	if unit then
		for _, player in pairs(Managers.player:players()) do
			if player.player_unit == unit then
				return player
			end
		end
	end
	return nil
end

local function explosive_type_from_cache(unit)
	if explosive_cache[unit] then
		local content = explosive_cache[unit].content
		if content == "explosion" then
			return "explosive_explosion_barrel"
		elseif content == "fire" then
			return "explosive_fire_barrel"
		elseif content == "gas" then
			return "explosive_gas_barrel"
		end
	end
	return "explosive_common"
end

local function explosive_text_color(explosive_type)
	if explosive_type == "explosive_explosion_barrel" then
		return Color.citadel_dorn_yellow(255, true)
	elseif explosive_type == "explosive_fire_barrel" then
		return Color.ui_red_light(255, true)
	elseif explosive_type == "explosive_gas_barrel" then
		return Color.green_yellow(255, true)
	end
	return Color.citadel_jokaero_orange(255, true)
end

local function get_explosive_ignited_cache(unit)
	if explosive_cache[unit] and explosive_cache[unit].ignited then
		return true
	end
	return false
end

local function set_explosive_ignited_cache(unit)
	explosive_cache[unit] = explosive_cache[unit] or {}
	explosive_cache[unit].ignited = true
end

mod:hook(CLASS.AttackReportManager, "add_attack_result", function(
		func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot,
		damage, attack_result, attack_type, damage_efficiency, ...
	)
	local player = player_from_unit(attacking_unit)
	local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
	if player and unit_data_extension then
		local account_id = player:account_id() or player:name()
		local breed = unit_data_extension:breed()
		if breed then
			local breed_name = unit_data_extension:breed_name()
			if breed_name == "hazard_prop" or breed_name == "hazard_sphere" then
				local hazard_prop_extension = ScriptUnit.has_extension(attacked_unit, "hazard_prop_system")
				if hazard_prop_extension then
					local explosive_type = explosive_type_from_cache(attacked_unit)
					local explosive = mod:localize(explosive_type)
					if damage == 0 and attack_type == nil then
						-- exploded
						explosive_cache[attacked_unit] = nil
						if mod:get("option_explosive_detonated") and scoreboard then
							scoreboard:update_stat("scoreboard_explosive_detonated", account_id, 1)
						end
						if mod:get("option_message_explosive_detonated") then
							local color = explosive_text_color(explosive_type)
							local message = mod:localize("message_explosive_detonated")
							message = string.gsub(message, ":explosive:", TextUtilities.apply_color_to_text(explosive, color))
							Managers.event:trigger("event_combat_feed_kill", attacking_unit, message)
						end
					else
						-- triggered / additional damage
						if not get_explosive_ignited_cache(attacked_unit) then
							if mod:get("option_message_explosive_ignited") then
								local color = explosive_text_color(explosive_type)
								local message = mod:localize("message_explosive_ignited")
								message = string.gsub(message, ":explosive:", TextUtilities.apply_color_to_text(explosive, color))
								Managers.event:trigger("event_combat_feed_kill", attacking_unit, message)
							end
							set_explosive_ignited_cache(attacked_unit)
						end
					end
				end
			end
		end
	end
	return func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, ...)
end)

mod:hook_safe("HazardPropExtension", "set_current_state", function(self, state)
	local unit = self._unit
	if state == "triggered" or state == "exploding" then
		explosive_cache[unit] = explosive_cache[unit] or {}
		explosive_cache[unit].content = self:content()
	end
end)

mod.scoreboard_rows = {
	{
		name = "scoreboard_explosive_detonated",
		text = "explosive_detonated",
		validation = "DESC",
		iteration = "ADD",
		group = "team",
		setting = "option_explosive_detonated",
	},
}
