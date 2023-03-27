local mod = get_mod("SpectatorHUD")
local HUDElementsSpectator = require("scripts/ui/hud/hud_elements_spectator")

local hud_data = {
	HudElementTeamPanelHandler = {
		package = "packages/ui/hud/team_player_panel/team_player_panel",
		use_retained_mode = true,
		use_hud_scale = true,
		class_name = "HudElementTeamPanelHandler",
		filename = "scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler",
		visibility_groups = {
			"dead",
			"alive",
			"communication_wheel",
			"tactical_overlay"
		}
	},
	HudElementBossHealth = {
		package = "packages/ui/hud/boss_health/boss_health",
		use_hud_scale = true,
		class_name = "HudElementBossHealth",
		filename = "scripts/ui/hud/elements/boss_health/hud_element_boss_health",
		visibility_groups = {
			"dead",
			"alive",
			"communication_wheel"
		}
	},
	HudElementTacticalOverlay = {
		package = "packages/ui/hud/tactical_overlay/tactical_overlay",
		use_hud_scale = false,
		class_name = "HudElementTacticalOverlay",
		filename = "scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay",
		visibility_groups = {
			"tactical_overlay",
			"dead",
			"alive",
			"communication_wheel"
		}
	},
	HudElementCrosshair = {
		package = "packages/ui/hud/crosshair/crosshair",
		use_hud_scale = true,
		class_name = "HudElementCrosshair",
		filename = "scripts/ui/hud/elements/crosshair/hud_element_crosshair",
		visibility_groups = {
			"alive",
			"dead"
		}
	},
	HudElementMissionObjectiveFeed = {
		package = "packages/ui/hud/mission_objective_feed/mission_objective_feed",
		use_hud_scale = true,
		class_name = "HudElementMissionObjectiveFeed",
		filename = "scripts/ui/hud/elements/mission_objective_feed/hud_element_mission_objective_feed",
		visibility_groups = {
			"dead",
			"alive",
			"communication_wheel",
			"tactical_overlay"
		}
	},
	HudElementMissionObjectivePopup = {
		package = "packages/ui/hud/mission_objective_popup/mission_objective_popup",
		use_hud_scale = true,
		class_name = "HudElementMissionObjectivePopup",
		filename = "scripts/ui/hud/elements/mission_objective_popup/hud_element_mission_objective_popup",
		visibility_groups = {
			"dead",
			"alive",
			"communication_wheel",
			"tactical_overlay"
		}
	},
	HudElementCombatFeed = {
		use_hud_scale = true,
		class_name = "HudElementCombatFeed",
		filename = "scripts/ui/hud/elements/combat_feed/hud_element_combat_feed",
		visibility_groups = {
			"dead",
			"alive",
			"communication_wheel",
			"tactical_overlay"
		}
	},
	HudElementWorldMarkers = {
		package = "packages/ui/hud/world_markers/world_markers",
		use_hud_scale = false,
		class_name = "HudElementWorldMarkers",
		filename = "scripts/ui/hud/elements/world_markers/hud_element_world_markers",
		visibility_groups = {
			"dead",
			"alive",
			"communication_wheel"
		}
	},
}

mod.on_enabled = function(initial_call)
	local m = {}
	for _, elem in ipairs(HUDElementsSpectator) do
		m[elem.class_name] = true
	end
	for key, value in pairs(hud_data) do
		if m[key] == nil then
			table.insert(HUDElementsSpectator, value)
		end
	end
end

mod.on_disabled = function(initial_call)
	for i = #HUDElementsSpectator, 1, -1 do
		if hud_data[HUDElementsSpectator[i].class_name] ~= nil then
			table.remove(HUDElementsSpectator, i)
		end
	end
end
