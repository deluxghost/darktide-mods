local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {
	name = "small_circle",
	create_widget_defintion = function (template, scenegraph_id)
		return UIWidget.create_definition({
			{
				value = "〇",
				pass_type = "text",
				style_id = "center",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					offset = { 0, 0, 1 },
					size = { 20, 20 },
					drop_shadow = false,
					font_type = "arial",
					font_size = 16,
					color = UIHudSettings.color_tint_main_1, -- HACK
					text_color = UIHudSettings.color_tint_main_1,
				},
				visibility_function = function(content, style)
					if style.color then
						style.text_color = style.color
					end
					return true
				end,
			},
			{
				value = "〇",
				pass_type = "text",
				style_id = "hit_border_inner",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					offset = { 0, 0, 0 },
					size = { 20, 20 },
					drop_shadow = false,
					font_type = "arial",
					font_size = 13,
					text_color = Color.citadel_nuln_oil(216, true),
				}
			},
			{
				value = "〇",
				pass_type = "text",
				style_id = "hit_border_outer",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					offset = { 0, 0, 0 },
					size = { 20, 20 },
					drop_shadow = false,
					font_type = "arial",
					font_size = 19,
					text_color = Color.citadel_nuln_oil(216, true),
				}
			},
			Crosshair.hit_indicator_segment("top_left"),
			Crosshair.hit_indicator_segment("bottom_left"),
			Crosshair.hit_indicator_segment("top_right"),
			Crosshair.hit_indicator_segment("bottom_right"),
			Crosshair.weakspot_hit_indicator_segment("top_left"),
			Crosshair.weakspot_hit_indicator_segment("bottom_left"),
			Crosshair.weakspot_hit_indicator_segment("top_right"),
			Crosshair.weakspot_hit_indicator_segment("bottom_right")
		}, scenegraph_id)
	end,
	on_enter = function (widget, template, data)
		return
	end
}

function template.update_function(parent, ui_renderer, widget, template, crosshair_settings, dt, t, draw_hit_indicator)
	local style = widget.style
	local hit_progress, hit_color, hit_weakspot = parent:hit_indicator()

	Crosshair.update_hit_indicator(style, hit_progress, hit_color, hit_weakspot, draw_hit_indicator)
end

return template
