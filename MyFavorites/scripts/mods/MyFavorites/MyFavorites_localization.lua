local loc = {
	mod_name = {
		en = "My Favorites",
		["zh-cn"] = "我的收藏",
		ru = "Моё избранное",
	},
	mod_description = {
		en = "Make favorite icons colorful.",
		["zh-cn"] = "为收藏图标添加颜色。",
		ru = "My Favorites - делает значок избранного цветным.",
	},
	show_extra_icon = {
		en = "Show extra star icons",
		["zh-cn"] = "显示额外的星星图标",
		ru = "Показать дополнительные значки-звёздочки",
	},
	favorite_preset_count = {
		en = "Number of enabled colors",
		["zh-cn"] = "启用的颜色数",
		ru = "Число выбранных цветов",
	},
	favorite_preset_count_description = {
		en = "Set how many icon colors you want.\nYou can choose color presets below.",
		["zh-cn"] = "设置你需要的图标颜色数量。\n你可以在下方选择颜色预设。",
		ru = "Укажите, сколько цветов значков вы хотите.\nВы можете выбрать предустановленные цвета ниже.",
	},
	color_definition = {
		en = "Color",
		["zh-cn"] = "颜色",
		ru = "Цвет",
	},
	color_demo_text = {
		en = "DEMO TEXT",
		["zh-cn"] = "演示文本",
		ru = "Пример текста",
	},
}

local color_list = {
	"ui_hud_red_light",
	"orange_red",
	"orange",
	"gold",
	"ui_difficulty_3",
	"green_yellow",
	"lawn_green",
	"ui_green_light",
	"spring_green",
	"ui_difficulty_1",
	"turquoise",
	"deep_sky_blue",
	"dodger_blue",
	"royal_blue",
	"blue_violet",
	"deep_pink",
	"deep_pink",
	"hot_pink",
	"crimson",
}

for _, color_name in ipairs(color_list) do
	local loc_id = "color_def_" .. color_name
	local color = Color[color_name](255, true)
	loc[loc_id] = {}
	for loc_lang, loc_demo in pairs(loc.color_demo_text) do
		local loc_value = string.format("{#color(%d,%d,%d)}%s{#reset()}", color[2], color[3], color[4], loc_demo)
		loc[loc_id][loc_lang] = loc_value
	end
end

for i = 1, 5 do
	local loc_key = "color_definition_" .. tostring(i)
	loc[loc_key] = {}
	for loc_lang, loc_text in pairs(loc.color_definition) do
		loc[loc_key][loc_lang] = loc_text .. " " .. tostring(i)
	end
end

return loc
