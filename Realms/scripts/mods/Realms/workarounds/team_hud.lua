local mod = get_mod("Realms")
local HudElementTeamPanelHandlerSettings = require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler_settings")

local MINIMUM_PLAYER_PANELS = 8

HudElementTeamPanelHandlerSettings.max_panels = math.max(HudElementTeamPanelHandlerSettings.max_panels, MINIMUM_PLAYER_PANELS)

local HudElementTeamPanelHandler = require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler")
local HudElementTeamPlayerPanel = require("scripts/ui/hud/elements/team_player_panel/hud_element_team_player_panel")
local PlayerCompositions = require("scripts/utilities/players/player_compositions")

local TeamHud = {}

local function ensure_position_scenegraphs()
	local settings = HudElementTeamPanelHandlerSettings

	settings.max_panels = math.max(settings.max_panels, MINIMUM_PLAYER_PANELS)

	local definitions = require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler_definitions")
	local scenegraphs = definitions.scenegraph_definition
	local panel_size = settings.panel_size
	local panel_spacing = settings.panel_spacing

	for i = 1, settings.max_panels - 1 do
		local scenegraph_id = "player_" .. i

		if not scenegraphs[scenegraph_id] then
			local previous = scenegraphs["player_" .. (i - 1)]
			local reference = previous or scenegraphs.local_player
			local position

			if previous then
				position = {
					previous.position[1] + panel_spacing[1],
					previous.position[2] - panel_size[2] - panel_spacing[2],
					previous.position[3],
				}
			else
				local panel_offset = settings.panel_offset

				position = {
					reference.position[1] + panel_offset[1],
					reference.position[2] + panel_offset[2] - reference.size[2],
					panel_offset[3],
				}
			end

			scenegraphs[scenegraph_id] = {
				horizontal_alignment = reference.horizontal_alignment,
				parent = reference.parent,
				vertical_alignment = reference.vertical_alignment,
				size = {panel_size[1], panel_size[2]},
				position = position,
			}
		end
	end
end

local function uses_training_grounds_hud()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

	return game_mode_name == "shooting_range" or game_mode_name == "training_grounds"
end

local function realms_human_players(result_table, dont_clear_table)
	if not dont_clear_table then
		table.clear(result_table)
	end

	for unique_id, player in pairs(Managers.player:human_players()) do
		result_table[unique_id] = player
	end

	return result_table
end

function TeamHud.install(Session)
	mod:hook(HudElementTeamPanelHandler, "init", function (func, self, ...)
		ensure_position_scenegraphs()

		return func(self, ...)
	end)

	mod:hook(HudElementTeamPanelHandler, "_add_panel", function (func, self, unique_id, ui_renderer, fixed_scenegraph_id)
		func(self, unique_id, ui_renderer, fixed_scenegraph_id)

		if not Session.is_active() or not uses_training_grounds_hud() then
			return
		end

		local panel_data = self._player_panel_by_unique_id[unique_id]

		if not panel_data or panel_data.is_my_player or panel_data.panel.__class_name ~= "HudElementTeamPlayerPanelHub" then
			return
		end

		panel_data.panel:destroy(ui_renderer)

		local scale = ui_renderer.scale or 1

		panel_data.panel = HudElementTeamPlayerPanel:new(self._parent, self._draw_layer, scale, panel_data)
		mod:info("Using mission team panel for training-grounds peer=%s", tostring(panel_data.player:peer_id()))
	end)

	mod:hook(PlayerCompositions, "players", function (func, composition_name, result_table, dont_clear_table)
		if composition_name == "party" and Session.is_active() and uses_training_grounds_hud() then
			return realms_human_players(result_table, dont_clear_table)
		end

		return func(composition_name, result_table, dont_clear_table)
	end)

	mod:hook(PlayerCompositions, "player_from_unique_id", function (func, composition_name, unique_id)
		local player = func(composition_name, unique_id)

		if not player and composition_name == "party" and Session.is_active() and uses_training_grounds_hud() then
			return Managers.player:player_from_unique_id(unique_id)
		end

		return player
	end)
end

return TeamHud
