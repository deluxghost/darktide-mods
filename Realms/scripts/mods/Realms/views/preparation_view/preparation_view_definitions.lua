local mod = get_mod("Realms")
local LobbyViewDefinitions = require("scripts/ui/views/lobby_view/lobby_view_definitions")
local LobbyViewFontStyle = require("scripts/ui/views/lobby_view/lobby_view_font_style")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local Blueprints = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/preparation_view_blueprints")
local Layout = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/preparation_view_layout")
local Style = mod:io_dofile("Realms/scripts/mods/Realms/views/realms_view_style")

local PLAYER_PANEL_SIZE = Layout.player_panel_size
local INFO_PANEL_SIZE = Layout.info_panel_size
local PLAYER_GRID_SIZE = Layout.player_grid_size
local INFO_GRID_SIZE = Layout.info_grid_size
local PANEL_INSET = Layout.panel_inset
local HEADER_HEIGHT = Layout.header_height
local GRID_TOP = Layout.grid_top
local COLUMNS = Layout.player_columns
local HEADER_TEXT_Y = 8

local scenegraph_definition = {
	screen = {
		scale = "fit",
		size = Layout.screen_size,
		position = {
			0,
			0,
			80,
		},
	},
	mission_title = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			Layout.screen_size[1] - (Layout.outer_margin + PANEL_INSET) * 2,
			100,
		},
		position = {
			Layout.outer_margin + PANEL_INSET,
			50,
			4,
		},
	},
	player_panel = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = PLAYER_PANEL_SIZE,
		position = {
			Layout.outer_margin,
			Layout.panel_top,
			3,
		},
	},
	info_panel = {
		parent = "screen",
		horizontal_alignment = "right",
		vertical_alignment = "top",
		size = INFO_PANEL_SIZE,
		position = {
			-Layout.outer_margin,
			Layout.panel_top,
			3,
		},
	},
	player_header = {
		parent = "player_panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			PLAYER_GRID_SIZE[1],
			HEADER_HEIGHT,
		},
		position = {
			PANEL_INSET,
			0,
			30,
		},
	},
	player_grid = {
		parent = "player_panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = PLAYER_GRID_SIZE,
		position = {
			PANEL_INSET,
			GRID_TOP,
			4,
		},
	},
	info_grid = {
		parent = "info_panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = INFO_GRID_SIZE,
		position = {
			PANEL_INSET,
			Layout.info_grid_top,
			4,
		},
	},
	countdown = {
		parent = "screen",
		horizontal_alignment = "right",
		vertical_alignment = "top",
		size = {
			110,
			90,
		},
		position = {
			-70,
			65,
			70,
		},
	},
	action_button = {
		parent = "info_panel",
		horizontal_alignment = "center",
		vertical_alignment = "bottom",
		size = {
			INFO_GRID_SIZE[1],
			Layout.action_button_height,
		},
		position = {
			0,
			-PANEL_INSET,
			30,
		},
	},
}

local function header_text_style(font_size)
	local style = table.clone(UIFontSettings.body)

	style.font_size = font_size
	style.horizontal_alignment = "left"
	style.text_color = Style.color("header_text")
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "center"
	style.vertical_alignment = "center"
	style.offset = {
		0,
		HEADER_TEXT_Y,
		0,
	}

	return style
end

local title_style = table.clone(LobbyViewFontStyle.title_text_style)
local sub_title_style = table.clone(LobbyViewFontStyle.sub_title_text_style)

title_style.text_color = Style.color("body_text")
sub_title_style.text_color = Style.color("secondary_text")

local timer_background_style = table.clone(UIFontSettings.body)

timer_background_style.text_color = Color.ui_terminal(25.5, true)
timer_background_style.font_size = 94
timer_background_style.font_type = "proxima_nova_medium"
timer_background_style.text_vertical_alignment = "center"
timer_background_style.text_horizontal_alignment = "center"

local timer_text_style = table.clone(UIFontSettings.body)

timer_text_style.text_color = Color.ui_terminal(255, true)
timer_text_style.color = Color.ui_terminal(255, true)
timer_text_style.font_size = 94
timer_text_style.font_type = "proxima_nova_medium"
timer_text_style.text_vertical_alignment = "center"
timer_text_style.text_horizontal_alignment = "right"
timer_text_style.offset = {
	-13,
	0,
	0,
}

local action_button_pass_template = Style.button_pass_template()

local widget_definitions = {
	background = Style.create_background("screen"),
	player_panel = Style.create_panel("player_panel"),
	info_panel = Style.create_panel("info_panel"),
	mission_title = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "title",
			style = title_style,
			value = "",
			value_id = "title",
		},
		{
			pass_type = "text",
			style_id = "sub_title",
			style = sub_title_style,
			value = "",
			value_id = "sub_title",
		},
	}, "mission_title"),
	player_header = UIWidget.create_definition({
		{
			pass_type = "text",
			style = table.merge(header_text_style(20), {
				size = {
					COLUMNS.talents.x,
					HEADER_HEIGHT,
				},
			}),
			value = "",
			value_id = "player",
		},
		{
			pass_type = "text",
			style = table.merge(header_text_style(18), {
				offset = {
					COLUMNS.talents.x + 8,
					HEADER_TEXT_Y,
					0,
				},
				size = {
					COLUMNS.talents.width - 4,
					HEADER_HEIGHT,
				},
			}),
			value = "",
			value_id = "skills",
		},
		{
			pass_type = "text",
			style = table.merge(header_text_style(18), {
				offset = {
					COLUMNS.weapons.x,
					HEADER_TEXT_Y,
					0,
				},
				size = {
					COLUMNS.weapons.width,
					HEADER_HEIGHT,
				},
			}),
			value = "",
			value_id = "loadout",
		},
		{
			pass_type = "text",
			style = table.merge(header_text_style(18), {
				offset = {
					COLUMNS.status.x,
					HEADER_TEXT_Y,
					0,
				},
				size = {
					COLUMNS.status.width,
					HEADER_HEIGHT,
				},
				text_horizontal_alignment = "center",
			}),
			value = "",
			value_id = "status",
		},
	}, "player_header"),
	countdown = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text_background",
			value = UISettings.digital_clock_numbers[8] .. UISettings.digital_clock_numbers[8],
			style = timer_background_style,
			visibility_function = function (content) return content.visible end,
		},
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = timer_text_style,
			visibility_function = function (content) return content.visible end,
		},
	}, "countdown", {
		visible = false,
	}),
	action_button = UIWidget.create_definition(action_button_pass_template, "action_button", {
		original_text = "",
	}),
}

local item_stats_grid_settings = table.clone(LobbyViewDefinitions.item_stats_grid_settings)

item_stats_grid_settings.resource_renderer_background = true

return {
	blueprints = Blueprints.blueprints,
	info_grid_size = INFO_GRID_SIZE,
	item_stats_grid_settings = item_stats_grid_settings,
	max_skills = Blueprints.max_skills,
	player_grid_size = PLAYER_GRID_SIZE,
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
}
