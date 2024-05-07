local mod = get_mod("MissionProgressBar")

local hud_element = {
	class_name = "HudElementMissionProgress",
	filename = "MissionProgressBar/scripts/mods/MissionProgressBar/HudElementMissionProgress",
	visibility_groups = {
		"dead",
		"alive",
		"communication_wheel",
	},
}

mod:add_require_path(hud_element.filename)

mod.cache = mod:persistent_table("cache")
function mod.on_game_state_changed(status, state_name)
	if state_name ~= "StateGameplay" then
		return
	end
	mod.cache["furthest_pos"] = nil
end

local function add_hud_element(elements)
	local i, t = table.find_by_key(elements, "class_name", hud_element.class_name)
	if not i or not t then
		table.insert(elements, hud_element)
	else
		elements[i] = hud_element
	end
end

mod:hook_require("scripts/ui/hud/hud_elements_player", add_hud_element)
