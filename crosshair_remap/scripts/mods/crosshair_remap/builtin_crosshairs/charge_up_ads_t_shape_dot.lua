local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local template = {}
local length = 24
local thickness = 56
local size = {
	length,
	thickness
}
local mask_size = {
	length,
	thickness - 4
}
local center_size = {
	4,
	4
}
local spread_distance = 10
local hit_default_distance = 10
local hit_size = {
	14,
	4
}
template.name = "charge_up_ads_t_shape_dot"
template.size = size
template.hit_size = hit_size
template.center_size = center_size
template.spread_distance = spread_distance
template.hit_default_distance = hit_default_distance

local CROSS_SIZE = {
	12,
	4
}
local CROSS_HALF_SIZE_X = CROSS_SIZE[1] * 0.5
local CROSS_HALF_SIZE_Y = CROSS_SIZE[2] * 0.5
local CROSS_MIN_OFFSET = CROSS_HALF_SIZE_X + 3

local function _crosshair_segment(style_id, angle)
	return table.clone({
		value = "content/ui/materials/hud/crosshairs/long_spread",
		pass_type = "rotated_texture",
		style_id = style_id,
		style = {
			vertical_alignment = "center",
			horizontal_alignment = "center",
			angle = angle,
			offset = {
				0,
				0,
				10
			},
			size = {
				CROSS_SIZE[1],
				CROSS_SIZE[2]
			},
			color = UIHudSettings.color_tint_main_1
		}
	})
end

function template.create_widget_defintion(template, scenegraph_id)
	local center_half_width = center_size[1] * 0.5
	local offset_charge = 120
	local offset_charge_right = {
		offset_charge + center_half_width,
		0,
		1
	}
	local offset_charge_mask_right = {
		offset_charge + center_half_width,
		0,
		2
	}
	local offset_charge_left = {
		-(offset_charge + center_half_width),
		0,
		1
	}
	local offset_charge_mask_left = {
		-(offset_charge + center_half_width),
		0,
		2
	}

	return UIWidget.create_definition({
		Crosshair.center_dot(),
		Crosshair.hit_indicator_segment("top_left"),
		Crosshair.hit_indicator_segment("bottom_left"),
		Crosshair.hit_indicator_segment("top_right"),
		Crosshair.hit_indicator_segment("bottom_right"),
		Crosshair.weakspot_hit_indicator_segment("top_left"),
		Crosshair.weakspot_hit_indicator_segment("bottom_left"),
		Crosshair.weakspot_hit_indicator_segment("top_right"),
		Crosshair.weakspot_hit_indicator_segment("bottom_right"),
		_crosshair_segment("bottom", math.rad(90)),
		_crosshair_segment("left", math.rad(0)),
		_crosshair_segment("right", math.rad(180)),
		{
			value = "content/ui/materials/hud/crosshairs/charge_up",
			style_id = "charge_left",
			pass_type = "texture_uv",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				uvs = {
					{
						1,
						0
					},
					{
						0,
						1
					}
				},
				offset = offset_charge_left,
				size = size,
				color = UIHudSettings.color_tint_main_1
			}
		},
		{
			value = "content/ui/materials/hud/crosshairs/charge_up",
			style_id = "charge_right",
			pass_type = "texture",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = offset_charge_right,
				size = size,
				color = UIHudSettings.color_tint_main_1
			}
		},
		{
			value = "content/ui/materials/hud/crosshairs/charge_up_mask",
			style_id = "charge_mask_left",
			pass_type = "texture_uv",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				uvs = {
					{
						1,
						0
					},
					{
						0,
						1
					}
				},
				offset = offset_charge_mask_left,
				size = mask_size,
				color = UIHudSettings.color_tint_main_1
			}
		},
		{
			value = "content/ui/materials/hud/crosshairs/charge_up_mask",
			style_id = "charge_mask_right",
			pass_type = "texture_uv",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				uvs = {
					{
						0,
						1
					},
					{
						1,
						0
					}
				},
				offset = offset_charge_mask_right,
				size = mask_size,
				color = UIHudSettings.color_tint_main_1
			}
		}
	}, scenegraph_id)
end

function template.on_enter(widget, template, data)
	return
end

function template.update_function(parent, ui_renderer, widget, template, crosshair_settings, dt, t, draw_hit_indicator)
	local style = widget.style
	local hit_progress, hit_color, hit_weakspot = parent:hit_indicator()
	local yaw, pitch = parent:_spread_yaw_pitch(dt)
	local charge_level = parent:_get_current_charge_level() or 0

	if yaw and pitch then
		local scalar = spread_distance * (crosshair_settings.spread_scalar or 1)
		local spread_offset_y = pitch * scalar
		local spread_offset_x = yaw * scalar
		local bottom_style = style.bottom
		bottom_style.offset[1] = 0
		bottom_style.offset[2] = math.max(spread_offset_y + CROSS_HALF_SIZE_X, CROSS_MIN_OFFSET)
		local left_style = style.left
		left_style.offset[1] = math.min(-spread_offset_x - CROSS_HALF_SIZE_X, -CROSS_MIN_OFFSET)
		left_style.offset[2] = 0
		local right_style = style.right
		right_style.offset[1] = math.max(spread_offset_x + CROSS_HALF_SIZE_X, CROSS_MIN_OFFSET)
		right_style.offset[2] = 0
	end

	local mask_height = mask_size[2]
	local mask_height_charged = mask_height * charge_level
	local mask_height_offset_charged = mask_height * (1 - charge_level) * 0.5
	local charge_mask_right_style = style.charge_mask_right
	charge_mask_right_style.uvs[1][2] = charge_level
	charge_mask_right_style.size[2] = mask_height_charged
	charge_mask_right_style.offset[2] = mask_height_offset_charged
	local charge_mask_left_style = style.charge_mask_left
	charge_mask_left_style.uvs[1][2] = 1 - charge_level
	charge_mask_left_style.size[2] = mask_height_charged
	charge_mask_left_style.offset[2] = mask_height_offset_charged

	Crosshair.update_hit_indicator(style, hit_progress, hit_color, hit_weakspot, draw_hit_indicator)
end

return template
