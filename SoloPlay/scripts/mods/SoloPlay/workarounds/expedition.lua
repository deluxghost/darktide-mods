local mod = get_mod("SoloPlay")
local ConstantElementNotificationFeed = require("scripts/ui/constant_elements/elements/notification_feed/constant_element_notification_feed")
local ExpeditionLogicServer = require("scripts/managers/game_mode/game_modes/expedition/expedition_logic_server")

-- remove debug message
mod:hook(ConstantElementNotificationFeed, "event_add_notification_message", function (func, self, message_type, data, ...)
	if mod.is_soloplay() and type(data) == "string" and string.starts_with(data, "[DEV]") then
		return
	end
	return func(self, message_type, data, ...)
end)

-- expedition mode nil checks
mod:hook_require("scripts/managers/multiplayer/connection_manager", function (ConnectionManager)
	-- num_connections is called in update functions
	-- change it permanently to survive mod reloading
	if ConnectionManager.__soloplay_modified then
		return
	end
	local orig_num_connections = ConnectionManager.num_connections
	ConnectionManager.num_connections = function (self)
		if self._connection_host == nil or self._connection_host.num_connections == nil then
			return 0
		end
		return orig_num_connections(self)
	end
	ConnectionManager.__soloplay_modified = true
end)

-- fake expedition server client: level despawning

local function _handle_wait_on_clients_level_loading_and_spawn(logic, state_name, state_flags)
	local player = Managers.player:local_player(1)
	if not player or not player:is_human_controlled() then
		return
	end
	local unique_id = player:unique_id()
	local peer_id = player:peer_id()
	local game_session_manager = Managers.state.game_session
	local channel_id = game_session_manager and game_session_manager:peer_to_channel(peer_id)

	local current_location_index = logic._current_section_index
	local players_spawned_next_location = logic._players_spawned_next_location or {}
	if players_spawned_next_location[unique_id] == false and channel_id == nil then
		if state_flags[state_name] ~= current_location_index then
			state_flags[state_name] = current_location_index
			logic._players_spawned_next_location[unique_id] = true
		end
	elseif players_spawned_next_location[unique_id] ~= false then
		state_flags[state_name] = nil
	end
end

local function _handle_wait_on_clients_level_despawn(logic, state_name, state_flags)
	local levels_spawner = logic._levels_spawner
	if not levels_spawner or levels_spawner:despawning() then
		return
	end

	local player = Managers.player:local_player(1)
	if not player or not player:is_human_controlled() then
		return
	end
	local unique_id = player:unique_id()
	local peer_id = player:peer_id()
	local game_session_manager = Managers.state.game_session
	local channel_id = game_session_manager and game_session_manager:peer_to_channel(peer_id)

	if logic._players_started_despawning[unique_id] ~= false then
		return
	end
	if state_flags[state_name] == unique_id then
		return
	end
	state_flags[state_name] = unique_id

	if channel_id == nil then
		logic._players_started_despawning[unique_id] = true
		return
	end
	logic:rpc_server_expedition_levels_despawned_by_player(channel_id)
end

local WAIT_ON_CLIENTS_STATE_HANDLERS = {
	wait_on_clients_level_loading_and_spawn = _handle_wait_on_clients_level_loading_and_spawn,
	wait_on_clients_level_despawn = _handle_wait_on_clients_level_despawn,
}

mod:hook_safe(ExpeditionLogicServer, "update", function (self)
	if not mod.is_soloplay() then
		return
	end

	local state = self._server_level_state
	self.__soloplay_wait_on_clients_state_flags = self.__soloplay_wait_on_clients_state_flags or {}
	local state_flags = self.__soloplay_wait_on_clients_state_flags
	for state_name in pairs(WAIT_ON_CLIENTS_STATE_HANDLERS) do
		if state_name ~= state then
			state_flags[state_name] = nil
		end
	end

	local handler = WAIT_ON_CLIENTS_STATE_HANDLERS[state]
	if handler then
		handler(self, state, state_flags)
	end
end)

-- fake expedition server client: exit safe zone trigger
mod:hook_safe(ExpeditionLogicServer, "_on_gameplay_paused", function (self)
	if not mod.is_soloplay() then
		return
	end

	local safe_zone_section = self._get_active_safe_zone_section and self:_get_active_safe_zone_section()
	if not safe_zone_section then
		return
	end

	local game_session_manager = Managers.state and Managers.state.game_session
	if game_session_manager then
		game_session_manager:send_rpc_clients("rpc_can_proceed_to_safe_zone_exit", safe_zone_section.index)
	end

	self:rpc_can_proceed_to_safe_zone_exit(nil, safe_zone_section.index)
end)
