local mod = get_mod("SoloPlayStratagems")
mod:io_dofile("SoloPlayStratagems/scripts/mods/SoloPlayStratagems/airstrike")

local PACKAGES = {
	"content/levels/expeditions/airstrikes/airstrikes_01/world",
	"content/levels/expeditions/airstrikes/airstrikes_02/world",
	"packages/game_mode/expedition",
}

mod.load_package = function (package_name)
	if not Managers.package:is_loading(package_name) and not Managers.package:has_loaded(package_name) then
		Managers.package:load(package_name, "solo_play_stratagems", nil, true)
	end
end

mod.on_all_mods_loaded = function ()
	for i = 1, #PACKAGES do
		mod.load_package(PACKAGES[i])
	end
end

mod.is_server = function ()
	local game_session_manager = Managers.state and Managers.state.game_session
	return game_session_manager and game_session_manager:is_server()
end

mod.game_world = function ()
	local world_manager = Managers.world
	local world_name = "level_world"
	return world_manager and world_manager:has_world(world_name) and world_manager:world(world_name) or nil
end

mod.on_game_state_changed = function (status, state_name)
	if state_name == "StateGameplay" then
		if status == "enter" then
			mod.airstrike_register_events()
		elseif status == "exit" then
			mod.airstrike_unregister_events()
			mod.airstrike_destroy()
		end
	end
end

mod.on_disabled = function ()
	mod.airstrike_unregister_events()
	mod.airstrike_destroy()
end

mod:hook_safe("GameplayStateRun", "update", function ()
	mod.airstrike_update()
end)
