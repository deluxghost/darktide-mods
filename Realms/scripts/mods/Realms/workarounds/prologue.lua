local mod = get_mod("Realms")
local DoorControlPanelExtension = require("scripts/extension_systems/door_control_panel/door_control_panel_extension")
local GameModeBase = require("scripts/managers/game_mode/game_modes/game_mode_base")

local Prologue = {}
local GAME_MODE_NAME = "prologue"

local function is_prologue()
	local game_mode_manager = Managers.state and Managers.state.game_mode

	return game_mode_manager and game_mode_manager:game_mode_name() == GAME_MODE_NAME
end

function Prologue.install(Session)
	mod:hook(GameModeBase, "init", function (func, self, game_mode_context, game_mode_name, network_event_delegate)
		func(self, game_mode_context, game_mode_name, network_event_delegate)

		if game_mode_name ~= GAME_MODE_NAME or game_mode_context.is_server or not Session.is_active_client() then
			return
		end

		self._settings = table.clone(self._settings)
		self._settings.use_prologue_profile = false
	end)

	mod:hook(DoorControlPanelExtension, "hot_join_sync", function (func, self, unit, sender)
		if Session.is_active_host() and is_prologue() and not self._door_unit then
			return
		end

		return func(self, unit, sender)
	end)
end

return Prologue
