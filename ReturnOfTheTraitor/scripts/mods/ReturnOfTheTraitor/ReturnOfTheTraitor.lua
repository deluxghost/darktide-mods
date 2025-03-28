local mod = get_mod("ReturnOfTheTraitor")
local FlowCallbacks = require("scripts/script_flow_nodes/flow_callbacks")
local UIFlowCallbacks = require("scripts/script_flow_nodes/ui_flow_callbacks")

mod:hook(FlowCallbacks, "local_player_level_larger_than", function (func, params)
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	local ret = func(params)
	if not params.target_level or params.target_level ~= 30 then
		return ret
	end
	if game_mode_name == "hub" or game_mode_name == "prologue_hub" then
		ret.level_larger_than = mod:get("commissary_vendor") ~= "traitor"
	end
	return ret
end)

mod:hook(UIFlowCallbacks, "local_player_level_larger_than", function (func, params)
	local ret = func(params)
	if not params.target_level or params.target_level ~= 30 then
		return ret
	end
	if Managers.ui:active_top_view() == "cosmetics_vendor_background_view" then
		ret.level_larger_than = mod:get("commissary_vendor") ~= "traitor"
	end
	return ret
end)
