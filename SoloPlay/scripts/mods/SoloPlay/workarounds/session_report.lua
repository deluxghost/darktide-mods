local mod = get_mod("SoloPlay")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local ProgressionManager = require("scripts/managers/progression/progression_manager")
local Promise = require("scripts/foundation/utilities/promise")
local StatDefinitions = require("scripts/managers/stats/stat_definitions")
local StatsManager = require("scripts/managers/stats/stats_manager")

local HOST_TYPES = MatchmakingConstants.HOST_TYPES
local TEAM_STATS = {
	team_kills = "session_team_kills",
	team_deaths = "team_deaths",
}
local STAT_EVENTS = {
	hook_kill = "team_kills",
	hook_death = "team_deaths",
}

mod:hook_safe("GameModeManager", "init", function (self, context)
	local host_type = Managers.multiplayer_session:host_type()

	if context.is_server and (host_type == HOST_TYPES.singleplay or host_type == HOST_TYPES.player) then
		-- Each mission owns its counters, including when starting a new mission in-game.
		self._soloplay_session_stats = {team_kills = 0, team_deaths = 0}
	end
end)

mod:hook_safe(StatsManager, "record_private", function (self, stat_name)
	local report_key = STAT_EVENTS[stat_name]

	if not report_key then
		return
	end

	local game_mode = Managers.state.game_mode
	local counters = game_mode and game_mode._soloplay_session_stats

	if counters and not counters.complete then
		-- The native events still fire locally, but record_private discards them
		-- without backend session tracking. Do not enable tracking or backend saves.
		counters[report_key] = counters[report_key] + 1
	end
end)

local function sync_final_team_stats(stats, team, players, game_session)
	-- Deliver the local totals before rpc_fetch_session_report on the same channel.
	for _, player in pairs(players) do
		local peer_id = player:peer_id()

		if game_session:connected_to_client(peer_id) and peer_id ~= Network.peer_id() then
			local channel_id = game_session:peer_to_channel(peer_id)

			for report_key, stat_name in pairs(TEAM_STATS) do
				local value = team[report_key]
				local rpc = stats:_get_smallest_send_rpc(value)

				rpc.rpc(channel_id, player:local_player_id(), StatDefinitions[stat_name].index, value)
			end
		end
	end
end

mod:hook(ProgressionManager, "_use_dummy_session_report", function (func, self)
	local host_type = Managers.multiplayer_session:host_type()

	if host_type ~= HOST_TYPES.singleplay and host_type ~= HOST_TYPES.player then
		return func(self)
	end

	local local_player = Managers.player:local_player(1)
	local local_profile = local_player:profile()
	local players = Managers.player:human_players()
	local stats = Managers.stats
	local game_session = Managers.state.game_session
	local is_server = game_session:is_server()
	local team = {
		play_time_seconds = Managers.time:time("gameplay"),
	}

	for report_key, stat_name in pairs(TEAM_STATS) do
		if is_server then
			team[report_key] = Managers.state.game_mode._soloplay_session_stats[report_key]
		else
			team[report_key] = stats:read_user_stat(local_player:local_player_id(), stat_name)
		end
	end

	if is_server then
		sync_final_team_stats(stats, team, players, game_session)
		-- Cleanup deaths after the report snapshot must not count toward the mission.
		Managers.state.game_mode._soloplay_session_stats.complete = true
	end

	local participants = {}

	for _, player in pairs(players) do
		local profile = player:profile()

		participants[#participants + 1] = {
			accountId = player:account_id(),
			characterId = profile.character_id,
			progression = {
				{
					type = "character",
					startLevel = profile.current_level,
					currentLevel = profile.current_level,
				},
			},
			rewardCards = {},
		}
	end

	-- Local sessions have no backend rewards. Do not parse the example report:
	-- its fake items and progression also enter the native reward-claim path.
	self._session_report = {
		dummy = true,
		team = team,
		character = {
			local_session_report = true,
			start_character_level = local_profile.current_level,
			current_character_level = local_profile.current_level,
			experience_gained = 0,
			rewards = {},
			inventory = {},
		},
		account = {
			experience_gained = 0,
			rewards = {},
		},
		eor = {
			mission = {
				playTimeSeconds = team.play_time_seconds,
			},
			team = {
				participants = participants,
			},
		},
	}
	self._session_report_is_dummy = true
	self._fetch_session_report_at = nil
	self:_calculate_game_score_end()
	self._session_report_state = "success"

	return Promise.resolved()
end)

mod:hook("EndView", "_level_from_xp", function (func, self, experience_settings, xp)
	if self._session_report.character.local_session_report then
		-- The native caller uses the participant's currentLevel when this returns 0.
		-- No XP curve or XP total is needed for an unchanged local character level.
		return 0
	end

	return func(self, experience_settings, xp)
end)

mod:hook("EndPlayerView", "_setup_progress_bar", function (func, self)
	if not self._session_report.local_session_report then
		return func(self)
	end

	-- _create_cards already continues immediately for an empty reward list.
	-- Hide the reward-only widgets while its asset callback is pending, rather
	-- than showing invented XP thresholds or zeroing the player's wallet display.
	for _, widget in pairs(self._widgets_by_name) do
		widget.visible = false
	end
end)
