local mod = get_mod("PrivateCharMap")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ColorUtilities = require("scripts/utilities/ui/colors")

local grid_width = 1270
local edge_padding = 60
local window_size = {
	grid_width + edge_padding,
	810,
}
local grid_size = {
	grid_width,
	window_size[2]
}
local grid_spacing = {
	10,
	10
}
local elements_size = {
	70,
	70,
}

local grid_settings = {
	scrollbar_width = 7,
	use_terminal_background = true,
	title_height = 0,
	grid_spacing = grid_spacing,
	grid_size = grid_size,
	mask_size = window_size,
	edge_padding = edge_padding
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
	char_box = {
		size = elements_size,
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
					}
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
					}
				}
			},
			{
				style_id = "char_pos",
				pass_type = "text",
				value = "",
				value_id = "char_pos",
				style = {
					vertical_alignment = "top",
					horizontal_alignment = "center",
					text_vertical_alignment = "top",
					text_horizontal_alignment = "center",
					offset = { 0, 0, 10 },
					size = { elements_size[1], 40 },
					text_color = Color.terminal_text_header(255, true),
					font_type = "proxima_nova_bold",
					font_size = 16,
				},
			},
			{
				style_id = "char_text",
				pass_type = "text",
				value = "",
				value_id = "char_text",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					offset = { 0, 6, 10 },
					size = { elements_size[1], elements_size[1] },
					text_color = Color.terminal_text_header(255, true),
					font_type = "proxima_nova_bold",
					font_size = 32,
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
					}
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
						13,
					}
				},
				change_function = item_change_function,
			},
		},
		init = function (parent, widget, element, callback_name)
			local content = widget.content
			local style = widget.style

			content.hotspot.pressed_callback = callback_name and callback(parent, callback_name, widget, element)
			content.char_index = element.char_index
			content.char_pos = element.char_pos
			content.char_text = element.char_text
		end
	},
	spacing_vertical = {
		size = {
			grid_width,
			20,
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
	char_table_pivot = {
		parent = "canvas",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {
			0,
			0,
		},
		position = {
			180,
			30,
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
			value = mod:localize("char_map_title"),
			style = table.clone(UIFontSettings.header_1),
		}
	}, "title_text"),
	desc_text = UIWidget.create_definition({
		{
			value_id = "desc_text",
			style_id = "desc_text",
			pass_type = "text",
			value = mod:localize("char_map_desc"),
			style = {
				line_spacing = 1.2,
				font_size = 22,
				font_type = "proxima_nova_bold",
				text_color = Color.text_default(255, true),
				default_color = Color.text_default(255, true),
				offset = {
					180,
					0,
					0
				},
			}
		}
	}, "canvas"),
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
	grid_settings = grid_settings,
}
