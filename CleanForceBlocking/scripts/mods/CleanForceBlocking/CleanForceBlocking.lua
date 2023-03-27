local mod = get_mod("CleanForceBlocking")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local ForceWeaponBlockEffects = require("scripts/extension_systems/visual_loadout/wieldable_slot_scripts/force_weapon_block_effects")

local function is_force_sword(template)
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

mod.on_enabled = function(initial_call)
	for _, template in pairs(WeaponTemplates) do
		if is_force_sword(template) and template.actions then
			local actions = template.actions
			if actions.action_block then
				actions.action_block.block_vfx_name = nil
			end
			if actions.action_push then
				actions.action_push.fx = nil
			end
			if actions.action_fling_target then
				actions.action_fling_target.fx = nil
			end
		end
	end
end

mod.on_disabled = function(initial_call)
	for _, template in pairs(WeaponTemplates) do
		if is_force_sword(template) and template.actions then
			local actions = template.actions
			if actions.action_block then
				actions.action_block.block_vfx_name = "content/fx/particles/weapons/swords/forcesword/psyker_block"
			end
			if actions.action_push then
				actions.action_push.fx = {
					fx_source = "fx_left_hand",
					vfx_effect = "content/fx/particles/weapons/swords/forcesword/psyker_parry"
				}
			end
			if actions.action_fling_target then
				actions.action_fling_target.fx = {
					fx_source = "fx_left_hand",
					vfx_effect = "content/fx/particles/weapons/swords/forcesword/psyker_push"
				}
			end
		end
	end
end
