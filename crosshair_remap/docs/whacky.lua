-- Mandatory, need it to create widgets.
local UIWidget = require("scripts/managers/ui/ui_widget")

-- Optional. There are some predefined colors in it.
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

-- We will return a crosshair template at the end.
-- Your template will be used in scripts/ui/hud/elements/crosshair/hud_element_crosshair.lua
-- More on that later.
local template = {}

-- Just name it the same as our file name.
template.name = "whacky"

-- Game will call this function to know what your crosshair would look like.
-- You need to return a list of stuff that make up of your crosshair.
-- "defintion": yes it is a typo by FS devs, keep it.
template.create_widget_defintion = function(template, scenegraph_id)
	local center_size = { 30, 30 }
	local leg_size = { 20, 30 }
	local hit_size = { 12, 2 }
	local hit_default_distance = 2
	local center_half_width = center_size[1] * 0.5
	local leg_offset = leg_size[1] + center_half_width
	local offset_up_left = {
		-leg_offset * 0.87,
		-leg_offset * 0.5,
		1
	}
	local offset_up_right = {
		leg_offset * 0.87,
		-leg_offset * 0.5,
		1
	}
	local offset_bottom_left = {
		-leg_offset * 0.87,
		leg_offset * 0.5,
		1
	}
	local offset_bottom_right = {
		leg_offset * 0.87,
		leg_offset * 0.5,
		1
	}

	return UIWidget.create_definition({
		-- Parts of our crosshair.
		{
			value = "content/ui/materials/hud/interactions/icons/objective_main",
			style_id = "center",
			pass_type = "texture",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = {
					0,
					0,
					0
				},
				size = center_size,
				color = UIHudSettings.color_tint_main_1
			}
		},
		{
			value = "content/ui/materials/icons/player_states/incapacitated",
			style_id = "up_left",
			pass_type = "rotated_texture",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				angle = math.pi / 3,
				offset = offset_up_left,
				default_offset = offset_up_left,
				size = leg_size,
				color = UIHudSettings.color_tint_main_1
			}
		},
		{
			value = "content/ui/materials/icons/player_states/incapacitated",
			style_id = "up_right",
			pass_type = "rotated_texture",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				angle = -math.pi / 3,
				offset = offset_up_right,
				default_offset = offset_up_right,
				size = leg_size,
				color = UIHudSettings.color_tint_main_1
			}
		},
		{
			value = "content/ui/materials/icons/player_states/incapacitated",
			style_id = "bottom_left",
			pass_type = "rotated_texture",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				angle = math.pi * 2 / 3,
				offset = offset_bottom_left,
				default_offset = offset_bottom_left,
				size = leg_size,
				color = UIHudSettings.color_tint_main_1
			}
		},
		{
			value = "content/ui/materials/icons/player_states/incapacitated",
			style_id = "bottom_right",
			pass_type = "rotated_texture",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				angle = -math.pi * 2 / 3,
				offset = offset_bottom_right,
				default_offset = offset_bottom_right,
				size = leg_size,
				color = UIHudSettings.color_tint_main_1
			}
		},
		{
			value = "content/ui/materials/backgrounds/default_square",
			style_id = "hit_top_left",
			pass_type = "rotated_texture",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "right",
				offset = {
					-center_half_width - hit_default_distance,
					-center_half_width - hit_default_distance,
					0
				},
				size = {
					hit_size[1],
					hit_size[2]
				},
				pivot = {
					hit_size[1],
					hit_size[2] * 0.5
				},
				angle = -math.pi / 4,
				color = {
					255,
					255,
					255,
					0
				}
			}
		},
		{
			value = "content/ui/materials/backgrounds/default_square",
			style_id = "hit_bottom_left",
			pass_type = "rotated_texture",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "right",
				offset = {
					-center_half_width - hit_default_distance,
					center_half_width + hit_default_distance,
					0
				},
				size = {
					hit_size[1],
					hit_size[2]
				},
				pivot = {
					hit_size[1],
					hit_size[2] * 0.5
				},
				angle = math.pi / 4,
				color = {
					255,
					255,
					255,
					0
				}
			}
		},
		{
			value = "content/ui/materials/backgrounds/default_square",
			style_id = "hit_top_right",
			pass_type = "rotated_texture",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "left",
				offset = {
					center_half_width + hit_default_distance,
					-center_half_width - hit_default_distance,
					0
				},
				size = {
					hit_size[1],
					hit_size[2]
				},
				pivot = {
					0,
					hit_size[2] * 0.5
				},
				angle = math.pi / 4,
				color = {
					255,
					255,
					255,
					0
				}
			}
		},
		{
			value = "content/ui/materials/backgrounds/default_square",
			style_id = "hit_bottom_right",
			pass_type = "rotated_texture",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "left",
				offset = {
					center_half_width + hit_default_distance,
					center_half_width + hit_default_distance,
					0
				},
				size = {
					hit_size[1],
					hit_size[2]
				},
				pivot = {
					0,
					hit_size[2] * 0.5
				},
				angle = -math.pi / 4,
				color = {
					255,
					255,
					255,
					0
				}
			}
		},
	}, scenegraph_id)
end

-- IDK, just keep it.
template.on_enter = function(widget, template, data)
	return
end

-- Helper function.
local function apply_color_values(destination_color, target_color, include_alpha, optional_alpha)
	if include_alpha then
		destination_color[1] = target_color[1]
	end

	if optional_alpha then
		destination_color[1] = optional_alpha
	end

	destination_color[2] = target_color[2]
	destination_color[3] = target_color[3]
	destination_color[4] = target_color[4]

	return destination_color
end

-- Update spread and hitmarker color, called by game.
template.update_function = function(parent, ui_renderer, widget, template, dt, t)
	local content = widget.content
	local style = widget.style

	-- Update crosshair based on spread.

	local hit_progress, hit_color = parent:hit_indicator()
	local yaw, pitch = parent:_spread_yaw_pitch(dt)

	if yaw and pitch then
		local spread_distance = 10
		local spread_offset_y = spread_distance * pitch
		local spread_offset_x = spread_distance * yaw
		local up_left_style = style.up_left
		up_left_style.offset[1] = up_left_style.default_offset[1] - spread_offset_x * 0.87
		up_left_style.offset[2] = up_left_style.default_offset[2] - spread_offset_y * 0.5
		local up_right_style = style.up_right
		up_right_style.offset[1] = up_right_style.default_offset[1] + spread_offset_x * 0.87
		up_right_style.offset[2] = up_right_style.default_offset[2] - spread_offset_y * 0.5
		local bottom_left_style = style.bottom_left
		bottom_left_style.offset[1] = bottom_left_style.default_offset[1] - spread_offset_x * 0.87
		bottom_left_style.offset[2] = bottom_left_style.default_offset[2] + spread_offset_y * 0.5
		local bottom_right_style = style.bottom_right
		bottom_right_style.offset[1] = bottom_right_style.default_offset[1] + spread_offset_x * 0.87
		bottom_right_style.offset[2] = bottom_right_style.default_offset[2] + spread_offset_y * 0.5
	end

	-- Update hitmarker color.

	local hit_alpha = (hit_progress or 0) * 255

	if hit_alpha > 0 then
		local top_left_style = style.hit_top_left
		top_left_style.color = apply_color_values(top_left_style.color, hit_color or top_left_style.color, false, hit_alpha)
		top_left_style.visible = true
		local bottom_left_style = style.hit_bottom_left
		bottom_left_style.color = apply_color_values(bottom_left_style.color, hit_color or bottom_left_style.color, false, hit_alpha)
		bottom_left_style.visible = true
		local top_right_style = style.hit_top_right
		top_right_style.color = apply_color_values(top_right_style.color, hit_color or top_right_style.color, false, hit_alpha)
		top_right_style.visible = true
		local bottom_right_style = style.hit_bottom_right
		bottom_right_style.color = apply_color_values(bottom_right_style.color, hit_color or bottom_right_style.color, false, hit_alpha)
		bottom_right_style.visible = true
	else
		style.hit_top_left.visible = false
		style.hit_bottom_left.visible = false
		style.hit_top_right.visible = false
		style.hit_bottom_right.visible = false
	end
end

return template
