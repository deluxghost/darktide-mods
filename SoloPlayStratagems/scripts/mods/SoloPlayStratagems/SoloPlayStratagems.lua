local mod = get_mod("SoloPlayStratagems")
local FixedFrame = require("scripts/utilities/fixed_frame")
local MasterItems = require("scripts/backend/master_items")
local Pickups = require("scripts/settings/pickup/pickups")
local PlayerUnitVisualLoadout = require("scripts/extension_systems/visual_loadout/utilities/player_unit_visual_loadout")
local Pocketable = require("scripts/utilities/pocketable")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local HOST_TYPES = MatchmakingConstants.HOST_TYPES

mod.state = mod.state or mod:persistent_table("state")
mod:io_dofile("SoloPlayStratagems/scripts/mods/SoloPlayStratagems/airstrike")
mod:io_dofile("SoloPlayStratagems/scripts/mods/SoloPlayStratagems/stratagem_menu_state")

mod:register_hud_element({
	class_name = "HudElementStratagemMenu",
	filename = "SoloPlayStratagems/scripts/mods/SoloPlayStratagems/HudElementStratagemMenu",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
})

local PACKAGES = {
	"content/levels/expeditions/airstrikes/airstrikes_01/world",
	"content/levels/expeditions/airstrikes/airstrikes_02/world",
	"packages/game_mode/expedition",
}

mod.load_package = function (package_name)
	if not Managers.package:is_loading(package_name) and not Managers.package:has_loaded(package_name) then
		Managers.package:load(package_name, "solo_play_stratagems", nil, true)
	end
end

mod.on_all_mods_loaded = function ()
	for i = 1, #PACKAGES do
		mod.load_package(PACKAGES[i])
	end
	mod.refresh_active_stratagems()
end

mod.is_server = function ()
	local game_session_manager = Managers.state and Managers.state.game_session
	return game_session_manager and game_session_manager:is_server()
end

mod.is_local_game = function ()
	if not Managers.state.game_mode then
		return false
	end
	if not Managers.multiplayer_session then
		return false
	end
	local host_type = Managers.multiplayer_session:host_type()
	return host_type == HOST_TYPES.singleplay or host_type == HOST_TYPES.singleplay_backend_session
end

mod.game_world = function ()
	local world_manager = Managers.world
	local world_name = "level_world"
	return world_manager and world_manager:has_world(world_name) and world_manager:world(world_name) or nil
end

mod.on_game_state_changed = function (status, state_name)
	if state_name == "StateGameplay" then
		if status == "enter" then
			mod.airstrike_register_events()
		elseif status == "exit" then
			mod.airstrike_unregister_events()
			mod.airstrike_destroy()
			mod.stratagem_menu_set_visible(false)
		end
	end
end

mod.on_disabled = function ()
	mod.airstrike_unregister_events()
	mod.airstrike_destroy()
	mod.stratagem_menu_set_visible(false)
end

mod.play_sound = function (event_name)
	local ui_manager = Managers.ui
	if not ui_manager or event_name == "" then
		return false
	end

	ui_manager:play_2d_sound(event_name)
	return true
end

local function _find_template_by_pocketable(pocketable)
	for _, template in ipairs(mod.templates.stratagems) do
		if template.pocketable == pocketable then
			return template
		end
	end
	return nil
end

mod.refresh_active_stratagems = function ()
	local active_stratagems = {}
	local seen = {}

	for idx = 1, mod.templates.MAX_ACTIVE_STRATAGEMS do
		local pocketable = mod:get("stratagem_slot_" .. tostring(idx))
		if pocketable ~= "" and pocketable ~= "none" and not seen[pocketable] then
			local template = _find_template_by_pocketable(pocketable)
			if template then
				seen[pocketable] = true
				active_stratagems[#active_stratagems + 1] = template
			end
		end
	end

	mod.state.active_stratagems = active_stratagems
	return active_stratagems
end

mod.get_active_stratagems = function ()
	return mod.state.active_stratagems or mod.refresh_active_stratagems()
end

mod.trigger_stratagem = function (name)
	if not mod.is_server() then
		return false
	end
	local pickup_data = Pickups.by_name[name]
	if not pickup_data then
		return false
	end

	local slot_name = pickup_data.inventory_slot_name
	local inventory_item_name = pickup_data.inventory_item
	local inventory_item = inventory_item_name and MasterItems.get_item(inventory_item_name)
	if not slot_name or not inventory_item then
		return false
	end

	local local_player = Managers.player and Managers.player:local_player(1)
	local player_unit = local_player and local_player.player_unit
	if not player_unit then
		return false
	end

	local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
	local visual_loadout_extension = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
	local world = mod.game_world()
	local physics_world = world and World.physics_world(world)
	if not unit_data_extension or not visual_loadout_extension or not physics_world then
		return false
	end

	local inventory_component = unit_data_extension:read_component("inventory")
	local fixed_t = FixedFrame.get_latest_fixed_time()
	if inventory_component[slot_name] ~= "not_equipped" then
		Pocketable.drop_pocketable(fixed_t, physics_world, mod.is_server(), player_unit, inventory_component, visual_loadout_extension, slot_name)
	end

	PlayerUnitVisualLoadout.equip_item_to_slot(player_unit, inventory_item, slot_name, nil, fixed_t)
	PlayerUnitVisualLoadout.wield_slot(slot_name, player_unit, fixed_t)
	return true
end

mod:hook_safe("GameplayStateRun", "update", function ()
	mod.airstrike_update()
	mod.stratagem_menu_update()
end)
