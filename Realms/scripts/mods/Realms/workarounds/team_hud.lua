local mod = get_mod("Realms")
local HudElementTeamPanelHandlerSettings = require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler_settings")

local HudElementTeamPanelHandler = require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler")
local HudElementTeamPlayerPanel = require("scripts/ui/hud/elements/team_player_panel/hud_element_team_player_panel")
local PlayerCompositions = require("scripts/utilities/players/player_compositions")

local TeamHud = {}

local function ensure_position_scenegraphs(definitions, max_panels)
	local settings = HudElementTeamPanelHandlerSettings
	local scenegraphs = definitions.scenegraph_definition
	local panel_size = settings.panel_size
	local panel_spacing = settings.panel_spacing

	for i = 1, max_panels - 1 do
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

local function grow_panel_capacity(self, ui_renderer, capacity)
	local definitions = table.clone(self._definitions)

	-- Rebuild only the handler's position graph; retain existing panel instances and live layout.
	for id, definition in pairs(definitions.scenegraph_definition) do
		local current = self._ui_scenegraph[id]

		definition.position = table.clone(current.local_position)
		definition.size = table.clone(current.size)
		definition.horizontal_alignment = current.horizontal_alignment
		definition.vertical_alignment = current.vertical_alignment
	end

	ensure_position_scenegraphs(definitions, capacity)
	self._definitions = definitions
	self._ui_scenegraph = self:_create_scenegraph(definitions, ui_renderer.scale or 1)
	self._max_panels = capacity
	self._position_scenegraphs = self:_setup_position_scenegraphs()
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
		local definitions = require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler_definitions")

		ensure_position_scenegraphs(definitions, HudElementTeamPanelHandlerSettings.max_panels)

		return func(self, ...)
	end)

	local temp_players = {}

	mod:hook(HudElementTeamPanelHandler, "_player_scan", function (func, self, ui_renderer)
		local players = PlayerCompositions.players(self._player_composition_name, temp_players)
		local capacity = table.size(players)

		if capacity > self._max_panels then
			grow_panel_capacity(self, ui_renderer, capacity)
		end

		return func(self, ui_renderer)
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
