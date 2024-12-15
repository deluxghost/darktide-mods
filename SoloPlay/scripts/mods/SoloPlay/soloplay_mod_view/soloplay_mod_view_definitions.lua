local mod = get_mod("SoloPlay")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local MissionBoardViewStyles = require("scripts/ui/views/mission_board_view/mission_board_view_styles")
local view_settings = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/soloplay_mod_view/soloplay_mod_view_settings")
local stepper_templates = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/soloplay_mod_view/stepper_templates")

local function visibility_function_solo_unavailable(content, style)
	return not mod.can_start_game()
end

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
			80,
		},
	},
	title_text = {
		parent = "screen",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {
			500,
			50,
		},
		position = {
			80,
			50,
			2,
		}
	},
	offline_tip_text = {
		parent = "screen",
		vertical_alignment = "top",
		horizontal_alignment = "right",
		size = {
			900,
			50,
		},
		position = {
			-80,
			50,
			2,
		}
	},
	canvas = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = {
			1920,
			970,
		},
		position = {
			0,
			110,
			2,
		},
	},
	warn_info_box = {
		parent = "canvas",
		vertical_alignment = "top",
		horizontal_alignment = "center",
		size = {
			400,
			50,
		},
		position = {
			0,
			842,
			2,
		}
	},
	normal_section = {
		parent = "canvas",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {
			550,
			970,
		},
		position = {
			100,
			10,
			0,
		}
	},
	normal_difficulty = {
		parent = "normal_section",
		vertical_alignment = "top",
		horizontal_alignment = "center",
		size = {
			483,
			178,
		},
		position = {
			0,
			590,
			0,
		}
	},
	normal_start = {
		parent = "normal_section",
		vertical_alignment = "top",
		horizontal_alignment = "center",
		size = ButtonPassTemplates.default_button.size,
		position = {
			0,
			760,
			0,
		}
	},
	havoc_section = {
		parent = "canvas",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {
			1130,
			970,
		},
		position = {
			690,
			10,
			0,
		}
	},
	havoc_modifier_lock = {
		parent = "havoc_section",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {
			210,
			40,
		},
		position = {
			340,
			410,
			0,
		}
	},
	havoc_modifiers_grid = {
		parent = "havoc_section",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = view_settings.grid_settings.grid_size,
		position = {
			0,
			450,
			0,
		}
	},
	havoc_difficulty_badge = {
		parent = "havoc_section",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = view_settings.havoc_badge_size,
		position = {
			580,
			482,
			0,
		}
	},
	havoc_difficulty = {
		parent = "havoc_section",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = view_settings.difficulty_slider_size,
		position = {
			780,
			575,
			0,
		}
	},
	havoc_randomize = {
		parent = "havoc_section",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = ButtonPassTemplates.default_button.size,
		position = {
			681.5,
			720,
			0,
		}
	},
	havoc_start = {
		parent = "havoc_section",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = ButtonPassTemplates.default_button.size,
		position = {
			681.5,
			790,
			0,
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
	title_text = UIWidget.create_definition({
		{
			value_id = "title_text",
			style_id = "title_text",
			pass_type = "text",
			value = mod:localize("solo_view_title"),
			style = table.clone(UIFontSettings.header_1),
		}
	}, "title_text"),
	offline_tip_text = UIWidget.create_definition({
		{
			value_id = "offline_tip_text",
			style_id = "offline_tip_text",
			pass_type = "text",
			value = mod:localize("tip_solo_offline"),
			style = table.merge_recursive(table.clone(UIFontSettings.header_5), {
				text_horizontal_alignment = "right",
				text_vertical_alignment = "top",
				offset = {
					0,
					0,
					0,
				}
			}),
		}
	}, "offline_tip_text"),
	warn_info_box = UIWidget.create_definition({
		{
			style_id = "background",
			pass_type = "rect",
			style = {
				color = {
					150,
					58,
					15,
					15,
				}
			},
			visibility_function = visibility_function_solo_unavailable,
		},
		{
			style_id = "frame",
			pass_type = "texture",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				scale_to_material = true,
				color = Color.ui_interaction_critical(255, true),
				offset = {
					0,
					0,
					1,
				},
			},
			visibility_function = visibility_function_solo_unavailable,
		},
		{
			value_id = "text",
			style_id = "text",
			pass_type = "text",
			value = mod:localize("msg_not_available"),
			style = {
				font_type = "proxima_nova_bold",
				font_size = 18,
				text_vertical_alignment = "center",
				text_horizontal_alignment = "center",
				text_color = Color.ui_interaction_critical(255, true),
				offset = {
					0,
					0,
					2,
				},
				size_addition = {
					-10,
					0,
				},
			},
			visibility_function = visibility_function_solo_unavailable,
		}
	}, "warn_info_box"),
	normal_title = UIWidget.create_definition({
		{
			value_id = "normal_title",
			style_id = "normal_title",
			pass_type = "text",
			value = mod:localize("title_normal_mode"),
			style = table.merge_recursive(table.clone(UIFontSettings.header_2), {
				text_color = view_settings.sub_title_color,
			}),
		}
	}, "normal_section"),
	havoc_title = UIWidget.create_definition({
		{
			value_id = "havoc_title",
			style_id = "havoc_title",
			pass_type = "text",
			value = mod:localize("title_havoc_mode"),
			style = table.merge_recursive(table.clone(UIFontSettings.header_2), {
				text_color = view_settings.sub_title_color,
			}),
		}
	}, "havoc_section"),
	havoc_modifier_label = UIWidget.create_definition({
		{
			value_id = "havoc_modifier_label",
			style_id = "havoc_modifier_label",
			pass_type = "text",
			value = mod:localize("label_mutator"),
			style = table.merge_recursive(table.clone(UIFontSettings.header_3), {
				offset = {
					0,
					410,
					0,
				}
			}),
		}
	}, "havoc_section"),
	normal_difficulty = UIWidget.create_definition(stepper_templates.difficulty_stepper, "normal_difficulty", nil, nil, MissionBoardViewStyles.difficulty_stepper_style),
	normal_start = UIWidget.create_definition(ButtonPassTemplates.default_button, "normal_start", {
		original_text = mod:localize("button_start_normal"),
	}),
	havoc_modifier_lock = UIWidget.create_definition(ButtonPassTemplates.terminal_button, "havoc_modifier_lock"),
	havoc_randomize = UIWidget.create_definition(ButtonPassTemplates.default_button, "havoc_randomize", {
		original_text = mod:localize("button_randomize"),
	}),
	havoc_start = UIWidget.create_definition(ButtonPassTemplates.default_button, "havoc_start", {
		original_text = mod:localize("button_start_havoc"),
	}),
	normal_tip_text = UIWidget.create_definition({
		{
			value_id = "normal_tip_text",
			style_id = "normal_tip_text",
			pass_type = "text",
			value = mod:localize("tip_invalid_combination"),
			style = table.merge_recursive(table.clone(UIFontSettings.header_5), {
				text_horizontal_alignment = "center",
				text_vertical_alignment = "top",
				offset = {
					0,
					550,
					0,
				}
			}),
		}
	}, "normal_section"),
}

local function add_dropdown(id, section, x, y)
	scenegraph_definition[id] = {
		parent = section,
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = view_settings.dropdown_size,
		position = {
			x,
			y + 50,
			0,
		},
	}
	local label_id = id .. "_label"
	local label_loc_key = view_settings.dropdown_label_loc_keys[id]
	widget_definitions[label_id] = UIWidget.create_definition({
		{
			value_id = label_id,
			style_id = label_id,
			pass_type = "text",
			value = mod:localize(label_loc_key),
			style = table.merge_recursive(table.clone(UIFontSettings.header_3), {
				offset = {
					x,
					y,
					0,
				}
			}),
		}
	}, section)
end

add_dropdown("normal_mission", "normal_section", 0, 50)
add_dropdown("normal_side_mission", "normal_section", 0, 170)
add_dropdown("normal_circumstance", "normal_section", 0, 290)
add_dropdown("normal_mission_giver", "normal_section", 0, 410)

add_dropdown("havoc_mission", "havoc_section", 0, 50)
add_dropdown("havoc_faction", "havoc_section", 0, 170)
add_dropdown("havoc_mission_giver", "havoc_section", 0, 290)

add_dropdown("havoc_circumstance1", "havoc_section", 580, 50)
add_dropdown("havoc_circumstance2", "havoc_section", 580, 170)
add_dropdown("havoc_theme_circumstance", "havoc_section", 580, 290)
add_dropdown("havoc_difficulty_circumstance", "havoc_section", 580, 410)

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
	legend_inputs = legend_inputs,
}
