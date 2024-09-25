local mod = get_mod("CleanForceBlocking")
local ForceWeaponBlockEffects = require("scripts/extension_systems/visual_loadout/wieldable_slot_scripts/force_weapon_block_effects")

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

mod:hook(ForceWeaponBlockEffects, "_update_vfx", function(func, self)
	if not mod:get("remove_blocking_effect") then
		return func(self)
	end
	self:_destroy_vfx()
end)

mod:hook(ForceWeaponBlockEffects, "_update_sfx", function(func, self)
	if not mod:get("remove_blocking_sound") then
		return func(self)
	end
	self:_stop_sfx()
end)

mod:hook_require("scripts/extension_systems/weapon/actions/action_damage_target", function(ActionDamageTarget)
	mod:hook(ActionDamageTarget, "_play_particles", function(func, self)
		if not mod:get("remove_push_attack_effect") then
			return func(self)
		end
		if is_force_sword(self._weapon_template) then
			return
		end
		return func(self)
	end)
end)

mod:hook_require("scripts/extension_systems/weapon/actions/action_push", function(ActionPush)
	mod:hook(ActionPush, "_play_push_particles", function(func, self)
		if not mod:get("remove_pushing_effect") then
			return func(self)
		end
		if is_force_sword(self._weapon_template) then
			return
		end
		return func(self)
	end)
end)
