local mod = get_mod("SimpleSpeedMeter")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local definitions = {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		speed_area  = {
			parent = "screen",
			size = { 150, 50 },
			vertical_alignment = "top",
			horizontal_alignment = "right",
			position = { -20, 20, 100 },
		}
	},
	widget_definitions = {
		speed_text = UIWidget.create_definition({
			{
				pass_type = "text",
				value = "",
				value_id = "speed",
				style_id = "speed",
				style = {
					font_type = "machine_medium",
					font_size = 28,
					drop_shadow = true,
					text_vertical_alignment = "top",
					text_horizontal_alignment = "right",
					text_color = Color.terminal_text_body(255, true),
					offset = { 0, 0, 100 },
				},
			}
		}, "speed_area")
	}
}

HudElementSpeed = class("HudElementSpeed", "HudElementBase")

function HudElementSpeed:init(parent, draw_layer, start_scale)
	HudElementSpeed.super.init(self, parent, draw_layer, start_scale, definitions)
end

HudElementSpeed.update = function (self, dt, t, ui_renderer, render_settings, input_service)
	HudElementSpeed.super.update(self, dt, t, ui_renderer, render_settings, input_service)
	local player = Managers.player:local_player(1)
	if player and player:unit_is_alive() then
		local player_unit = player.player_unit
		if player_unit then
			local locomotion_extension = ScriptUnit.has_extension(player_unit, "locomotion_system")
			if locomotion_extension then
				local velocity = locomotion_extension:current_velocity()
				if velocity ~= nil then
					self._widgets_by_name.speed_text.content.speed = string.format("%s: %.2f", mod:localize("speed_title"), Vector3.length(velocity))
					return
				end
			end
		end
	end
	self._widgets_by_name.speed_text.content.speed = ""
end

return HudElementSpeed
