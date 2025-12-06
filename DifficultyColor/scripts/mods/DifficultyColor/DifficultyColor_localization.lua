local loc = {
	mod_name = {
		en = "Difficulty Color",
		["zh-cn"] = "难度颜色",
		ru = "Цвета сложности",
	},
	mod_description = {
		en = "Customize the color of each difficulty.",
		["zh-cn"] = "自定义每个难度的颜色。",
		ru = "Difficulty Color - Настройте цвета каждой сложности.",
	},
	common_r = {
		en = "Red",
		["zh-cn"] = "红",
		ru = "Красный",
	},
	common_g = {
		en = "Green",
		["zh-cn"] = "绿",
		ru = "Зелёный",
	},
	common_b = {
		en = "Blue",
		["zh-cn"] = "蓝",
		ru = "Синий",
	},
	opt_color_1 = {
		en = Localize("loc_mission_board_danger_low"),
	},
	opt_color_2 = {
		en = Localize("loc_mission_board_danger_medium"),
	},
	opt_color_3 = {
		en = Localize("loc_mission_board_danger_high"),
	},
	opt_color_4 = {
		en = Localize("loc_mission_board_danger_highest"),
	},
	opt_color_5 = {
		en = Localize("loc_group_finder_difficulty_auric"),
	},
}

for i = 1, 5 do
	loc["opt_color_" .. tostring(i) .. "_r"] = table.clone(loc["common_r"])
	loc["opt_color_" .. tostring(i) .. "_g"] = table.clone(loc["common_g"])
	loc["opt_color_" .. tostring(i) .. "_b"] = table.clone(loc["common_b"])
end

return loc
