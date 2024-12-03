local mod = get_mod("WarpUnboundTimer")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local definitions = {
  	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		timer_area  = {
			parent = "screen",
			size = { 200, 100 },
			vertical_alignment = "center",
			horizontal_alignment = "center",
			position = { 0, -190, 5 }
		}
  	},
  	widget_definitions = {
		timer_text = UIWidget.create_definition({
			{
				pass_type = "text",
				value = "",
				value_id = "timer",
				style_id = "timer",
				style = {
					font_type = "machine_medium",
					font_size = 30,
					drop_shadow = true,
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					text_color = Color.ui_hud_warp_charge_high(255, true),
					offset = { 0, 0, 100 }
				}
			}
		}, "timer_area")
  	}
}

HudElementWarpUnboundTimer = class("HudElementWarpUnboundTimer", "HudElementBase")

function HudElementWarpUnboundTimer:init(parent, draw_layer, start_scale)
  	HudElementWarpUnboundTimer.super.init(self, parent, draw_layer, start_scale, definitions)
end

HudElementWarpUnboundTimer.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudElementWarpUnboundTimer.super.update(self, dt, t, ui_renderer, render_settings, input_service)
	local base_font_size = 30 * mod:get("hud_scale")

	local player = Managers.player:local_player(1)
	if not player or not player.player_unit then
		self._widgets_by_name.timer_text.content.timer = ""
		self._widgets_by_name.timer_text.style.timer.font_size = base_font_size
		return
	end
	local archetype = player:archetype_name()
	if archetype ~= "psyker" then
		self._widgets_by_name.timer_text.content.timer = ""
		self._widgets_by_name.timer_text.style.timer.font_size = base_font_size
		return
	end
	local profile = player:profile()
	if not profile or not profile.talents or not profile.talents.psyker_overcharge_stance_infinite_casting then
		self._widgets_by_name.timer_text.content.timer = ""
		self._widgets_by_name.timer_text.style.timer.font_size = base_font_size
		return
	end
	local buff_extensions = ScriptUnit.extension(player.player_unit, "buff_system")
	if not buff_extensions then
		self._widgets_by_name.timer_text.content.timer = ""
		self._widgets_by_name.timer_text.style.timer.font_size = base_font_size
		return
	end
	local timer = 0
	for _, buff in pairs(buff_extensions._buffs_by_index) do
		local template = buff:template()
		if template.name == "psyker_overcharge_stance_infinite_casting" then
			local remaining = buff:duration_progress() or 1
			timer = math.max(timer, buff:duration() * remaining)
		end
	end
	if timer == 0 then
		self._widgets_by_name.timer_text.content.timer = ""
		self._widgets_by_name.timer_text.style.timer.font_size = base_font_size
		return
	end
	self._widgets_by_name.timer_text.content.timer = string.format("%.1f", timer)
	local inc_font_size = base_font_size * 0.333
	self._widgets_by_name.timer_text.style.timer.font_size = base_font_size + (inc_font_size - math.min(inc_font_size, timer)) * 2
end

return HudElementWarpUnboundTimer
