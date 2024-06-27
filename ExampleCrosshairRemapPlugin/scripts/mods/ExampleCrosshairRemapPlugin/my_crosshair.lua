-- simple green dot crosshair as an example
-- modified from https://github.com/Aussiemon/Darktide-Source-Code/blob/master/scripts/ui/hud/elements/crosshair/templates/crosshair_template_dot_new.lua

local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {
	-- crosshair name
	name = "my_crosshair",
	create_widget_defintion = function (template, scenegraph_id)
		return UIWidget.create_definition({
			{
				value = "content/ui/materials/hud/crosshairs/center_dot",
				style_id = "center",
				pass_type = "texture",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					offset = {
						0,
						0,
						1
					},
					size = {
						8,
						8
					},
					color = Color.spring_green(255, true)
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
