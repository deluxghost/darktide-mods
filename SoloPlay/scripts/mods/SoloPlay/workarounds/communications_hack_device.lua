local mod = get_mod("SoloPlay")
local Auspex = require("scripts/utilities/weapon/auspex")
local MinigameFrequency = require("scripts/extension_systems/minigame/minigames/minigame_frequency")
local PlayerCharacterStateMinigame = require("scripts/extension_systems/character_state_machine/character_states/player_character_state_minigame")
local PlayerUnitVisualLoadout = require("scripts/extension_systems/visual_loadout/utilities/player_unit_visual_loadout")
local WieldableSlotScripts = require("scripts/extension_systems/visual_loadout/utilities/wieldable_slot_scripts")

mod:hook_require("scripts/settings/equipment/weapon_templates/pocketables/communications_hack_device_pocketable", function (template)
	local action_use_self = template.actions.action_use_self

	action_use_self.kind = "focus_auspex"
	action_use_self.action_condition_func = function (action_settings, condition_func_params, used_input, t)
		return not Auspex.in_focus(condition_func_params.unit)
	end
end)

local function set_communication_hack_interface_state(slot_script)
	if not slot_script._is_server then
		return
	end

	slot_script._minigame_character_state_component.interface_level_unit_id = NetworkConstants.invalid_level_unit_id
	slot_script._minigame_character_state_component.interface_game_object_id = slot_script._game_object_id
	slot_script._minigame_character_state_component.interface_is_level_unit = false
end

local function activate_communication_hack_device(wieldable_slot_scripts, action_settings)
	if not action_settings or action_settings.kind ~= "focus_auspex" then
		return
	end

	for i = 1, #wieldable_slot_scripts do
		local slot_script = wieldable_slot_scripts[i]

		if slot_script.__class_name == "CommunicationHackInterfaceDevice" then
			set_communication_hack_interface_state(slot_script)
		elseif slot_script.__class_name == "Device" then
			slot_script._activate_game = true
		end
	end
end

local function sync_minigame_completion_settings(minigame)
	if not minigame then
		return
	end

	local minigame_extension = minigame._minigame_extension
	local mutator_on_minigame_complete = minigame_extension and minigame_extension._mutator_on_minigame_complete

	if not mutator_on_minigame_complete then
		return
	end

	minigame._mutator_on_minigame_complete = mutator_on_minigame_complete
	minigame._minigame = minigame
end

mod:hook_safe(WieldableSlotScripts, "on_action", function (wieldable_slot_scripts, action_settings, t)
	activate_communication_hack_device(wieldable_slot_scripts, action_settings)
end)

mod:hook(MinigameFrequency, "complete", function (func, self, ...)
	sync_minigame_completion_settings(self)

	return func(self, ...)
end)

mod:hook_safe(MinigameFrequency, "on_action_pressed", function (self, t)
	if self._is_server and not self:is_completed() then
		self:test_frequency(self._frequency.x, self._frequency.y)
	end
end)

local function is_communication_hack_device_equipped(visual_loadout_extension)
	local pocketable_item = visual_loadout_extension:item_from_slot("slot_pocketable_small")

	return pocketable_item and pocketable_item.name == "content/items/pocketable/communications_hack_device_pocketable"
end

mod:hook(PlayerCharacterStateMinigame, "on_exit", function (func, self, unit, t, next_state)
	local minigame = self._minigame
	local inventory_component = self._inventory_component
	local visual_loadout_extension = self._visual_loadout_extension
	local remove_pocketable = minigame
		and minigame:unequip_on_exit()
		and minigame:is_completed()
		and inventory_component.wielded_slot == "slot_pocketable_small"
		and is_communication_hack_device_equipped(visual_loadout_extension)

	func(self, unit, t, next_state)

	if remove_pocketable
		and PlayerUnitVisualLoadout.slot_equipped(inventory_component, visual_loadout_extension, "slot_pocketable_small")
		and is_communication_hack_device_equipped(visual_loadout_extension) then
		PlayerUnitVisualLoadout.wield_previous_weapon_slot(inventory_component, unit, t)
		PlayerUnitVisualLoadout.unequip_item_from_slot(unit, "slot_pocketable_small", t)
	end
end)
