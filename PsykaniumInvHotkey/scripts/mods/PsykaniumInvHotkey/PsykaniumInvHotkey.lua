local mod = get_mod("PsykaniumInvHotkey")
local GameModeSettings = require("scripts/settings/game_mode/game_mode_settings")

mod.on_enabled = function(initial_call)
	GameModeSettings.shooting_range.hotkeys.hotkeys["hotkey_inventory"] = "inventory_background_view"
	GameModeSettings.shooting_range.hotkeys.lookup["inventory_background_view"] = "hotkey_inventory"
end

mod.on_disabled = function(initial_call)
	GameModeSettings.shooting_range.hotkeys.hotkeys["hotkey_inventory"] = nil
	GameModeSettings.shooting_range.hotkeys.lookup["inventory_background_view"] = nil
end
