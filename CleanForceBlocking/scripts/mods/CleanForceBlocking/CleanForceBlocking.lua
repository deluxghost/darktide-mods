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

mod:hook(ForceWeaponBlockEffects, "_update_sound_effects", function(func, self)
	if not mod:get("remove_blocking_sound") then
		return func(self)
	end
	local looping_sound_component = self._looping_sound_component
	local fx_extension = self._fx_extension

	if looping_sound_component.is_playing then
		fx_extension:stop_looping_wwise_event("block_loop")
	end
end)

mod:hook(ForceWeaponBlockEffects, "_update_block_effects", function(func, self, dt)
	self:_destroy_effects()
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
