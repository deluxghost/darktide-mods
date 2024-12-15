local grid_size = { 544, 350 }
local edge_padding = 6
local window_size = {
	grid_size[1] + edge_padding,
	grid_size[2],
}
local grid_spacing = {
	5,
	5,
}
local grid_settings = {
	scrollbar_width = 7,
	use_terminal_background = true,
	title_height = 0,
	grid_spacing = grid_spacing,
	grid_size = grid_size,
	mask_size = window_size,
	edge_padding = edge_padding,
	hide_dividers = true,
}

local havoc_rank_badges = {
	{
		texture = "content/ui/textures/frames/havoc_ranks/havoc_rank_1",
		level = 1,
	},
	{
		texture = "content/ui/textures/frames/havoc_ranks/havoc_rank_2",
		level = 5,
	},
	{
		texture = "content/ui/textures/frames/havoc_ranks/havoc_rank_3",
		level = 10,
	},
	{
		texture = "content/ui/textures/frames/havoc_ranks/havoc_rank_4",
		level = 15,
	},
	{
		texture = "content/ui/textures/frames/havoc_ranks/havoc_rank_5",
		level = 20,
	},
	{
		texture = "content/ui/textures/frames/havoc_ranks/havoc_rank_6",
		level = 25,
	},
	{
		texture = "content/ui/textures/frames/havoc_ranks/havoc_rank_7",
		level = 30,
	},
	{
		texture = "content/ui/textures/frames/havoc_ranks/havoc_rank_8",
		level = 35,
	},
}

local view_settings = {
	havoc_max_level = 40,
	havoc_rank_badges = havoc_rank_badges,
	havoc_badge_size = { 200, 160 },
	sub_title_color = { 255, 0, 198, 255 },
	grid_settings = grid_settings,
	difficulty_slider_size = { 350, 64 },
	slider_size = { 530, 60 },
	slider_setting_width = 150,
	dropdown_size = { 550, 60 },
	dropdown_setting_width = 550,
	dropdown_max_visible_options = 6,
	dropdown_default_num_decimals = 0,
	dropdown_all_ids = {
		"normal_mission",
		"normal_side_mission",
		"normal_circumstance",
		"normal_mission_giver",
		"havoc_mission",
		"havoc_faction",
		"havoc_mission_giver",
		"havoc_circumstance1",
		"havoc_circumstance2",
		"havoc_theme_circumstance",
		"havoc_difficulty_circumstance",
	},
	dropdown_related_ids = {
		normal_mission = {
			"normal_circumstance",
			"normal_mission_giver",
		},
		havoc_mission = {
			"havoc_theme_circumstance",
			"havoc_mission_giver",
		},
	},
	dropdown_label_loc_keys = {
		normal_mission = "label_mission",
		normal_side_mission = "label_side_mission",
		normal_circumstance = "label_circumstance",
		normal_mission_giver = "label_mission_giver",
		havoc_mission = "label_mission",
		havoc_faction = "label_faction",
		havoc_mission_giver = "label_mission_giver",
		havoc_circumstance1 = "label_circumstance1",
		havoc_circumstance2 = "label_circumstance2",
		havoc_theme_circumstance = "label_theme_modifier",
		havoc_difficulty_circumstance = "label_difficulty_modifier",
	},
	dropdown_setting_keys = {
		normal_mission = "choose_mission",
		normal_side_mission = "choose_side_mission",
		normal_circumstance = "choose_circumstance",
		normal_mission_giver = "choose_mission_giver",
		havoc_mission = "havoc_mission",
		havoc_faction = "havoc_faction",
		havoc_mission_giver = "havoc_mission_giver",
		havoc_circumstance1 = "havoc_circumstance1",
		havoc_circumstance2 = "havoc_circumstance2",
		havoc_theme_circumstance = "havoc_theme_circumstance",
		havoc_difficulty_circumstance = "havoc_difficulty_circumstance",
	},
	dropdown_setting_default = {
		normal_mission = "prologue",
		normal_side_mission = "default",
		normal_circumstance = "default",
		normal_mission_giver = "default",
		havoc_mission = "cm_raid",
		havoc_faction = "mixed",
		havoc_mission_giver = "default",
		havoc_circumstance1 = 1,
		havoc_circumstance2 = 3,
		havoc_theme_circumstance = "default",
		havoc_difficulty_circumstance = "mutator_increased_difficulty",
	},
	regen_havoc_settings = {
		{
			id = "havoc_mission",
			data = "mission",
		},
		{
			id = "havoc_faction",
			data = "faction",
		},
		{
			id = "havoc_circumstance1",
			data = "circumstance1",
		},
		{
			id = "havoc_circumstance2",
			data = "circumstance2",
		},
		{
			id = "havoc_theme_circumstance",
			data = "theme_circumstance",
		},
		{
			id = "havoc_difficulty_circumstance",
			data = "difficulty_circumstance",
		},
	},
}

return view_settings
