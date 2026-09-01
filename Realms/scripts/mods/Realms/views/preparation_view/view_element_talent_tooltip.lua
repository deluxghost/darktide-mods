local mod = get_mod("Realms")
local LobbyViewDefinitions = require("scripts/ui/views/lobby_view/lobby_view_definitions")
local ScriptWorld = require("scripts/foundation/utilities/script_world")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local ViewElementBase = require("scripts/ui/view_elements/view_element_base")

local definitions = {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		talent_tooltip = table.clone(LobbyViewDefinitions.scenegraph_definition.talent_tooltip),
	},
	widget_definitions = {
		talent_tooltip = table.clone(LobbyViewDefinitions.widget_definitions.talent_tooltip),
	},
}
local ViewElementTalentTooltip = class("ViewElementTalentTooltip", "ViewElementBase")

ViewElementTalentTooltip.init = function (self, parent, draw_layer, start_scale)
	ViewElementTalentTooltip.super.init(self, parent, draw_layer, start_scale, definitions)

	self._unique_id = self.__class_name .. "_" .. string.gsub(tostring(self), "table: ", "")

	local ui_manager = Managers.ui
	local world_name = self._unique_id .. "_world"
	local world_layer = 101 + self._draw_layer
	local viewport_name = self._unique_id .. "_viewport"
	local renderer_name = self._unique_id .. "_renderer"

	self._world = ui_manager:create_world(world_name, world_layer, "ui", parent.view_name)
	self._viewport = ui_manager:create_viewport(self._world, viewport_name, "overlay", 1)
	self._viewport_name = viewport_name
	self._renderer_name = renderer_name
	self._renderer = ui_manager:create_renderer(renderer_name, self._world)
end

ViewElementTalentTooltip.destroy = function (self)
	ViewElementTalentTooltip.super.destroy(self, self._renderer)
	Managers.ui:destroy_renderer(self._renderer_name)
	ScriptWorld.destroy_viewport(self._world, self._viewport_name)
	Managers.ui:destroy_world(self._world)
end

ViewElementTalentTooltip.draw = function (self, dt, t, ui_renderer, render_settings, input_service)
	ViewElementTalentTooltip.super.draw(self, dt, t, self._renderer, render_settings, input_service)
end

ViewElementTalentTooltip.widget = function (self)
	return self._widgets_by_name.talent_tooltip
end

ViewElementTalentTooltip.size = function (self)
	return self:_scenegraph_size("talent_tooltip")
end

ViewElementTalentTooltip.set_height = function (self, height)
	self:_set_scenegraph_size("talent_tooltip", nil, height)
end

ViewElementTalentTooltip.set_position = function (self, x, y)
	self:_set_scenegraph_position("talent_tooltip", x, y)
end

return ViewElementTalentTooltip
