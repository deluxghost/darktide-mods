local mod = get_mod("CleanForceBlocking")
local PlayerUnitFxExtension = require("scripts/extension_systems/fx/player_unit_fx_extension")
local ForceWeaponBlockEffects = require("scripts/extension_systems/visual_loadout/wieldable_slot_scripts/force_weapon_block_effects")
local ActionDamageTarget = require("scripts/extension_systems/weapon/actions/action_damage_target")
local ActionPush = require("scripts/extension_systems/weapon/actions/action_push")

local function is_force_sword(template)
	if not template then
		return false
	end
	if not template.keywords then
		return false
	end
	for _, keyword in ipairs(template.keywords) do
		if keyword == "force_sword" then
			return true
		end
	end
	return false
end

mod:hook(ForceWeaponBlockEffects, "_update_block_effects", function(func, self, dt)
	if not mod:get("remove_blocking_effect") then
		return func(self, dt)
	end
	self:_destroy_effects()
end)

mod:hook(ActionDamageTarget, "_play_particles", function(func, self)
	if not mod:get("remove_push_attack_effect") then
		return func(self)
	end
	if is_force_sword(self._weapon_template) then
		return
	end
	return func(self)
end)

mod:hook(ActionPush, "_play_push_particles", function(func, self)
	if not mod:get("remove_pushing_effect") then
		return func(self)
	end
	if is_force_sword(self._weapon_template) then
		return
	end
	return func(self)
end)

mod:hook(PlayerUnitFxExtension, "_trigger_looping_wwise_event", function(func, self, sound_alias, optional_source_name)
	if not mod:get("remove_blocking_sound") then
		return func(self, sound_alias, optional_source_name)
	end
	if sound_alias == "block_loop" and optional_source_name == "slot_primary_block" then
		return
	end
	return func(self, sound_alias, optional_source_name)
end)
