local mod = get_mod("ScoreboardExplosive")
local scoreboard = get_mod("scoreboard")
local TextUtilities = require("scripts/utilities/ui/text")

mod.on_all_mods_loaded = function()
	if not scoreboard then
		mod:hook(CLASS.HudElementCombatFeed, "event_combat_feed_kill", function(func, self, attacking_unit, attacked_unit, ...)
			if type(attacked_unit) == "string" then
				local message = attacked_unit
				local color_name = self:_get_unit_presentation_name(attacking_unit) or "NONE"
				self:_add_combat_feed_message(color_name .. message)
				return
			end
			return func(self, attacking_unit, attacked_unit, ...)
		end)
	end
end

mod.on_enabled = function(initial_call)
	if mod:get("option_explosive_detonated") == false then
		mod:set("option_explosive_ignited", false, false)
	elseif mod:get("option_explosive_detonated") == nil and mod:get("explosive_ignited") == false then
		mod:set("option_explosive_ignited", false, false)
	end
	mod:set("option_explosive_detonated", nil, false)
	mod:set("explosive_ignited", nil, false)
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

local function get_explosive_type(damage_profile, unit)
	if damage_profile.name == "barrel_explosion" or damage_profile.name == "barrel_explosion_close" then
		return "explosive_explosion_barrel"
	elseif damage_profile.name == "fire_barrel_explosion" or damage_profile.name == "fire_barrel_explosion_close" then
		return "explosive_fire_barrel"
	end
	local hazard_prop_extension = ScriptUnit.has_extension(unit, "hazard_prop_system")
	if hazard_prop_extension then
		if hazard_prop_extension._content == "explosion" then
			return "explosive_explosion_barrel"
		elseif hazard_prop_extension._content == "fire" then
			return "explosive_fire_barrel"
		end
	end
	return "explosive_common"
end

local function handle_attack(account_id, damage_profile, attacking_unit, attacked_unit)
	local explosive_type = get_explosive_type(damage_profile, attacked_unit)
	local explosive = mod:localize(explosive_type)
	local hazard_prop_extension = ScriptUnit.has_extension(attacked_unit, "hazard_prop_system")
	if not hazard_prop_extension then
		return
	end
	if hazard_prop_extension._current_state == "triggered" then
		if mod:get("option_explosive_ignited") and scoreboard and account_id then
			scoreboard:update_stat("scoreboard_explosive_ignited", account_id, 1)
		end
		if mod:get("option_message_explosive_ignited") then
			local color = explosive_text_color(explosive_type)
			local message = mod:localize("message_explosive_ignited")
			message = string.gsub(message, ":explosive:", TextUtilities.apply_color_to_text(explosive, color))
			Managers.event:trigger("event_combat_feed_kill", attacking_unit, message)
		end
	elseif hazard_prop_extension._current_state == "broken" and explosive_type ~= "explosive_common" then
		if mod:get("option_message_explosive_detonated") then
			local color = explosive_text_color(explosive_type)
			local message = mod:localize("message_explosive_detonated")
			message = string.gsub(message, ":explosive:", TextUtilities.apply_color_to_text(explosive, color))
			Managers.event:trigger("event_combat_feed_kill", attacking_unit, message)
		end
	end
end

mod:hook(CLASS.AttackReportManager, "add_attack_result", function(
		func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot,
		damage, attack_result, attack_type, damage_efficiency, ...
	)
	local player = player_from_unit(attacking_unit)
	local account_id = nil
	if player then
		account_id = player:account_id() or player:name()
	end
	local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
	if unit_data_extension then
		local breed = unit_data_extension:breed()
		if breed then
			local breed_name = unit_data_extension:breed_name()
			if breed_name == "hazard_prop" or breed_name == "hazard_sphere" then
				if damage > 0 then
					handle_attack(account_id, damage_profile, attacking_unit, attacked_unit)
				end
			end
		end
	end
	return func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, ...)
end)

mod.scoreboard_rows = {
	{
		name = "scoreboard_explosive_ignited",
		text = "explosive_ignited",
		validation = "DESC",
		iteration = "ADD",
		group = "team",
		setting = "option_explosive_ignited",
	},
}
