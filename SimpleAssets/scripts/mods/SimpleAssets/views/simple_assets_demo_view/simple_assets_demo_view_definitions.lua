local mod = get_mod("SimpleAssets")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local VIEW_ROOT_LAYER = 13
local CARD_WIDTH = 200
local CARD_HEIGHT = 210
local CARD_HORIZONTAL_GAP = 20
local CARD_VERTICAL_GAP = 20
local GALLERY_COLUMNS = 7
local LOADING_TEXT = "Loading..."
local VIDEO_PASS_VALUE = "content/videos/fatshark_splash"

local names = {
	mouse_cursor = "left_ptr",
	slug_album = "run",
	video = "flower",
}
local resource_names = {
	mouse_cursor = mod.get_resource_name("mouse_cursor", names.mouse_cursor),
	slug_album = mod.get_resource_name("slug_album", names.slug_album),
	video = mod.get_resource_name("video", names.video),
}

local screen = table.clone(UIWorkspaceSettings.screen)

screen.position[3] = VIEW_ROOT_LAYER

local function gallery_item(index)
	local zero_based_index = index - 1
	local column = zero_based_index % GALLERY_COLUMNS
	local row = math.floor(zero_based_index / GALLERY_COLUMNS)

	return {
		parent = "gallery",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			CARD_WIDTH,
			CARD_HEIGHT,
		},
		position = {
			column * (CARD_WIDTH + CARD_HORIZONTAL_GAP),
			row * (CARD_HEIGHT + CARD_VERTICAL_GAP),
			1,
		},
	}
end

local scenegraph_definition = {
	screen = screen,
	title = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			600,
			60,
		},
		position = {
			180,
			90,
			2,
		},
	},
	gallery = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			1560,
			820,
		},
		position = {
			180,
			170,
			1,
		},
	},
	gallery_item_1 = gallery_item(1),
	gallery_item_2 = gallery_item(2),
	gallery_item_3 = gallery_item(3),
	gallery_item_4 = gallery_item(4),
	gallery_item_5 = gallery_item(5),
}

local card_passes = {
	{
		pass_type = "rect",
		style = {
			color = {
				220,
				18,
				18,
				18,
			},
			offset = {
				0,
				0,
				0,
			},
		},
	},
	{
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = {
			color = Color.terminal_frame(nil, true),
			offset = {
				0,
				0,
				4,
			},
		},
	},
}

local function append_passes(destination, passes)
	for i = 1, #passes do
		destination[#destination + 1] = table.clone(passes[i])
	end

	return destination
end

local function label_pass(label)
	local style = table.clone(UIFontSettings.header_3)

	style.font_size = 18
	style.offset = {
		10,
		5,
		3,
	}
	style.size = {
		CARD_WIDTH - 20,
		24,
	}
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "center"

	return {
		pass_type = "text",
		value = label,
		style = style,
	}
end

local function status_pass(initial_text, ready_id)
	return {
		pass_type = "text",
		value_id = "status",
		value = initial_text,
		style = {
			font_type = "proxima_nova_bold",
			font_size = 14,
			text_color = Color.text_default(255, true),
			text_horizontal_alignment = "center",
			text_vertical_alignment = "center",
			offset = {
				10,
				38,
				3,
			},
			size = {
				CARD_WIDTH - 20,
				CARD_HEIGHT - 48,
			},
		},
		visibility_function = function(content)
			return not content[ready_id]
		end,
	}
end

local texture_passes = append_passes({}, card_passes)

texture_passes[#texture_passes + 1] = label_pass("texture")
texture_passes[#texture_passes + 1] = {
	pass_type = "texture",
	style_id = "image",
	style = {
		horizontal_alignment = "center",
		vertical_alignment = "top",
		material_values = {
			texture_map = nil,
			use_placeholder_texture = 0,
		},
		offset = {
			0,
			38,
			2,
		},
		size = {
			165,
			158,
		},
	},
	visibility_function = function(content)
		return content.texture_ready
	end,
}
texture_passes[#texture_passes + 1] = status_pass(LOADING_TEXT, "texture_ready")

local font_passes = append_passes({}, card_passes)

font_passes[#font_passes + 1] = label_pass("font")
font_passes[#font_passes + 1] = {
	pass_type = "text",
	value_id = "sample_text",
	value = "The quick brown fox\njumps over the lazy dog.",
	style_id = "sample_text",
	style = {
		font_type = "proxima_nova_bold",
		font_size = 20,
		text_color = Color.text_default(255, true),
		text_horizontal_alignment = "center",
		text_vertical_alignment = "center",
		offset = {
			10,
			38,
			2,
		},
		size = {
			CARD_WIDTH - 20,
			CARD_HEIGHT - 48,
		},
	},
	visibility_function = function(content)
		return content.font_ready
	end,
}
font_passes[#font_passes + 1] = status_pass(LOADING_TEXT, "font_ready")

local mouse_cursor_passes = append_passes({}, card_passes)

mouse_cursor_passes[#mouse_cursor_passes + 1] = {
	pass_type = "hotspot",
	content_id = "hotspot",
}
mouse_cursor_passes[#mouse_cursor_passes + 1] = label_pass("mouse_cursor")
mouse_cursor_passes[#mouse_cursor_passes + 1] = {
	pass_type = "text",
	value = "Hover here to preview",
	style = {
		font_type = "proxima_nova_bold",
		font_size = 16,
		text_color = Color.text_default(255, true),
		text_horizontal_alignment = "center",
		text_vertical_alignment = "center",
		offset = {
			10,
			38,
			2,
		},
		size = {
			CARD_WIDTH - 20,
			CARD_HEIGHT - 48,
		},
	},
	visibility_function = function(content)
		return content.mouse_cursor_ready
	end,
}
mouse_cursor_passes[#mouse_cursor_passes + 1] = status_pass(LOADING_TEXT, "mouse_cursor_ready")

local video_passes = append_passes({}, card_passes)

video_passes[#video_passes + 1] = label_pass("video")
video_passes[#video_passes + 1] = {
	pass_type = "video",
	value = VIDEO_PASS_VALUE,
	style = {
		color = Color.white(255, true),
		horizontal_alignment = "center",
		vertical_alignment = "top",
		offset = {
			0,
			38,
			2,
		},
		size = {
			160,
			160,
		},
	},
	visibility_function = function(content)
		return content.video_ready and content.video_player_reference ~= nil
	end,
}
video_passes[#video_passes + 1] = status_pass(LOADING_TEXT, "video_ready")

local slug_album_passes = append_passes({}, card_passes)

slug_album_passes[#slug_album_passes + 1] = label_pass("slug_album")
slug_album_passes[#slug_album_passes + 1] = {
	pass_type = "slug_icon",
	value = resource_names.slug_album,
	style = {
		color = Color.white(255, true),
		draw_index = 1,
		horizontal_alignment = "center",
		vertical_alignment = "top",
		offset = {
			0,
			38,
			2,
		},
		size = {
			160,
			160,
		},
	},
	visibility_function = function(content)
		return content.slug_album_ready
	end,
}
slug_album_passes[#slug_album_passes + 1] = status_pass(LOADING_TEXT, "slug_album_ready")

local widget_definitions = {
	background = UIWidget.create_definition({
		{
			pass_type = "rect",
			style = {
				color = Color.black(255, true),
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/backgrounds/terminal_basic",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				scale_to_material = true,
				size_addition = {
					40,
					40,
				},
				color = Color.terminal_grid_background_gradient(204, true),
			},
		},
	}, "screen"),
	title = UIWidget.create_definition({
		{
			pass_type = "text",
			value = "Simple Assets UI Demo",
			style = table.clone(UIFontSettings.header_1),
		},
	}, "title"),
	texture_demo = UIWidget.create_definition(texture_passes, "gallery_item_1", {
		texture_ready = false,
	}),
	font_demo = UIWidget.create_definition(font_passes, "gallery_item_2", {
		font_ready = false,
	}),
	mouse_cursor_demo = UIWidget.create_definition(mouse_cursor_passes, "gallery_item_3", {
		mouse_cursor_ready = false,
	}),
	video_demo = UIWidget.create_definition(video_passes, "gallery_item_4", {
		video_ready = false,
	}),
	slug_album_demo = UIWidget.create_definition(slug_album_passes, "gallery_item_5", {
		slug_album_ready = false,
	}),
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
	legend_inputs = legend_inputs,
	names = names,
	resource_names = resource_names,
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
}
