local mod = get_mod("PreferAuric")
local MissionBoardView = require("scripts/ui/views/mission_board_view/mission_board_view")

mod.on_enabled = function()
	mod:set("_last_mission_board_selection", mod:get("_last_mission_board_selection") or "normal", false)
end

mod:hook_safe(MissionBoardView, "init", function(self, settings)
	local preference = mod:get("mission_board_preference")
	if preference == "_last_selection" then
		self._selected_mission_type = mod:get("_last_mission_board_selection") or "normal"
	else
		self._selected_mission_type = preference or "normal"
	end
end)

mod:hook_safe(MissionBoardView, "_callback_switch_mission_board", function(self, mission_type)
	mod:set("_last_mission_board_selection", mission_type or "normal", false)
end)

mod:hook_safe(MissionBoardView, "_setup_widgets", function(self)
	mod:set("_last_mission_board_selection", self._selected_mission_type or "normal", false)
end)
