local mod = get_mod("ColorViewer")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ColorUtilities = require("scripts/utilities/ui/colors")

local grid_spacing = {
	10,
	10
}

local color_table_grid_width = 1190
local color_table_edge_padding = 60
local color_table_window_size = {
	color_table_grid_width + color_table_edge_padding,
	800,
}
local color_table_grid_size = {
	color_table_grid_width,
	color_table_window_size[2],
}
local color_table_elements_size = {
	290,
	80,
}
local color_table_grid_settings = {
	scrollbar_width = 7,
	use_terminal_background = true,
	title_height = 0,
	grid_spacing = grid_spacing,
	grid_size = color_table_grid_size,
	mask_size = color_table_window_size,
	edge_padding = color_table_edge_padding,
}

local control_grid_width = 280
local control_edge_padding = 20
local control_window_size = {
	control_grid_width + control_edge_padding,
	800,
}
local control_grid_size = {
	control_grid_width,
	control_window_size[2],
}
local control_grid_settings = {
	scrollbar_width = 7,
	use_terminal_background = true,
	title_height = 0,
	grid_spacing = grid_spacing,
	grid_size = control_grid_size,
	mask_size = control_window_size,
	edge_padding = control_edge_padding,
}

local function item_change_function(content, style)
	local hotspot = content.hotspot
	local is_selected = hotspot.is_selected
	local is_focused = hotspot.is_focused
	local is_hover = hotspot.is_hover
	local default_color = style.default_color
	local selected_color = style.selected_color
	local hover_color = style.hover_color
	local color

	if is_selected or is_focused then
		color = selected_color
	elseif is_hover then
		color = hover_color
	else
		color = default_color
	end

	local progress = math.max(math.max(hotspot.anim_hover_progress or 0, hotspot.anim_select_progress or 0), hotspot.anim_focus_progress or 0)

	ColorUtilities.color_lerp(default_color, color, progress, style.color)
end

local blueprints = {
	color_box = {
		size = color_table_elements_size,
		pass_template = {
			{
				pass_type = "hotspot",
				content_id = "hotspot",
				style = {
					on_hover_sound = UISoundEvents.default_mouse_hover,
					on_pressed_sound = UISoundEvents.default_click,
				}
			},
			{
				pass_type = "texture",
				style_id = "background",
				value = "content/ui/materials/backgrounds/default_square",
				style = {
					default_color = Color.terminal_background(nil, true),
					selected_color = Color.terminal_background_selected(nil, true)
				},
				change_function = ButtonPassTemplates.terminal_button_change_function,
			},
			{
				pass_type = "texture",
				style_id = "background_gradient",
				value = "content/ui/materials/gradients/gradient_vertical",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					default_color = Color.terminal_background_gradient(nil, true),
					selected_color = Color.terminal_frame_selected(nil, true),
					offset = {
						0,
						0,
						2,
					},
				},
				change_function = function (content, style)
					ButtonPassTemplates.terminal_button_change_function(content, style)
					ButtonPassTemplates.terminal_button_hover_change_function(content, style)
				end,
			},
			{
				value = "content/ui/materials/frames/dropshadow_medium",
				style_id = "outer_shadow",
				pass_type = "texture",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					scale_to_material = true,
					color = Color.black(100, true),
					size_addition = {
						20,
						20,
					},
					offset = {
						0,
						0,
						3,
					},
				}
			},
			{
				pass_type = "rect",
				style_id = "color_icon",
				style = {
					color = Color.black(255, true),
					size = {
						70,
						70,
					},
					offset = {
						5,
						5,
						7,
					},
				},
			},
			{
				pass_type = "text",
				value = "",
				style = {
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					text_color = { 255, 204, 204, 204 },
					drop_shadow = false,
					font_type = "proxima_nova_bold",
					font_size = 50,
					size = {
						70,
						70,
					},
					offset = {
						5,
						4,
						6,
					},
				},
			},
			{
				pass_type = "rect",
				style = {
					color = Color.white(255, true),
					size = {
						70,
						70,
					},
					offset = {
						5,
						5,
						5,
					},
				},
			},
			{
				style_id = "color_name",
				pass_type = "text",
				value = "",
				value_id = "color_name",
				style = {
					vertical_alignment = "top",
					horizontal_alignment = "left",
					text_vertical_alignment = "top",
					text_horizontal_alignment = "left",
					offset = { 80, 5, 10 },
					size = { color_table_elements_size[1] - 85, color_table_elements_size[2] },
					text_color = Color.terminal_text_header(255, true),
					font_type = "proxima_nova_bold",
					font_size = 21,
				},
			},
			{
				pass_type = "texture",
				style_id = "frame",
				value = "content/ui/materials/frames/frame_tile_2px",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					color = Color.terminal_frame(nil, true),
					default_color = Color.terminal_frame(nil, true),
					selected_color = Color.terminal_frame_selected(nil, true),
					hover_color = Color.terminal_frame_hover(nil, true),
					offset = {
						0,
						0,
						2,
					},
				},
				change_function = item_change_function,
			},
			{
				pass_type = "texture",
				style_id = "corner",
				value = "content/ui/materials/frames/frame_corner_2px",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					color = Color.terminal_corner(nil, true),
					default_color = Color.terminal_corner(nil, true),
					selected_color = Color.terminal_corner_selected(nil, true),
					hover_color = Color.terminal_corner_hover(nil, true),
					offset = {
						0,
						0,
						3,
					},
				},
				change_function = item_change_function,
			},
		},
		init = function (parent, widget, element, callback_name)
			local content = widget.content
			local style = widget.style

			content.hotspot.pressed_callback = callback_name and callback(parent, callback_name, widget, element)
			content.color_codename = element.color_name
			content.color_name = string.gsub(element.color_name, "_", " ")
			style.color_icon.color = element.color_data
		end,
		update = function (parent, widget, input_service, dt, t, ui_renderer)
			local content = widget.content
			local style = widget.style

			content.hotspot.is_selected = content.color_codename == parent._selected_color
		end,
	},
	color_header = {
		size = { 280, 80 },
		pass_template = {
			{
				pass_type = "rect",
				style_id = "color_icon",
				style = {
					color = Color.black(255, true),
					size = {
						70,
						70,
					},
					offset = {
						5,
						5,
						7,
					},
				},
			},
			{
				pass_type = "text",
				value = "",
				style = {
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					text_color = { 255, 204, 204, 204 },
					drop_shadow = false,
					font_type = "proxima_nova_bold",
					font_size = 50,
					size = {
						70,
						70,
					},
					offset = {
						5,
						4,
						6,
					},
				},
			},
			{
				pass_type = "rect",
				style = {
					color = Color.white(255, true),
					size = {
						70,
						70,
					},
					offset = {
						5,
						5,
						5,
					},
				},
			},
			{
				style_id = "color_name",
				pass_type = "text",
				value = "",
				value_id = "color_name",
				style = {
					vertical_alignment = "top",
					horizontal_alignment = "left",
					text_vertical_alignment = "top",
					text_horizontal_alignment = "left",
					offset = { 80, 0, 10 },
					size = { 280 - 85, 80 },
					text_color = Color.terminal_text_header(255, true),
					font_type = "proxima_nova_bold",
					font_size = 21,
				},
			},
		},
		init = function (parent, widget, element, callback_name)
			local content = widget.content
			local style = widget.style

			content.color_name = string.gsub(element.color_name, "_", " ")
			style.color_icon.color = element.color_data
		end,
	},
	copy_text_box = {
		size = { 280, 100 },
		pass_template = {
			{
				pass_type = "rect",
				style = {
					color = { 84, 90, 135, 85 },
					size = {
						270,
						50,
					},
					offset = {
						5,
						5,
						5,
					},
				},
			},
			{
				pass_type = "text",
				value = "",
				value_id = "text_to_copy",
				style = {
					text_vertical_alignment = "top",
					text_horizontal_alignment = "left",
					text_color = { 255, 204, 204, 204 },
					drop_shadow = false,
					font_type = "proxima_nova_bold",
					font_size = 20,
					size = {
						260,
						45,
					},
					offset = {
						10,
						5,
						6,
					},
				},
			},
			{
				pass_type = "hotspot",
				content_id = "hotspot",
				style = {
					size = {
						270,
						40,
					},
					offset = {
						5,
						60,
						6,
					},
					on_hover_sound = UISoundEvents.default_mouse_hover,
					on_pressed_sound = UISoundEvents.default_click,
				}
			},
			{
				pass_type = "texture",
				style_id = "background",
				value = "content/ui/materials/backgrounds/default_square",
				style = {
					size = {
						270,
						40,
					},
					offset = {
						5,
						60,
						1,
					},
					default_color = Color.terminal_background(nil, true),
					selected_color = Color.terminal_background_selected(nil, true)
				},
				change_function = ButtonPassTemplates.terminal_button_change_function,
			},
			{
				pass_type = "texture",
				style_id = "background_gradient",
				value = "content/ui/materials/gradients/gradient_vertical",
				style = {
					default_color = Color.terminal_background_gradient(nil, true),
					selected_color = Color.terminal_frame_selected(nil, true),
					size = {
						270,
						40,
					},
					offset = {
						5,
						60,
						2,
					},
				},
				change_function = function (content, style)
					ButtonPassTemplates.terminal_button_change_function(content, style)
					ButtonPassTemplates.terminal_button_hover_change_function(content, style)
				end,
			},
			{
				value = "content/ui/materials/frames/dropshadow_medium",
				style_id = "outer_shadow",
				pass_type = "texture",
				style = {
					scale_to_material = true,
					color = Color.black(100, true),
					size = {
						270,
						40,
					},
					offset = {
						-5,
						50,
						3,
					},
					size_addition = {
						20,
						20,
					},
				}
			},
			{
				pass_type = "text",
				value = "",
				value_id = "copy_button_display_name",
				style = {
					text_vertical_alignment = "top",
					text_horizontal_alignment = "center",
					size = {
						270,
						40,
					},
					offset = {
						5,
						62,
						3,
					},
					text_color = Color.terminal_text_header(255, true),
					font_type = "proxima_nova_bold",
					font_size = 25,
				},
			},
			{
				pass_type = "texture",
				style_id = "frame",
				value = "content/ui/materials/frames/frame_tile_2px",
				style = {
					color = Color.terminal_frame(nil, true),
					default_color = Color.terminal_frame(nil, true),
					selected_color = Color.terminal_frame_selected(nil, true),
					hover_color = Color.terminal_frame_hover(nil, true),
					size = {
						270,
						40,
					},
					offset = {
						5,
						60,
						2,
					},
				},
			},
			{
				pass_type = "texture",
				style_id = "corner",
				value = "content/ui/materials/frames/frame_corner_2px",
				style = {
					color = Color.terminal_corner(nil, true),
					default_color = Color.terminal_corner(nil, true),
					selected_color = Color.terminal_corner_selected(nil, true),
					hover_color = Color.terminal_corner_hover(nil, true),
					size = {
						270,
						40,
					},
					offset = {
						5,
						60,
						3,
					},
				},
			},
		},
		init = function (parent, widget, element, callback_name)
			local content = widget.content
			local style = widget.style

			content.hotspot.pressed_callback = callback_name and callback(parent, callback_name, widget, element)
			content.copy_type = element.copy_type
			content.copy_button_display_name = mod:localize("btn_copy", element.copy_type)
			content.text_to_copy = element.text_to_copy
		end,
	},
	color_table_spacing_vertical = {
		size = {
			color_table_grid_width,
			20,
		}
	},
	control_spacing_vertical = {
		size = {
			control_grid_width,
			10,
		}
	}
}

local scenegraph_definition = {
	screen = {
		scale = "fit",
		size = {
			1920,
			1080,
		},
		position = {
			0,
			0,
			100,
		},
	},
	title_divider = {
		parent = "screen",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {
			335,
			18,
		},
		position = {
			180,
			145,
			101,
		}
	},
	title_text = {
		parent = "title_divider",
		vertical_alignment = "bottom",
		horizontal_alignment = "left",
		size = {
			500,
			50,
		},
		position = {
			0,
			-35,
			101,
		}
	},
	canvas = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = {
			1920,
			915,
		},
		position = {
			0,
			165,
			102,
		},
	},
	color_table_pivot = {
		parent = "canvas",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {
			0,
			0,
		},
		position = {
			180,
			10,
			103,
		}
	},
	control_pivot = {
		parent = "canvas",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {
			0,
			0,
		},
		position = {
			1435,
			10,
			103,
		}
	},
}

local widget_definitions = {
	background = UIWidget.create_definition({
		{
			value = "content/ui/materials/backgrounds/terminal_basic",
			pass_type = "texture",
			style = {
				horizontal_alignemt = "center",
				scale_to_material = true,
				vertical_alignemnt = "center",
				size_addition = {
					40,
					40
				},
				offset = {
					-20,
					-20,
					1
				},
				color = Color.terminal_grid_background_gradient(255, true),
			}
		},
		{
			pass_type = "rect",
			style = {
				color = Color.black(255, true)
			},
			offset = {
				0,
				0,
				0
			}
		},
	}, "screen"),
	title_divider = UIWidget.create_definition({
		{
			pass_type = "texture",
			value = "content/ui/materials/dividers/skull_rendered_left_01",
		}
	}, "title_divider"),
	title_text = UIWidget.create_definition({
		{
			value_id = "title_text",
			style_id = "title_text",
			pass_type = "text",
			value = mod:localize("color_viewer_title"),
			style = table.clone(UIFontSettings.header_1),
		}
	}, "title_text"),
}

local legend_inputs = {
	{
		input_action = "back",
		on_pressed_callback = "_on_back_pressed",
		display_name = "loc_class_selection_button_back",
		alignment = "left_alignment",
	},
}

return {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
	blueprints = blueprints,
	legend_inputs = legend_inputs,
	color_table_grid_settings = color_table_grid_settings,
	control_grid_settings = control_grid_settings,
}
