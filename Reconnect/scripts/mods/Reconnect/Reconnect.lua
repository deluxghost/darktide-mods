local mod = get_mod("Reconnect")
local StateMainMenu = require("scripts/game_states/game/state_main_menu")
local MechanismHub = require("scripts/managers/mechanism/mechanisms/mechanism_hub")
local memory = mod:persistent_table("memory")

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

mod.retry_func = function()
	if not memory.in_game then
		mod:echo(mod:localize("err_not_in_game"))
		return
	end
	if not Managers.multiplayer_session then
		mod:echo(mod:localize("err_not_in_game"))
		return
	end
	if not Managers.party_immaterium:game_session_in_progress() then
		mod:echo(mod:localize("err_not_in_game"))
		return
	end
	local players = Managers.player:players()
	local human = 0
	for _, player in pairs(players) do
		if player:is_human_controlled() and player.player_unit then
			human = human + 1
		end
	end
	if human < 2 then
		mod:echo(mod:localize("err_only_one_human"))
		return
	end
	Managers.multiplayer_session:leave("pong_timeout")
end

mod.retry_keybind_func = function()
	if not Managers.ui:chat_using_input() then
		mod:retry_func()
	end
end

mod:command("retry", mod:localize("retry_description"), function()
	mod:retry_func()
end)

mod:hook(StateMainMenu, "_show_reconnect_popup", function(func, self)
	local handle_rejoin_popup = mod:get("handle_rejoin_popup")
	if handle_rejoin_popup == "rejoin" then
		self._reconnect_pressed = true
		self:_rejoin_game()
		return
	elseif handle_rejoin_popup == "leave" then
		Managers.party_immaterium:leave_party()
		return
	end
	return func(self)
end)

mod:hook(MechanismHub, "_show_retry_popup", function(func, self)
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
