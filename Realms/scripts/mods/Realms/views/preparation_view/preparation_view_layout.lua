local mod = get_mod("Realms")

local SCREEN_WIDTH = 1920
local SCREEN_HEIGHT = 1080
local OUTER_MARGIN = 80
local PANEL_GAP = 40
local PANEL_TOP = 180
local PANEL_HEIGHT = 780
local PANEL_INSET = 20
local INFO_PANEL_WIDTH = 400
local PLAYER_PANEL_WIDTH = SCREEN_WIDTH - OUTER_MARGIN * 2 - PANEL_GAP - INFO_PANEL_WIDTH
local HEADER_HEIGHT = 40
local GRID_TOP = 40
local SCROLLBAR_GUTTER = 16
local ROW_SPACING = 8
local ACTION_BUTTON_HEIGHT = 64
local ACTION_GAP = 12
local INFO_FOOTER_HEIGHT = PANEL_INSET + ACTION_BUTTON_HEIGHT + ACTION_GAP
local PLAYER_GRID_WIDTH = PLAYER_PANEL_WIDTH - PANEL_INSET * 2
local INFO_GRID_WIDTH = INFO_PANEL_WIDTH - PANEL_INSET * 2
local PLAYER_ROW_WIDTH = PLAYER_GRID_WIDTH - SCROLLBAR_GUTTER
local INFO_ROW_WIDTH = INFO_GRID_WIDTH - SCROLLBAR_GUTTER

return {
	screen_size = {
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
	},
	outer_margin = OUTER_MARGIN,
	panel_gap = PANEL_GAP,
	panel_top = PANEL_TOP,
	panel_inset = PANEL_INSET,
	header_height = HEADER_HEIGHT,
	grid_top = GRID_TOP,
	row_spacing = ROW_SPACING,
	scrollbar_gutter = SCROLLBAR_GUTTER,
	player_panel_size = {
		PLAYER_PANEL_WIDTH,
		PANEL_HEIGHT,
	},
	info_panel_size = {
		INFO_PANEL_WIDTH,
		PANEL_HEIGHT,
	},
	player_grid_size = {
		PLAYER_GRID_WIDTH,
		PANEL_HEIGHT - GRID_TOP - PANEL_INSET,
	},
	info_grid_size = {
		INFO_GRID_WIDTH,
		PANEL_HEIGHT - PANEL_INSET - INFO_FOOTER_HEIGHT,
	},
	player_row_width = PLAYER_ROW_WIDTH,
	info_row_width = INFO_ROW_WIDTH,
	player_columns = {
		portrait = {
			x = 8,
			width = 64,
		},
		player = {
			x = 82,
			width = 554,
		},
		talents = {
			x = 652,
			width = 224,
		},
		weapons = {
			x = 892,
			width = 296,
		},
		status = {
			x = 1196,
			width = PLAYER_ROW_WIDTH - 1196,
		},
	},
	action_button_height = ACTION_BUTTON_HEIGHT,
	action_gap = ACTION_GAP,
	info_footer_height = INFO_FOOTER_HEIGHT,
}
