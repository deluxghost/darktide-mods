local mod = get_mod("SoloPlayStratagems")

local templates = {}

templates.UP = "^"
templates.DOWN = "v"
templates.LEFT = "<"
templates.RIGHT = ">"

templates.categories = {
	strike = {
		color = { 255, 221, 102, 88 },
		bg_color = { 255, 25, 3, 1 },
	},
	equipment = {
		color = { 255, 83, 188, 218 },
		bg_color = { 255, 1, 20, 25 },
	},
	emplacement = {
		color = { 255, 103, 148, 82 },
		bg_color = { 255, 9, 25, 1 },
	},
}

templates.input_directions = {
	[templates.UP] = {
		internal = templates.UP,
		display = "",
		action = "keyboard_move_forward",
	},
	[templates.DOWN] = {
		internal = templates.DOWN,
		display = "",
		action = "keyboard_move_backward",
	},
	[templates.LEFT] = {
		internal = templates.LEFT,
		display = "",
		action = "keyboard_move_left",
	},
	[templates.RIGHT] = {
		internal = templates.RIGHT,
		display = "",
		action = "keyboard_move_right",
	},
}

templates.stratagems = {
	{
		pocketable = "expedition_grenade_airstrike_pocketable",
		input = "^>v>",
		category = "strike",
	},
	{
		pocketable = "expedition_grenade_valkyrie_hover_pocketable",
		input = "^>^<",
		category = "strike",
	},
}

templates.input_directions_by_action = {}
for _, direction in pairs(templates.input_directions) do
	templates.input_directions_by_action[direction.action] = direction
end

for _, template in ipairs(templates.stratagems) do
	template.input_sequence = {}
	template.input_display = {}

	for index = 1, #template.input do
		local input = string.sub(template.input, index, index)
		local direction = templates.input_directions[input]

		if direction then
			template.input_sequence[#template.input_sequence + 1] = input
			template.input_display[#template.input_display + 1] = direction.display
		end
	end
end

return templates
