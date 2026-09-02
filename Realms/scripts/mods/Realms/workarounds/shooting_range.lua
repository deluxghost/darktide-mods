local mod = get_mod("Realms")
local BuffSettings = require("scripts/settings/buff/buff_settings")
local Component = require("scripts/utilities/component")
require("scripts/extension_systems/health/health_extension_base")
local InteracteeExtension = require("scripts/extension_systems/interaction/interactee_extension")
local PlayerMovement = require("scripts/utilities/player_movement")
local PlayerHuskHealthExtension = require("scripts/extension_systems/health/player_husk_health_extension")
local ScriptedScenarioSystem = require("scripts/extension_systems/scripted_scenario/scripted_scenario_system")
local ShootingRangeSteps = require("scripts/extension_systems/training_grounds/shooting_range_steps")

local ShootingRange = {}
local Session
local GameplayControl
local installed_interactable_events = setmetatable({}, { __mode = "k" })

local GAME_MODE_NAME = "shooting_range"
local INVENTORY_VIEW_NAME = "inventory_background_view"
local MUSIC_ZONE_STATE_GROUP = "music_zone"
local MUSIC_ZONE_UNMUFFLED = "on"
local OPEN_TIMEOUT = 5
local PENDING_TIMEOUT = OPEN_TIMEOUT + 1
local UNPERCEIVABLE_BUFF_NAME = "tg_player_unperceivable"
local UNPERCEIVABLE_KEYWORD = BuffSettings.keywords.unperceivable

local runtime = {
	chest_open = false,
	close_pending = false,
	closing_animation = false,
	local_open_pending = false,
	local_view_opened = false,
	host_sound_muffled = true,
	local_invulnerability_sync = false,
	local_sound_muffled = true,
	local_sound_muffling_sync = false,
	open_by_peer = {},
	pending_by_peer = {},
}

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function is_shooting_range()
	local game_mode_manager = Managers.state and Managers.state.game_mode

	return game_mode_manager and game_mode_manager:game_mode_name() == GAME_MODE_NAME
end

local function is_local_client_health_extension(health_extension)
	if not Session or not Session.is_active_client() or not is_shooting_range() then
		return false
	end

	local player = Managers.player and Managers.player:local_player(1)
	local player_unit = player and player.player_unit
	local local_health_extension = player_unit and ALIVE[player_unit] and ScriptUnit.has_extension(player_unit, "health_system")

	return local_health_extension == health_extension
end

local function is_loadout_unit(unit)
	local unit_spawner = Managers.state and Managers.state.unit_spawner
	local templates = unit_spawner and unit_spawner._unit_templates
	local templates_by_unit = unit_spawner and unit_spawner._unit_template_by_unit

	return unit and templates and templates_by_unit and templates_by_unit[unit] == templates.shooting_range_loadout or false
end

local function find_loadout_unit()
	if runtime.chest_unit and ALIVE[runtime.chest_unit] then
		return runtime.chest_unit
	end

	local unit_spawner = Managers.state and Managers.state.unit_spawner

	if not unit_spawner then
		return nil
	end

	for unit, template in pairs(unit_spawner._unit_template_by_unit) do
		if template == unit_spawner._unit_templates.shooting_range_loadout and ALIVE[unit] then
			runtime.chest_unit = unit

			return unit
		end
	end

	return nil
end

local function update_chest_occupancy()
	local was_open = runtime.chest_open

	runtime.chest_open = next(runtime.open_by_peer) ~= nil or next(runtime.pending_by_peer) ~= nil

	if runtime.chest_open then
		runtime.close_pending = false
	elseif was_open and not runtime.chest_open then
		runtime.close_pending = true
	end
end

local function set_peer_pending(peer_id)
	peer_id = normalize_peer_id(peer_id)
	runtime.pending_by_peer[peer_id] = Managers.time:time("main")

	update_chest_occupancy()
end

local function set_peer_open(peer_id, open)
	peer_id = normalize_peer_id(peer_id)

	if open then
		runtime.pending_by_peer[peer_id] = nil
	end

	runtime.open_by_peer[peer_id] = open and true or nil

	update_chest_occupancy()
end

local function clear_peer_chest_state(peer_id)
	peer_id = normalize_peer_id(peer_id)
	runtime.pending_by_peer[peer_id] = nil
	runtime.open_by_peer[peer_id] = nil

	update_chest_occupancy()
end

local function local_peer_id()
	return normalize_peer_id(Network.peer_id())
end

local function reset_runtime()
	table.clear(runtime.open_by_peer)
	table.clear(runtime.pending_by_peer)
	runtime.chest_open = false
	runtime.chest_unit = nil
	runtime.close_pending = false
	runtime.closing_animation = false
	runtime.local_open_pending = false
	runtime.local_open_started_at = nil
	runtime.local_status_pending = nil
	runtime.local_view_opened = false
	runtime.host_sound_muffled = true
	runtime.local_invulnerability_sync = false
	runtime.local_sound_muffled = true
	runtime.local_sound_muffling_sync = false
	runtime.session_active = false
end

local function discard_client_init_scenarios(scenario_system)
	local queued_scenarios = scenario_system._queued_scenarios

	for i = #queued_scenarios, 1, -1 do
		local scenario = queued_scenarios[i]

		if scenario.alias == GAME_MODE_NAME and scenario.name == "init" then
			table.remove(queued_scenarios, i)
		end
	end
end

local function apply_local_sound_muffling()
	local sound_muffled = not runtime.local_sound_muffling_sync or runtime.local_sound_muffled

	Wwise.set_state(MUSIC_ZONE_STATE_GROUP, sound_muffled and GAME_MODE_NAME or MUSIC_ZONE_UNMUFFLED)
end

local function initialize_client(scenario_system)
	local player = Managers.player:local_player(1)
	local player_unit = player and player.player_unit

	if not player_unit or not Unit.alive(player_unit) then
		return false
	end

	local directional_unit = scenario_system:get_directional_unit("arena_middle")

	if not directional_unit then
		if not scenario_system._realms_missing_arena_middle_logged then
			scenario_system._realms_missing_arena_middle_logged = true
			mod:error("The arena_middle directional unit is unavailable")
		end

		return false
	end

	apply_local_sound_muffling()
	PlayerMovement.teleport_fixed_update(player_unit, Unit.local_position(directional_unit, 1), Unit.local_rotation(directional_unit, 1))
	scenario_system:spawn_attached_units_in_spawn_group("shooting_range_units")
	discard_client_init_scenarios(scenario_system)
	mod:info("Initialized shooting-range client")

	return true
end

local function start_local_loadout()
	local scenario_system = Managers.state.extension:system("scripted_scenario_system")
	local shooting_range_scenarios = scenario_system._parallel_scenarios[GAME_MODE_NAME]

	runtime.local_open_pending = true
	runtime.local_open_started_at = Managers.time:time("main")

	if shooting_range_scenarios and shooting_range_scenarios.open_loadout then
		if not scenario_system:enabled() then
			scenario_system:set_enabled(true)
		end

		return
	end

	scenario_system:start_parallel_scenario(GAME_MODE_NAME, "open_loadout", Managers.time:time("gameplay"))

	if not scenario_system:enabled() then
		scenario_system:set_enabled(true)
	end
end

local function close_chest_if_unoccupied()
	if not runtime.close_pending or runtime.chest_open then
		return
	end

	local chest_unit = find_loadout_unit()
	local player = Managers.player:local_player(1)
	local player_unit = player and player.player_unit

	if not chest_unit or not player_unit or not ALIVE[player_unit] then
		return
	end

	runtime.close_pending = false
	runtime.closing_animation = true
	Component.event(chest_unit, "interaction_success", "scripted_scenario", player_unit)
	Component.event(chest_unit, "interaction_canceled", "scripted_scenario", player_unit)
	runtime.closing_animation = false
end

local function update_local_inventory()
	if not runtime.local_open_pending and not runtime.local_view_opened then
		return
	end

	local view_open = Managers.ui:view_instance(INVENTORY_VIEW_NAME) ~= nil

	if runtime.local_open_pending then
		if view_open then
			runtime.local_open_pending = false
			runtime.local_open_started_at = nil
			runtime.local_view_opened = true

			if Session.is_active_host() then
				set_peer_open(local_peer_id(), true)
			elseif Session.is_active_client() then
				local sent, send_error = GameplayControl.send_to_host("shooting_range_inventory", {
					open = true,
				})

				if not sent then
					mod:error("Failed sending opened inventory state: %s", send_error)
				end
			end
		elseif Managers.time:time("main") - runtime.local_open_started_at >= OPEN_TIMEOUT then
			mod:error("The shooting-range inventory view did not open within %.1f seconds", OPEN_TIMEOUT)
			runtime.local_open_pending = false
			runtime.local_open_started_at = nil

			if Session.is_active_host() then
				clear_peer_chest_state(local_peer_id())
			elseif Session.is_active_client() then
				GameplayControl.send_to_host("shooting_range_inventory", {
					open = false,
				})
			end
		end
	elseif not view_open then
		runtime.local_view_opened = false

		if Session.is_active_host() then
			set_peer_open(local_peer_id(), false)
		else
			local sent, send_error = GameplayControl.send_to_host("shooting_range_inventory", {
				open = false,
			})

			if not sent then
				mod:error("Failed sending closed inventory state: %s", send_error)
			end
		end
	end
end

local function handle_inventory_message(channel_id, peer_id, data)
	if not Session.is_active_host() or not is_shooting_range() then
		return false, "Shooting-range inventory state arrived outside a Realms shooting-range session"
	end
	local normalized_peer_id = normalize_peer_id(peer_id)

	if data.open and not runtime.pending_by_peer[normalized_peer_id] and not runtime.open_by_peer[normalized_peer_id] then
		return false, "Shooting-range inventory opened without a successful chest interaction"
	end

	set_peer_open(peer_id, data.open)

	return true
end

local function expire_pending_interactions()
	if not Session.is_active_host() or not next(runtime.pending_by_peer) then
		return
	end

	local t = Managers.time:time("main")
	local changed = false

	for peer_id, started_at in pairs(runtime.pending_by_peer) do
		if t - started_at >= PENDING_TIMEOUT then
			runtime.pending_by_peer[peer_id] = nil
			changed = true
		end
	end

	if changed then
		update_chest_occupancy()
	end
end

local function apply_pending_local_status()
	local pending = runtime.local_status_pending

	if not pending then
		return
	end

	local player = Managers.player and Managers.player:local_player(1)
	local player_unit = player and player.player_unit
	local health_extension = player_unit and ALIVE[player_unit] and ScriptUnit.has_extension(player_unit, "health_system")

	if not health_extension then
		return
	end

	runtime.local_invulnerability_sync = pending.sync_invulnerability

	if pending.sync_invulnerability then
		health_extension:set_invulnerable(pending.invulnerable)
	else
		health_extension._realms_invulnerable = nil
	end

	runtime.local_status_pending = nil
end

local function handle_status_message(channel_id, peer_id, data)
	if not Session.is_active_client() or not is_shooting_range() then
		return false, "Shooting-range status arrived outside a Realms shooting-range client session"
	end

	runtime.local_status_pending = {
		sync_invulnerability = data.sync_invulnerability,
		invulnerable = data.invulnerable,
	}
	runtime.local_invulnerability_sync = data.sync_invulnerability

	runtime.local_sound_muffled = data.sound_muffled
	runtime.local_sound_muffling_sync = data.sync_sound_muffling
	apply_local_sound_muffling()

	apply_pending_local_status()

	return true
end

local function can_synchronize_player_status()
	if not Session or not Session.is_active_host() or not is_shooting_range() then
		return false
	end

	local game_mode = Managers.state.game_mode:game_mode()

	return game_mode and game_mode:state() == "in_game"
end

local function status_sync(spawn_manager)
	local sync = spawn_manager._realms_shooting_range_status_sync

	if not sync then
		sync = {
			applied = {},
			version = 0,
		}
		spawn_manager._realms_shooting_range_status_sync = sync
	end

	return sync
end

local function read_status(unit)
	local health_extension = ScriptUnit.extension(unit, "health_system")
	local buff_extension = ScriptUnit.extension(unit, "buff_system")

	return health_extension:is_invulnerable(), buff_extension:has_keyword(UNPERCEIVABLE_KEYWORD)
end

local function apply_status(unit, scenario_system, sync_invulnerability, invulnerable, sync_invisibility, unperceivable, t, applied)
	local health_extension = ScriptUnit.extension(unit, "health_system")
	local buff_extension = ScriptUnit.extension(unit, "buff_system")

	if sync_invulnerability then
		if applied and not applied.invulnerability_active then
			applied.invulnerability_active = true
			applied.original_invulnerability = health_extension:is_invulnerable()
		end

		health_extension:set_invulnerable(invulnerable)

		if applied then
			applied.invulnerability = invulnerable
		end
	elseif applied and applied.invulnerability_active then
		if health_extension:is_invulnerable() == applied.invulnerability then
			health_extension:set_invulnerable(applied.original_invulnerability)
		end

		applied.invulnerability_active = nil
		applied.original_invulnerability = nil
		applied.invulnerability = nil
	end

	local currently_unperceivable = buff_extension:has_keyword(UNPERCEIVABLE_KEYWORD)
	local scenario_buff = scenario_system:has_scenario_buff(unit, UNPERCEIVABLE_BUFF_NAME)

	if sync_invisibility then
		if applied and not applied.invisibility_active then
			applied.invisibility_active = true
			applied.original_scenario_buff = scenario_buff
		end

		if unperceivable then
			if not currently_unperceivable then
				if scenario_buff then
					scenario_system:remove_scenario_buff(unit, UNPERCEIVABLE_BUFF_NAME)
				end

				scenario_system:add_scenario_buff(unit, UNPERCEIVABLE_BUFF_NAME, t)
			end
		elseif scenario_buff then
			scenario_system:remove_scenario_buff(unit, UNPERCEIVABLE_BUFF_NAME)
		end
	elseif applied and applied.invisibility_active then
		if applied.original_scenario_buff and not scenario_buff then
			scenario_system:add_scenario_buff(unit, UNPERCEIVABLE_BUFF_NAME, t)
		elseif not applied.original_scenario_buff and scenario_buff then
			scenario_system:remove_scenario_buff(unit, UNPERCEIVABLE_BUFF_NAME)
		end

		applied.invisibility_active = nil
		applied.original_scenario_buff = nil
	end
end

local function send_status_to_peer(peer_id, sync)
	local connection_host = Managers.connection and Managers.connection._connection_host
	local connected_peers = connection_host and connection_host:connected_peers()

	if not connected_peers then
		return false
	end

	peer_id = normalize_peer_id(peer_id)

	for channel_id, connected_peer_id in pairs(connected_peers) do
		if normalize_peer_id(connected_peer_id) == peer_id then
			return GameplayControl.send_to_client(channel_id, "shooting_range_status", {
				sync_invulnerability = sync.sync_invulnerability,
				invulnerable = sync.invulnerable,
				sync_sound_muffling = sync.sync_sound_muffling,
				sound_muffled = sync.sound_muffled,
			})
		end
	end

	return false
end

local function send_remote_status(player, sync, applied)
	if not player.remote or applied.client_version == sync.version then
		return
	end

	if send_status_to_peer(player:peer_id(), sync) then
		applied.client_version = sync.version
	end
end

local function read_sync_state(host_unit)
	local invulnerable, unperceivable = read_status(host_unit)
	local sync_invulnerability = mod:get("shooting_range_sync_invulnerability") == true
	local sync_invisibility = mod:get("shooting_range_sync_invisibility") == true
	local sync_sound_muffling = mod:get("shooting_range_sync_sound_muffling") == true

	return sync_invulnerability, sync_invulnerability and invulnerable or false,
		sync_invisibility, sync_invisibility and unperceivable or false,
		sync_sound_muffling, sync_sound_muffling and runtime.host_sound_muffled or false
end

local function update_sync_state(sync, host_unit)
	local sync_invulnerability, invulnerable, sync_invisibility, unperceivable, sync_sound_muffling, sound_muffled = read_sync_state(host_unit)
	local changed = sync.host_unit ~= host_unit
		or sync.sync_invulnerability ~= sync_invulnerability
		or sync.invulnerable ~= invulnerable
		or sync.sync_invisibility ~= sync_invisibility
		or sync.unperceivable ~= unperceivable
		or sync.sync_sound_muffling ~= sync_sound_muffling
		or sync.sound_muffled ~= sound_muffled

	sync.host_unit = host_unit
	sync.sync_invulnerability = sync_invulnerability
	sync.invulnerable = invulnerable
	sync.sync_invisibility = sync_invisibility
	sync.unperceivable = unperceivable
	sync.sync_sound_muffling = sync_sound_muffling
	sync.sound_muffled = sound_muffled

	if changed then
		sync.version = sync.version + 1
	end
end

local function synchronize_player_status(spawn_manager, t)
	local player_manager = Managers.player
	local host = player_manager and player_manager:local_player(1)
	local host_unit = host and host.player_unit
	local extension_manager = Managers.state and Managers.state.extension
	local scenario_system = extension_manager and extension_manager:system("scripted_scenario_system")

	if not host_unit or not ALIVE[host_unit] or not scenario_system or not scenario_system._current_scenario then
		return
	end

	local sync = status_sync(spawn_manager)

	if sync.host_unit and sync.host_unit ~= host_unit and sync.invulnerable ~= nil then
		apply_status(host_unit, scenario_system, mod:get("shooting_range_sync_invulnerability") == true, sync.invulnerable,
			mod:get("shooting_range_sync_invisibility") == true, sync.unperceivable, t)
	end

	update_sync_state(sync, host_unit)

	local present = {}

	for _, player in pairs(player_manager:players()) do
		if player:is_human_controlled() then
			local unique_id = player:unique_id()
			local player_unit = player.player_unit

			present[unique_id] = true

			if player_unit and ALIVE[player_unit] then
				local applied = sync.applied[unique_id]
				local client_version
				local needs_update = not applied

				if applied then
					client_version = applied.client_version
					needs_update = applied.unit ~= player_unit or applied.version ~= sync.version
				end

				if needs_update then
					if not applied or applied.unit ~= player_unit then
						applied = {
							client_version = client_version,
							unit = player_unit,
						}
					end

					if player_unit ~= host_unit then
						apply_status(player_unit, scenario_system, sync.sync_invulnerability, sync.invulnerable,
							sync.sync_invisibility, sync.unperceivable, t, applied)
					end

					applied.version = sync.version
					sync.applied[unique_id] = applied
				end

				if player_unit ~= host_unit then
					send_remote_status(player, sync, applied)
				end
			end
		end
	end

	for unique_id in pairs(sync.applied) do
		if not present[unique_id] then
			sync.applied[unique_id] = nil
		end
	end
end

local function update_player_status()
	if not can_synchronize_player_status() then
		return
	end

	local spawn_manager = Managers.state.player_unit_spawn

	if spawn_manager and spawn_manager._is_server then
		synchronize_player_status(spawn_manager, Managers.time:time("gameplay"))
	end
end

function ShootingRange.install(session, gameplay_control)
	Session = session
	GameplayControl = gameplay_control

	GameplayControl.register_host_handler("shooting_range_inventory", handle_inventory_message)
	GameplayControl.register_client_handler("shooting_range_status", handle_status_message)
	GameplayControl.register_disconnect_handler("shooting_range", function (peer_id)
		clear_peer_chest_state(peer_id)
	end)

	mod:hook(CLASS.ModManager, "update", function (func, self, dt)
		func(self, dt)
		update_player_status()
	end)

	mod:hook(Wwise, "set_state", function (func, group_name, state_name, ...)
		if Session.is_active_host() and is_shooting_range() and group_name == MUSIC_ZONE_STATE_GROUP then
			if state_name == GAME_MODE_NAME then
				runtime.host_sound_muffled = true
			elseif state_name == MUSIC_ZONE_UNMUFFLED then
				runtime.host_sound_muffled = false
			end
		end

		return func(group_name, state_name, ...)
	end)

	mod:hook(PlayerHuskHealthExtension, "set_invulnerable", function (func, self, should_be_invulnerable)
		if runtime.local_invulnerability_sync and is_local_client_health_extension(self) then
			self._realms_invulnerable = should_be_invulnerable

			return
		end

		return func(self, should_be_invulnerable)
	end)

	mod:hook(PlayerHuskHealthExtension, "is_invulnerable", function (func, self)
		if runtime.local_invulnerability_sync and is_local_client_health_extension(self) and self._realms_invulnerable ~= nil then
			return self._realms_invulnerable
		end

		return func(self)
	end)

	mod:hook(ScriptedScenarioSystem, "start_scenario", function (func, self, alias, name, t)
		if not Session.is_active_client() or not is_shooting_range() or alias ~= GAME_MODE_NAME or name ~= "init" then
			return func(self, alias, name, t)
		end

		if not self._realms_client_initialized then
			self._realms_client_initialized = initialize_client(self)

			if not self._realms_client_initialized then
				table.insert(self._queued_scenarios, 1, {
					alias = alias,
					name = name,
				})
			end
		end
	end)

	mod:hook(ShootingRangeSteps.chest_loop, "condition_func", function (func, scenario_system, player, scenario_data, step_data, t)
		if not Session.is_active_host() or not is_shooting_range() then
			return func(scenario_system, player, scenario_data, step_data, t)
		end

		runtime.chest_unit = step_data.loadout_unit

		local interactee_extension = ALIVE[runtime.chest_unit] and ScriptUnit.has_extension(runtime.chest_unit, "interactee_system")

		if interactee_extension and not interactee_extension:active() then
			interactee_extension:set_active(true)
		end

		close_chest_if_unoccupied()

		return false
	end)

	mod:hook(InteracteeExtension, "stopped", function (func, self, result, interactor_unit)
		local func_result = func(self, result, interactor_unit)

		if result ~= "success" or not Session.is_active() or not is_shooting_range() or not is_loadout_unit(self._unit) then
			return func_result
		end

		local player = interactor_unit and Managers.state.player_unit_spawn:owner(interactor_unit)

		if not player then
			return func_result
		end

		if Session.is_active_host() then
			set_peer_pending(player:peer_id())

			if not player.remote then
				start_local_loadout()
			end
		elseif not player.remote then
			start_local_loadout()
		end

		return func_result
	end)

	mod:hook_require("scripts/components/interactable", function (Interactable)
		local events = Interactable.events

		if installed_interactable_events[events] then
			return
		end

		mod:hook(events, "interaction_started", function (func, self, interaction_type, interactor_unit)
			if Session.is_active_host() and is_shooting_range() and is_loadout_unit(self._unit) and runtime.chest_open then
				return true
			end

			return func(self, interaction_type, interactor_unit)
		end)

		mod:hook(events, "interaction_success", function (func, self, interaction_type, interactor_unit)
			if Session.is_active_host() and is_shooting_range() and is_loadout_unit(self._unit) then
				if runtime.closing_animation then
					return func(self, interaction_type, interactor_unit)
				end
				if runtime.chest_open then
					return
				end
			end

			return func(self, interaction_type, interactor_unit)
		end)

		installed_interactable_events[events] = true
	end)
end

function ShootingRange.update()
	local active = Session and Session.is_active() and is_shooting_range()

	if not active then
		if runtime.session_active then
			reset_runtime()
		end

		return
	end

	runtime.session_active = true
	apply_pending_local_status()
	find_loadout_unit()
	update_local_inventory()
	expire_pending_interactions()
end

return ShootingRange
