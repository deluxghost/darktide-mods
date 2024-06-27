local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {
	name = "chevron",
	create_widget_defintion = function (template, scenegraph_id)
		return UIWidget.create_definition({
			{
				value = "content/ui/materials/dividers/divider_line_01",
				pass_type = "rotated_texture",
				style_id = "hit_border_l1",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					offset = { 0, 5, 10 },
					size = { 2, 11 },
					pivot = { 1, 0 },
					angle = -math.pi / 4,
					color = Color.citadel_nuln_oil(216, true),
				}
			},
			{
				value = "content/ui/materials/dividers/divider_line_01",
				pass_type = "rotated_texture",
				style_id = "hit_border_l2",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					offset = { 0, 8, 10 },
					size = { 2, 7 },
					pivot = { 1, 0 },
					angle = -math.pi / 4,
					color = Color.citadel_nuln_oil(216, true),
				}
			},
			{
				value = "content/ui/materials/dividers/divider_line_01",
				pass_type = "rotated_texture",
				style_id = "hit_border_r1",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					offset = { 0, 5, 10 },
					size = { 2, 11 },
					pivot = { 1, 0 },
					angle = math.pi / 4,
					color = Color.citadel_nuln_oil(216, true),
				}
			},
			{
				value = "content/ui/materials/dividers/divider_line_01",
				pass_type = "rotated_texture",
				style_id = "hit_border_r2",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					offset = { 0, 8, 10 },
					size = { 2, 7 },
					pivot = { 1, 0 },
					angle = math.pi / 4,
					color = Color.citadel_nuln_oil(216, true),
				}
			},
			{
				value = "content/ui/materials/buttons/arrow_01",
				style_id = "center",
				pass_type = "rotated_texture",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					offset = { 0, 5, 1 },
					size = { 14, 14 },
					pivot = { 7, 7 },
					angle = math.pi / 2,
					color = UIHudSettings.color_tint_main_1,
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
