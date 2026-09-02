local mod = get_mod("Realms")
local BotSpawning = require("scripts/managers/bot/bot_spawning")
local PlayerUnitSpawnManager = require("scripts/managers/player/player_unit_spawn_manager")

local BotBackfill = {}
local MAX_INITIAL_BOTS = 6
local resetting_host_session = false

local function active_host(Session)
	local game_session = Managers.state and Managers.state.game_session

	local session_manager = Managers.multiplayer_session
	return not resetting_host_session and Session.is_active_host() and game_session and game_session:is_server() and session_manager and not session_manager:is_leaving()
end

local function available_bot_slots(self, maximum_desired_bots, Session)
	if not active_host(Session) then
		return 0
	end

	local settings = Managers.state.game_mode:settings()
	if not settings.bot_backfilling_allowed then
		return 0
	end

	local bot_synchronizer_host = Managers.bot:synchronizer_host()
	local num_humans = Managers.player:num_ready_human_players()
	local num_bots = bot_synchronizer_host:num_bots() + self._queued_bots_n
	local desired_bot_count = math.max(mod:get("bot_fill_target") - num_humans, 0)
	if maximum_desired_bots then
		desired_bot_count = math.min(desired_bot_count, maximum_desired_bots)
	end

	return desired_bot_count - num_bots
end

local function initial_available_bot_slots(self, Session)
	return available_bot_slots(self, MAX_INITIAL_BOTS, Session)
end

local function fallback_profile_name()
	local config_prefix = BotSpawning.get_bot_config_identifier() .. "_bot_"
	local used_profiles = {}
	for _, player in pairs(Managers.player:bot_players()) do
		local profile = player:profile()
		local identifier = profile.identifier

		if identifier then
			used_profiles[identifier] = true
		end
	end

	local registered_profiles = {}
	local unused_profiles = {}
	for lookup_id, profile_name in pairs(NetworkLookup.bot_profile_names) do
		if type(lookup_id) == "number" and type(profile_name) == "string" and string.sub(profile_name, 1, #config_prefix) == config_prefix then
			registered_profiles[#registered_profiles + 1] = profile_name
			if not used_profiles[profile_name] then
				unused_profiles[#unused_profiles + 1] = profile_name
			end
		end
	end

	local candidates = #unused_profiles > 0 and unused_profiles or registered_profiles

	return #candidates > 0 and candidates[math.random(#candidates)] or nil
end

function BotBackfill.reset_session(Session, original_reset, manager, reason)
	if not Session.is_active_host() then
		return original_reset(manager, reason)
	end

	-- A reset disconnects clients while the old gameplay state is still updating.
	-- Its replacement-bot queue belongs to the session being destroyed.
	local player_unit_spawn = Managers.state and Managers.state.player_unit_spawn

	resetting_host_session = true
	local result = original_reset(manager, reason)
	resetting_host_session = false

	if player_unit_spawn then
		player_unit_spawn._queued_bots_n = 0
	end

	return result
end

function BotBackfill.install(Session)

	mod:hook(BotSpawning, "despawn_best_bot", function (func, despawn_safe)
		return func(active_host(Session) or despawn_safe)
	end)

	mod:hook(PlayerUnitSpawnManager, "init", function (func, self, is_server, ...)
		if not is_server or not Session.is_active_host() then
			return func(self, is_server, ...)
		end

		self._num_available_bot_slots = function (spawn_manager)
			return initial_available_bot_slots(spawn_manager, Session)
		end

		local result = func(self, is_server, ...)

		self._num_available_bot_slots = function (spawn_manager)
			return available_bot_slots(spawn_manager, nil, Session)
		end
		self:_validate_bot_backfill()

		return result
	end)

	mod:hook(BotSpawning, "spawn_bot_character", function (func, profile_name)
		if profile_name == nil and active_host(Session) then
			profile_name = fallback_profile_name()
		end

		return func(profile_name)
	end)
end

function BotBackfill.apply_settings(Session)
	local player_unit_spawn = Managers.state and Managers.state.player_unit_spawn
	if not player_unit_spawn or not active_host(Session) then
		return
	end

	player_unit_spawn:_validate_bot_backfill()
end

return BotBackfill
