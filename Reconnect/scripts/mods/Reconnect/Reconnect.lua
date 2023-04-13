local mod = get_mod("Reconnect")

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

mod:command("retry", "Reconnect", function()
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
    Managers.multiplayer_session:_leave("")
end)
