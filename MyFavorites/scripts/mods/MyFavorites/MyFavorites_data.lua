local mod = get_mod("MyFavorites")

local default_colors = {
	{ 255, 255, 165, 0 },
	{ 255, 124, 252, 0 },
	{ 255, 0, 191, 255 },
	{ 255, 138, 43, 226 },
	{ 255, 255, 20, 147 },
}

local color_widgets = {}
for index, color in ipairs(default_colors) do
	color_widgets[#color_widgets + 1] = {
		setting_id = "favorite_color_" .. tostring(index),
		type = "color",
		title = "color_definition_" .. tostring(index),
		default_value = color,
	}
end

local count_options = { localize = false }
for count = 1, #color_widgets do
	local show_widgets = {}
	for index = 1, count do
		show_widgets[#show_widgets + 1] = index
	end
	count_options[#count_options + 1] = {
		text = tostring(count),
		value = count,
		show_widgets = show_widgets,
	}
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
				type = "dropdown",
				default_value = 5,
				options = count_options,
				sub_widgets = color_widgets,
			},
		}
	}
}
