local mod = get_mod("SoloPlayStratagems")
local Pickups = require("scripts/settings/pickup/pickups")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")

local MAX_ACTIVE_ENTRIES = 6

local PANEL_OFFSET_X = 40
local PANEL_OFFSET_Y = 40
local INITIAL_PANEL_WIDTH = 360
local INITIAL_PANEL_CONTENT_WIDTH = 320
local INITIAL_PANEL_HEIGHT = 360
local INITIAL_PANEL_CONTENT_HEIGHT = 320
local PANEL_PADDING_LEFT = 20
local PANEL_PADDING_RIGHT = 20
local PANEL_PADDING_TOP = 20
local PANEL_PADDING_BOTTOM = 20

local HEADER_HEIGHT = 20
local ROW_HEIGHT = 54
local ROW_SPACING = 5

local ICON_SIZE = 40
local ICON_BORDER_WIDTH = 2
local ICON_INNER_SIZE = ICON_SIZE - ICON_BORDER_WIDTH * 2
local ICON_OFFSET_X = 8
local ICON_OFFSET_Y = 8

local TEXT_OFFSET_X = 54
local TEXT_RIGHT_PADDING = 10
local TITLE_TEXT_OFFSET_X = 2
local TITLE_TEXT_OFFSET_Y = 3
local NAME_OFFSET_Y = 3
local SEQUENCE_OFFSET_Y = 28
local TEXT_MEASURE_MAX_WIDTH = 800
local TEXT_MEASURE_HEIGHT = 50

local DEFAULT_ICON = "content/ui/materials/icons/perks/perk_level_05"
local DIMMED_ALPHA = 128

local ICON_TEXTURE_COLOR = { 255, 255, 255, 255 }
local DEFAULT_ICON_COLOR = { 255, 201, 178, 105 }
local DEFAULT_ICON_BG_COLOR = { 255, 54, 52, 38 }

local NAME_COLOR = Color.terminal_text_header(255, true)
local SEQUENCE_COLOR = Color.terminal_text_body_sub_header(255, true)
local SEQUENCE_COLOR_HIGHLIGHT = Color.terminal_text_body(255, true)
local SEQUENCE_COLOR_NEXT = { 255, 255, 255, 255 }

local function _entry_visible(content)
	return content.entry_visible == true
end

local function _color_with_alpha(color, alpha)
	return {
		alpha,
		color[2],
		color[3],
		color[4],
	}
end

local function _color_text(text, color)
	return string.format("{#color(%d,%d,%d)}%s{#reset()}", color[2], color[3], color[4], text)
end

local function _sequence_is_prefix(sequence, input_sequence)
	if #sequence > #input_sequence then
		return false
	end
	for index = 1, #sequence do
		if sequence[index] ~= input_sequence[index] then
			return false
		end
	end
	return true
end

local function _build_sequence_text(template, sequence)
	if #sequence == 0 or not _sequence_is_prefix(sequence, template.input_sequence) then
		return table.concat(template.input_display, "")
	end
	local parts = {}
	local last_input_index = #sequence
	local next_input_index = last_input_index + 1

	for index = 1, #template.input_display do
		local display = template.input_display[index]
		if index == last_input_index then
			parts[#parts + 1] = _color_text(display, SEQUENCE_COLOR_HIGHLIGHT)
		elseif index == next_input_index and next_input_index <= #template.input_display then
			parts[#parts + 1] = _color_text(display, SEQUENCE_COLOR_NEXT)
		else
			parts[#parts + 1] = display
		end
	end
	return table.concat(parts, "")
end

local function _sequence_base_color(sequence)
	return #sequence == 0 and SEQUENCE_COLOR_HIGHLIGHT or SEQUENCE_COLOR
end

local function _entry_sequence_color(sequence, dimmed)
	local base_color = _sequence_base_color(sequence)
	if dimmed then
		return _color_with_alpha(base_color, DIMMED_ALPHA)
	end
	return base_color
end

local function _hud_entries()
	local entries = {}
	local sequence = mod.state.sequence

	for _, template in ipairs(mod.templates.stratagems) do
		local category = mod.templates.categories[template.category]
		local pickup = Pickups.by_name[template.pocketable]
		local weapon_template = WeaponTemplates[template.pocketable]
		local name = pickup and pickup.description and Localize(pickup.description) or template.pocketable
		local icon = weapon_template and (weapon_template.hud_icon or weapon_template.hud_icon_small) or pickup and pickup.interaction_icon or DEFAULT_ICON
		local icon_color = category and category.color or DEFAULT_ICON_COLOR
		local matched_prefix = _sequence_is_prefix(sequence, template.input_sequence)
		local dimmed = #sequence > 0 and not matched_prefix

		entries[#entries + 1] = {
			dimmed = dimmed,
			icon = icon,
			icon_color = icon_color,
			icon_bg_color = DEFAULT_ICON_BG_COLOR,
			name_color = dimmed and _color_with_alpha(NAME_COLOR, DIMMED_ALPHA) or NAME_COLOR,
			name = name,
			sequence_plain = table.concat(template.input_display, ""),
			sequence = _build_sequence_text(template, sequence),
			sequence_color = _entry_sequence_color(sequence, dimmed),
		}
	end

	return entries
end

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	panel = {
		parent = "screen",
		size = { INITIAL_PANEL_WIDTH, INITIAL_PANEL_HEIGHT },
		vertical_alignment = "top",
		horizontal_alignment = "left",
		position = { PANEL_OFFSET_X, PANEL_OFFSET_Y, 400 },
	},
	panel_content = {
		parent = "panel",
		size = { INITIAL_PANEL_CONTENT_WIDTH, INITIAL_PANEL_CONTENT_HEIGHT },
		vertical_alignment = "top",
		horizontal_alignment = "left",
		position = { PANEL_PADDING_LEFT, PANEL_PADDING_TOP, 1 },
	},
	title = {
		parent = "panel_content",
		size = { INITIAL_PANEL_CONTENT_WIDTH, HEADER_HEIGHT },
		vertical_alignment = "top",
		horizontal_alignment = "left",
		position = { 0, 0, 1 },
	},
}

local widget_definitions = {
	panel_background = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "background",
			visibility_function = mod.stratagem_menu_visible,
			value = "content/ui/materials/backgrounds/terminal_basic",
			style = {
				scale_to_material = true,
				color = { 255, 50, 75, 50 },
				size = { INITIAL_PANEL_WIDTH, INITIAL_PANEL_HEIGHT },
			},
		},
	}, "panel"),
	title_text = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "title",
			value_id = "title",
			value = mod:localize("stratagem_menu_title"),
			visibility_function = mod.stratagem_menu_visible,
			style = {
				font_type = "machine_medium",
				font_size = 20,
				text_vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_color = Color.terminal_text_header(255, true),
				offset = { TITLE_TEXT_OFFSET_X, TITLE_TEXT_OFFSET_Y, 0 }
			},
		},
	}, "title"),
}

local function _create_row_scenegraph_definition(index)
	local y = HEADER_HEIGHT + 12 + (index - 1) * (ROW_HEIGHT + ROW_SPACING)
	return {
		parent = "panel_content",
		size = { INITIAL_PANEL_CONTENT_WIDTH, ROW_HEIGHT },
		vertical_alignment = "top",
		horizontal_alignment = "left",
		position = { 0, y, 1 },
	}
end

local function _create_row_widget_definition(scenegraph_id)
	return UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "background",
			visibility_function = _entry_visible,
			style = {
				color = { 145, 11, 17, 16 },
			},
		},
		{
			pass_type = "rect",
			style_id = "icon_border",
			visibility_function = _entry_visible,
			style = {
				color = DEFAULT_ICON_COLOR,
				size = { ICON_SIZE, ICON_SIZE },
				offset = { ICON_OFFSET_X, ICON_OFFSET_Y, 1 },
			},
		},
		{
			pass_type = "rect",
			style_id = "icon_background",
			visibility_function = _entry_visible,
			style = {
				color = DEFAULT_ICON_BG_COLOR,
				size = { ICON_INNER_SIZE, ICON_INNER_SIZE },
				offset = { ICON_OFFSET_X + ICON_BORDER_WIDTH, ICON_OFFSET_Y + ICON_BORDER_WIDTH, 2 },
			},
		},
		{
			pass_type = "texture",
			style_id = "icon",
			value_id = "icon",
			visibility_function = _entry_visible,
			style = {
				color = ICON_TEXTURE_COLOR,
				size = { ICON_INNER_SIZE, ICON_INNER_SIZE },
				offset = { ICON_OFFSET_X + ICON_BORDER_WIDTH, ICON_OFFSET_Y + ICON_BORDER_WIDTH, 3 },
			},
		},
		{
			pass_type = "text",
			style_id = "name",
			value_id = "name",
			visibility_function = _entry_visible,
			style = {
				font_type = "machine_medium",
				font_size = 18,
				text_vertical_alignment = "top",
				text_horizontal_alignment = "left",
				text_color = Color.terminal_text_header(255, true),
				size = { 220, 22 },
				offset = { TEXT_OFFSET_X, NAME_OFFSET_Y, 2 },
			},
		},
		{
			pass_type = "text",
			style_id = "sequence",
			value_id = "sequence",
			visibility_function = _entry_visible,
			style = {
				font_type = "machine_medium",
				font_size = 18,
				text_vertical_alignment = "bottom",
				text_horizontal_alignment = "left",
				text_color = Color.terminal_text_body(255, true),
				size = { 236, 20 },
				offset = { TEXT_OFFSET_X, SEQUENCE_OFFSET_Y, 2 },
			},
		},
	}, scenegraph_id)
end

for i = 1, MAX_ACTIVE_ENTRIES do
	local scenegraph_id = string.format("entry_%d", i)
	local widget_id = string.format("entry_%d", i)

	scenegraph_definition[scenegraph_id] = _create_row_scenegraph_definition(i)
	widget_definitions[widget_id] = _create_row_widget_definition(scenegraph_id)
end

local definitions = {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
}

HudElementStratagemMenu = class("HudElementStratagemMenu", "HudElementBase")

function HudElementStratagemMenu:init(parent, draw_layer, start_scale)
	HudElementStratagemMenu.super.init(self, parent, draw_layer, start_scale, definitions)
	self._cached_title_width = nil
	self._cached_entry_name_widths = {}
	self._cached_entry_sequence_widths = {}
	self:_set_entry_layout(0, nil, {})
end

function HudElementStratagemMenu:_measure_text_width(ui_renderer, text, style, size)
	local width = self:_text_size(ui_renderer, text, style, size)
	return math.ceil(width)
end

function HudElementStratagemMenu:_update_entry_width(ui_renderer, entries)
	local title_style = self._widgets_by_name.title_text.style.title
	local title_text = self._widgets_by_name.title_text.content.title or ""

	if self._cached_title_width == nil or self._cached_title_text ~= title_text then
		self._cached_title_text = title_text
		self._cached_title_width = self:_measure_text_width(ui_renderer, title_text, title_style, { TEXT_MEASURE_MAX_WIDTH, TEXT_MEASURE_HEIGHT }) + TITLE_TEXT_OFFSET_X
	end

	local title_width = self._cached_title_width
	local max_text_width = 0

	for index = 1, #entries do
		local entry = entries[index]
		local name_width = self._cached_entry_name_widths[entry.name]
		local sequence_width = self._cached_entry_sequence_widths[entry.sequence_plain]

		if not name_width then
			name_width = self:_measure_text_width(ui_renderer, entry.name, self._widgets_by_name.entry_1.style.name, { TEXT_MEASURE_MAX_WIDTH, TEXT_MEASURE_HEIGHT })
			self._cached_entry_name_widths[entry.name] = name_width
		end

		if not sequence_width then
			sequence_width = self:_measure_text_width(ui_renderer, entry.sequence_plain, self._widgets_by_name.entry_1.style.sequence, { TEXT_MEASURE_MAX_WIDTH, TEXT_MEASURE_HEIGHT })
			self._cached_entry_sequence_widths[entry.sequence_plain] = sequence_width
		end

		local entry_text_width = math.max(name_width, sequence_width)

		if max_text_width < entry_text_width then
			max_text_width = entry_text_width
		end
	end

	local content_width = math.max(title_width, TEXT_OFFSET_X + max_text_width + TEXT_RIGHT_PADDING)
	local panel_width = PANEL_PADDING_LEFT + content_width + PANEL_PADDING_RIGHT

	return content_width, panel_width
end

function HudElementStratagemMenu:_set_entry_layout(entry_count, ui_renderer, entries)
	local row_count = math.max(entry_count, 1)
	local content_height = HEADER_HEIGHT + 12 + row_count * ROW_HEIGHT + (row_count - 1) * ROW_SPACING
	local content_width = INITIAL_PANEL_CONTENT_WIDTH
	local panel_width = INITIAL_PANEL_WIDTH

	if ui_renderer then
		content_width, panel_width = self:_update_entry_width(ui_renderer, entries)
	end
	local panel_height = PANEL_PADDING_TOP + content_height + PANEL_PADDING_BOTTOM

	self:_set_scenegraph_size("panel", panel_width, panel_height)
	self:_set_scenegraph_size("panel_content", content_width, content_height)
	self:_set_scenegraph_size("title", content_width, HEADER_HEIGHT)

	for index = 1, MAX_ACTIVE_ENTRIES do
		self:_set_scenegraph_size(string.format("entry_%d", index), content_width, ROW_HEIGHT)
	end

	self._widgets_by_name.title_text.style.title.size = { content_width, HEADER_HEIGHT }
	self._widgets_by_name.panel_background.style.background.size[1] = panel_width
	self._widgets_by_name.panel_background.style.background.size[2] = panel_height

	for index = 1, MAX_ACTIVE_ENTRIES do
		local widget = self._widgets_by_name[string.format("entry_%d", index)]
		local text_width = math.max(content_width - TEXT_OFFSET_X, 0)

		widget.style.name.size[1] = text_width
		widget.style.sequence.size[1] = text_width
	end
end

function HudElementStratagemMenu:_update_entry_widget(index, entry)
	local widget = self._widgets_by_name[string.format("entry_%d", index)]

	if entry then
		widget.content.entry_visible = true
		widget.content.icon = entry.icon
		widget.content.name = entry.name
		widget.content.sequence = entry.sequence
		widget.style.icon_border.color = entry.dimmed and _color_with_alpha(entry.icon_color, DIMMED_ALPHA) or entry.icon_color
		widget.style.icon_background.color = entry.icon_bg_color
		widget.style.icon.color = entry.dimmed and _color_with_alpha(ICON_TEXTURE_COLOR, DIMMED_ALPHA) or ICON_TEXTURE_COLOR
		widget.style.name.text_color = entry.name_color
		widget.style.sequence.text_color = entry.sequence_color
	else
		widget.content.entry_visible = false
		widget.content.icon = ""
		widget.content.name = ""
		widget.content.sequence = ""
		widget.style.icon_border.color = DEFAULT_ICON_COLOR
		widget.style.icon_background.color = DEFAULT_ICON_BG_COLOR
		widget.style.icon.color = ICON_TEXTURE_COLOR
		widget.style.name.text_color = NAME_COLOR
		widget.style.sequence.text_color = SEQUENCE_COLOR_HIGHLIGHT
	end
end

HudElementStratagemMenu.update = function (self, dt, t, ui_renderer, render_settings, input_service)
	HudElementStratagemMenu.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local visible = mod.stratagem_menu_visible()
	local entries = visible and _hud_entries() or {}
	local has_entries = #entries > 0
	local show_panel = visible and has_entries

	self:_set_entry_layout(#entries, ui_renderer, entries)

	for i = 1, MAX_ACTIVE_ENTRIES do
		self:_update_entry_widget(i, show_panel and entries[i] or nil)
	end
end

return HudElementStratagemMenu
