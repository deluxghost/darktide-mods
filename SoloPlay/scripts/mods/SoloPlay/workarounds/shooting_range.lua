local mod = get_mod("SoloPlay")
local PlayerUnitSpawnManager = require("scripts/managers/player/player_unit_spawn_manager")

local GAME_MODE_NAME = "shooting_range"
local NAMEPLATES_NAME = "HudElementNameplates"
local PLAYER_WEAPON_HANDLER_NAME = "HudElementPlayerWeaponHandler"

local function is_shooting_range()
	local game_mode_manager = Managers.state and Managers.state.game_mode

	return game_mode_manager and game_mode_manager:game_mode_name() == GAME_MODE_NAME
end

local function can_respawn()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode = game_mode_manager and game_mode_manager:game_mode()

	return game_mode_manager and game_mode_manager:game_mode_name() == GAME_MODE_NAME and game_mode and game_mode:state() == "in_game"
end

local function initial_spawn_points(spawn_manager)
	local spawn_points = spawn_manager._soloplay_shooting_range_initial_spawn_points

	if not spawn_points then
		spawn_points = {}
		spawn_manager._soloplay_shooting_range_initial_spawn_points = spawn_points
	end

	return spawn_points
end

local function refresh_hud_player_unit(hud, changed_unit)
	if not hud then
		return
	end

	local extensions = hud._extensions
	local player_unit = hud:player_unit()

	if player_unit ~= changed_unit and (not extensions or extensions.unit ~= changed_unit) then
		return
	end

	local unit_changed = not extensions or extensions.unit ~= player_unit
	local nameplates = hud._elements[NAMEPLATES_NAME]

	if nameplates and nameplates._extensions and nameplates._extensions.unit ~= player_unit then
		nameplates._extensions = nil
	end

	if not unit_changed then
		return
	end

	hud._extensions = nil

	local handler = hud._elements[PLAYER_WEAPON_HANDLER_NAME]

	if not handler then
		return
	end

	local player_weapons = handler._player_weapons

	for _, data in pairs(player_weapons) do
		data.hud_element_player_weapon:destroy(hud._ui_renderer)
	end

	table.clear(player_weapons)
	table.clear(handler._player_weapons_array)
end

local function refresh_player_huds(changed_unit)
	local ui_manager = Managers.ui

	if not ui_manager or not is_shooting_range() then
		return
	end

	refresh_hud_player_unit(ui_manager:get_hud(), changed_unit)
	refresh_hud_player_unit(ui_manager._spectator_hud, changed_unit)
end

mod:hook(PlayerUnitSpawnManager, "spawn_player", function (func, self, player, position, rotation, parent, force_spawn, optional_side_name, breed_name_optional, character_state_optional, is_respawn, optional_damage, optional_permanent_damage)
	local result = func(self, player, position, rotation, parent, force_spawn, optional_side_name, breed_name_optional, character_state_optional, is_respawn, optional_damage, optional_permanent_damage)

	if self._is_server and not is_respawn and is_shooting_range() then
		local spawn_points = initial_spawn_points(self)
		local unique_id = player:unique_id()

		if not spawn_points[unique_id] then
			spawn_points[unique_id] = {
				position = Vector3Box(position),
				rotation = QuaternionBox(rotation),
				side = optional_side_name,
			}
		end
	end

	return result
end)

mod:hook(PlayerUnitSpawnManager, "fixed_update", function (func, self, dt, t)
	func(self, dt, t)

	if not self._is_server or not can_respawn() then
		return
	end

	local players_to_spawn = self:players_to_spawn()
	local spawn_points = self._soloplay_shooting_range_initial_spawn_points

	for i = #players_to_spawn, 1, -1 do
		local player = players_to_spawn[i]
		local spawn_point = spawn_points and spawn_points[player:unique_id()]

		if spawn_point then
			local force_spawn = false
			local is_respawn = true

			self:spawn_player(player, spawn_point.position:unbox(), spawn_point.rotation:unbox(), nil, force_spawn, spawn_point.side, nil, "walking", is_respawn)
			table.remove(players_to_spawn, i)
		else
			mod:error("Missing initial spawn point for player %s", player:unique_id())
		end
	end

	self._num_players_to_spawn = #players_to_spawn
end)

mod:hook_safe(PlayerUnitSpawnManager, "assign_unit_ownership", function (self, unit, player, is_player_unit)
	if is_player_unit then
		refresh_player_huds(unit)
	end
end)

mod:hook_safe(PlayerUnitSpawnManager, "relinquish_unit_ownership", function (self, unit)
	refresh_player_huds(unit)
end)
