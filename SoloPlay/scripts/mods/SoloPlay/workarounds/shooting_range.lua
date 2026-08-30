local mod = get_mod("SoloPlay")
local PlayerUnitSpawnManager = require("scripts/managers/player/player_unit_spawn_manager")

local GAME_MODE_NAME = "shooting_range"

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
