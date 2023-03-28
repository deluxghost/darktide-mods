local mod = get_mod("CleanForceBlocking")
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
	self:_destroy_effects()
	return
end)

mod:hook(ActionDamageTarget, "_play_particles", function(func, self)
	if is_force_sword(self._weapon_template) then
		return
	end
	func(self)
end)

mod:hook(ActionPush, "_play_push_particles", function(func, self)
	if is_force_sword(self._weapon_template) then
		return
	end
	func(self)
end)
