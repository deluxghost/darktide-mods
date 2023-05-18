local mod = get_mod("ScoreboardExplosive")
local scoreboard = get_mod("scoreboard")
local TextUtilities = require("scripts/utilities/ui/text")
-- local Breed = require("scripts/utilities/breed")

local explosive_cache = mod:persistent_table("explosive_cache")

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
	local id = Unit.id_string(unit)
	if explosive_cache[id] then
		local content = explosive_cache[id].content
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

local function explosive_first_damage(unit)
	local id = Unit.id_string(unit)
	if explosive_cache[id] and explosive_cache[id].content and (not explosive_cache[id].ignited) then
		return true
	end
	return false
end

local function set_explosive_ignited_cache(attacking, attacked)
	local id = Unit.id_string(attacked)
	explosive_cache[id] = explosive_cache[id] or {}
	explosive_cache[id].emitter = attacking
	explosive_cache[id].ignited = true
end

local function handle_attack(account_id, damage, attacking_unit, attacked_unit, attack_type)
	local explosive_type = explosive_type_from_cache(attacked_unit)
	local explosive = mod:localize(explosive_type)
	if damage == 0 and attack_type == nil then
		-- exploded
		if mod:get("option_message_explosive_detonated") and explosive_type ~= "explosive_common" then
			local color = explosive_text_color(explosive_type)
			local message = mod:localize("message_explosive_detonated")
			message = string.gsub(message, ":explosive:", TextUtilities.apply_color_to_text(explosive, color))
			if player_from_unit(attacking_unit) then
				Managers.event:trigger("event_combat_feed_kill", attacking_unit, message)
			else
				local id = Unit.id_string(attacked_unit)
				if explosive_cache[id] and explosive_cache[id].emitter and player_from_unit(explosive_cache[id].emitter) then
					Managers.event:trigger("event_combat_feed_kill", explosive_cache[id].emitter, message)
				end
			end
		end
		explosive_cache[Unit.id_string(attacked_unit)] = nil
	else
		-- triggered / additional damage
		if explosive_first_damage(attacked_unit) then
			if mod:get("option_explosive_ignited") and scoreboard and account_id and explosive_type ~= "explosive_common" then
				scoreboard:update_stat("scoreboard_explosive_ignited", account_id, 1)
			end
			if mod:get("option_message_explosive_ignited") and explosive_type ~= "explosive_common" then
				local color = explosive_text_color(explosive_type)
				local message = mod:localize("message_explosive_ignited")
				message = string.gsub(message, ":explosive:", TextUtilities.apply_color_to_text(explosive, color))
				if player_from_unit(attacking_unit) then
					Managers.event:trigger("event_combat_feed_kill", attacking_unit, message)
				end
			end
			set_explosive_ignited_cache(attacking_unit, attacked_unit)
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
				local hazard_prop_extension = ScriptUnit.has_extension(attacked_unit, "hazard_prop_system")
				if hazard_prop_extension then
					handle_attack(account_id, damage, attacking_unit, attacked_unit, attack_type)
				end
			end
		end
	end
	return func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, ...)
end)

mod:hook_safe("HazardPropExtension", "set_current_state", function(self, state)
	local unit = self._unit
	local id = Unit.id_string(unit)
	if state == "triggered" or state == "exploding" then
		explosive_cache[id] = explosive_cache[id] or {}
		explosive_cache[id].content = self:content()
	end
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
