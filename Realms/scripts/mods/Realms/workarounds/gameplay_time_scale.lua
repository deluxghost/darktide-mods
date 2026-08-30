local mod = get_mod("Realms")
local AdaptiveClockHandlerClient = require("scripts/managers/player/player_game_states/utilities/adaptive_clock_handler_client")
local FlowCallbacks = require("scripts/script_flow_nodes/flow_callbacks")

local GameplayTimeScale = {}
local DEFAULT_GAMEPLAY_TIME_SCALE = 1
local host_gameplay_time_scale = DEFAULT_GAMEPLAY_TIME_SCALE

function GameplayTimeScale.install(Session, GameplayControl)
	mod:hook(FlowCallbacks, "set_host_gameplay_timescale", function (func, params)
		if Session.is_active_client() then
			return
		end

		local result = func(params)

		if Session.is_active_host() then
			local sent, send_error = GameplayControl.send_to_clients("gameplay_time_scale", {
				scale = tonumber(params.scale),
			})

			if not sent then
				mod:error("Failed synchronizing gameplay time scale: %s", send_error)
			end
		end

		return result
	end)

	mod:hook_safe(AdaptiveClockHandlerClient, "post_update", function (self)
		if not self._time_scale or not Session.is_active_client() then
			return
		end

		local correction = self._time_scale - self._base_time_scale
		local scale = host_gameplay_time_scale == 0 and 0 or math.max(host_gameplay_time_scale + correction, 0)

		Managers.time:set_local_scale("gameplay", scale)
	end)

	GameplayControl.register_client_handler("gameplay_time_scale", function (channel_id, peer_id, data)
		host_gameplay_time_scale = data.scale

		return true
	end)

	GameplayControl.register_ready_handler("gameplay_time_scale", function (channel_id, peer_id, role)
		if role ~= "host" or not Session.is_active_host() then
			return true
		end

		local scale = DEFAULT_GAMEPLAY_TIME_SCALE

		if Managers.time:has_timer("gameplay") then
			scale = Managers.time:local_scale("gameplay")
		end

		return GameplayControl.send_to_client(channel_id, "gameplay_time_scale", {
			scale = scale,
		})
	end)

	GameplayControl.register_disconnect_handler("gameplay_time_scale", function ()
		host_gameplay_time_scale = DEFAULT_GAMEPLAY_TIME_SCALE
	end)
end

return GameplayTimeScale
