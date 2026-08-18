local mod = get_mod("Reconnect")
local StateMainMenu = require("scripts/game_states/game/state_main_menu")
local MechanismHub = require("scripts/managers/mechanism/mechanisms/mechanism_hub")
local ConnectionManager = require("scripts/managers/multiplayer/connection_manager")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local HOST_TYPES = MatchmakingConstants.HOST_TYPES

local memory = mod:persistent_table("memory")
local disconnect_requested = false

function mod.on_game_state_changed(status, state_name)
	if state_name ~= "StateGameplay" then
		return
	end
	if status == "enter" then
		memory.in_game = true
	else
		memory.in_game = false
	end
end

local function retry_error()
	if not memory.in_game then
		return "err_not_in_game"
	end
	if not Managers.multiplayer_session then
		return "err_not_in_game"
	end
	if not Managers.party_immaterium:game_session_in_progress() then
		return "err_not_in_game"
	end
	local connection = Managers.connection
	if not connection or not connection:is_client() or Managers.multiplayer_session:host_type() ~= HOST_TYPES.mission_server then
		return "err_not_in_game"
	end
	if not connection:host() or not connection:host_channel() then
		return "err_not_in_game"
	end
	local players = Managers.player:players()
	local human = 0
	for _, player in pairs(players) do
		if player:is_human_controlled() and player.player_unit then
			human = human + 1
		end
	end
	if human < 2 then
		return "err_only_one_human"
	end
end

local function can_retry()
	return not retry_error()
		and not disconnect_requested
		and not Managers.multiplayer_session:is_leaving()
end

mod.retry_func = function ()
	local error_key = retry_error()
	if error_key then
		mod:echo(mod:localize(error_key))
		return
	end
	if disconnect_requested or Managers.multiplayer_session:is_leaving() then
		return
	end
	disconnect_requested = true
end

mod:hook(ConnectionManager, "update", function (func, self, dt)
	if disconnect_requested then
		disconnect_requested = false

		local host_peer_id = self:is_client() and self:host()
		local host_channel_id = self:is_client() and self:host_channel()

		if host_peer_id and host_channel_id then
			self:disconnect(host_peer_id)
		else
			mod:echo(mod:localize("err_not_in_game"))
		end
	end

	return func(self, dt)
end)

mod.retry_keybind_func = function ()
	if not Managers.ui:chat_using_input() then
		mod:retry_func()
	end
end

mod:command("retry", mod:localize("retry_description"), function ()
	mod:retry_func()
end)

local system_menu_button = {
	icon = "content/ui/materials/icons/system/escape/leave_mission",
	text = "loc_popup_reconnect_to_session_reconnect_button",
	type = "button",
	validation_function = function ()
		return mod:is_enabled()
			and mod:get("show_system_menu_button")
			and can_retry()
	end,
	trigger_function = function ()
		mod:retry_func()
	end,
}

mod:hook_require("scripts/ui/views/system_view/system_view_content_list", function (content)
	if table.find_by_key(content.default, "text", system_menu_button.text) then
		return
	end

	for index, entry in ipairs(content.default) do
		if entry.text == "loc_leave_mission_display_name" then
			table.insert(content.default, index, system_menu_button)
			return
		end
	end

	mod:error("Could not find the leave mission button in the system menu")
end)

mod:hook(StateMainMenu, "_show_reconnect_popup", function (func, self)
	local handle_rejoin_popup = mod:get("handle_rejoin_popup")
	if handle_rejoin_popup == "rejoin" then
		if self._reconnect_pressed then
			return
		end

		self._reconnect_pressed = true
		self:_rejoin_game()
		return
	elseif handle_rejoin_popup == "leave" then
		Managers.party_immaterium:leave_party()
		return
	end
	return func(self)
end)

mod:hook(MechanismHub, "_show_retry_popup", function (func, self)
	local handle_rejoin_popup = mod:get("handle_rejoin_popup")
	if handle_rejoin_popup == "rejoin" then
		self:_retry_join()
		return
	elseif handle_rejoin_popup == "leave" then
		Managers.party_immaterium:leave_party()
		return
	end
	return func(self)
end)
