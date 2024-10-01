local mod = get_mod("MyFavorites")

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
	"hot_pink",
	"deep_pink",
	"crimson",
}

local color_widget = {
	setting_id = "color_definition",
	type = "group",
	sub_widgets = {
		{
			setting_id = "color_definition_1",
			type = "dropdown",
			default_value = "orange",
			options = {},
		},
		{
			setting_id = "color_definition_2",
			type = "dropdown",
			default_value = "lawn_green",
			options = {},
		},
		{
			setting_id = "color_definition_3",
			type = "dropdown",
			default_value = "deep_sky_blue",
			options = {},
		},
		{
			setting_id = "color_definition_4",
			type = "dropdown",
			default_value = "blue_violet",
			options = {},
		},
		{
			setting_id = "color_definition_5",
			type = "dropdown",
			default_value = "deep_pink",
			options = {},
		},
	},
}

local color_options = {}
for _, color_name in ipairs(color_list) do
	table.insert(color_options, {
		text = "color_def_" .. color_name,
		value = color_name,
	})
end

for _, sub_widget in ipairs(color_widget.sub_widgets) do
	sub_widget.options = table.clone(color_options)
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "show_extra_icon",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "favorite_preset_count",
				type = "numeric",
				default_value = 5,
				range = { 1, 5 },
			},
			color_widget,
		}
	}
}
