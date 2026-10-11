local mod = get_mod("Mechanization")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local InputUtils = require("scripts/managers/input/input_utils")
local HudElementVehicleStatus = class("HudElementVehicleStatus", "HudElementBase")
local PADDING = 8
local BLOCK_GAP = 16
local LINE_HEIGHT = 18
local SECTION_GAP = 6
local BAR_HEIGHT = 3

local function text_pass (id, size, color, alignment)
	return {
		pass_type = "text",
		value_id = id,
		style_id = id,
		value = "",
		style = {
			font_type = "proxima_nova_bold",
			font_size = size,
			drop_shadow = true,
			text_horizontal_alignment = alignment or "center",
			text_vertical_alignment = "center",
			text_color = color,
			size = { 0, LINE_HEIGHT },
			offset = { 0, 0, 2 },
		},
	}
end

local function bar_pass (id, color, layer)
	return {
		pass_type = "rect",
		style_id = id,
		style = { color = color, size = { 0, BAR_HEIGHT }, offset = { 0, 0, layer } },
	}
end

local function status_definition (count)
	local passes = {
		{ pass_type = "rect", style = { color = { 150, 12, 18, 20 } } },
		text_pass("title", 15, { 255, 220, 211, 177 }),
		text_pass("health", 13, { 255, 149, 203, 184 }, "left"),
		text_pass("summary", 13, { 255, 149, 203, 184 }, "right"),
		text_pass("exit", 13, { 255, 220, 211, 177 }),
		bar_pass("exit_progress", { 255, 220, 211, 177 }, 2),
	}
	for index = 1, count do
		local key = "weapon_" .. index
		passes[#passes + 1] = text_pass(key .. "_label", 14, { 255, 235, 235, 225 })
		passes[#passes + 1] = text_pass(key .. "_text", 12, { 255, 220, 211, 177 })
		passes[#passes + 1] = bar_pass(key .. "_track", { 170, 60, 65, 65 }, 1)
		passes[#passes + 1] = bar_pass(key .. "_bar", { 255, 149, 203, 184 }, 2)
	end
	return UIWidget.create_definition(passes, "status")
end

local definitions = {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		status = {
			parent = "screen",
			size = { 0, 0 },
			vertical_alignment = "bottom",
			horizontal_alignment = "center",
			position = { 0, -145, 0 },
		},
	},
	widget_definitions = { status = status_definition(0) },
}

HudElementVehicleStatus.init = function (self, parent, draw_layer, start_scale)
	-- Native HUD panels start above the world markers' 0..300 layer range.
	HudElementVehicleStatus.super.init(self, parent, UIHudSettings.element_draw_layers.HudElementStamina, start_scale, definitions)
	self._weapon_count = 0
end

local function place (style, x, y, width, height)
	style.offset[1], style.offset[2] = x, y
	style.size[1] = width
	style.size[2] = height or BAR_HEIGHT
end

HudElementVehicleStatus._layout = function (self, ui_renderer, rows)
	local widget = self._widgets_by_name.status
	local content, style = widget.content, widget.style
	local widths, heights = {}, {}
	local function measure (id, reference)
		local measurement = style[id]
		local scale = ui_renderer.scale
		local font_size = measurement.font_size
		measurement.font_size = math.max(font_size * scale, 1)
		local width, height, _, caret = self:_text_size(ui_renderer, reference or content[id], measurement, { 1000000, LINE_HEIGHT * scale }, true)
		measurement.font_size = font_size
		-- Layout must include the final glyph advance, not only its visible outline.
		widths[id] = math.ceil(math.max(width, caret.x) / scale)
		heights[id] = math.max(LINE_HEIGHT, math.ceil(height / scale))
	end
	measure("title")
	measure("health", self._health_reference)
	measure("summary", self._summary_reference)
	measure("exit")
	local status_gap = content.health ~= "" and content.summary ~= "" and BLOCK_GAP or 0
	local status_width = widths.health + status_gap + widths.summary
	local status_height = math.max(heights.health, heights.summary)
	local width = math.max(widths.title, status_width, widths.exit)
	local block_width = 0
	local label_height, text_height = LINE_HEIGHT, LINE_HEIGHT
	for index = 1, #rows do
		local key = "weapon_" .. index
		measure(key .. "_label")
		measure(key .. "_text")
		block_width = math.max(block_width, widths[key .. "_label"], widths[key .. "_text"])
		label_height = math.max(label_height, heights[key .. "_label"])
		text_height = math.max(text_height, heights[key .. "_text"])
	end
	block_width = block_width + PADDING * 2
	local weapons_width = #rows > 0 and block_width * #rows + BLOCK_GAP * (#rows - 1) or 0
	width = math.max(width, weapons_width) + PADDING * 2
	local y = PADDING
	place(style.title, PADDING, y, width - PADDING * 2, heights.title)
	y = y + heights.title
	place(style.health, PADDING, y, widths.health, status_height)
	place(style.summary, width - PADDING - widths.summary, y, widths.summary, status_height)
	if content.health ~= "" or content.summary ~= "" then
		y = y + status_height
	end
	if #rows > 0 then
		y = y + SECTION_GAP
		local left = (width - weapons_width) * 0.5
		for index, row in ipairs(rows) do
			local key = "weapon_" .. index
			local x = left + (index - 1) * (block_width + BLOCK_GAP)
			place(style[key .. "_label"], x, y, block_width, label_height)
			place(style[key .. "_text"], x, y + label_height, block_width, text_height)
			place(style[key .. "_track"], x, y + label_height + text_height, block_width)
			place(style[key .. "_bar"], x, y + label_height + text_height, block_width * row.progress)
		end
		y = y + label_height + text_height + BAR_HEIGHT + SECTION_GAP
	end
	place(style.exit, PADDING, y, width - PADDING * 2, heights.exit)
	place(style.exit_progress, PADDING, y + heights.exit, (width - PADDING * 2) * self._interaction_progress)
	self:_set_scenegraph_size("status", width, y + heights.exit + BAR_HEIGHT + PADDING)
end

HudElementVehicleStatus.update = function (self, dt, t, ui_renderer, render_settings, input_service)
	HudElementVehicleStatus.super.update(self, dt, t, ui_renderer, render_settings, input_service)
	local session = mod.session
	local v, occupant
	if session then
		v, occupant = session.local_vehicle()
	end
	local boarding = not v and session and session.boarding.vehicle
	self._active = v ~= nil or boarding ~= nil
	if not self._active then
		return
	end
	local vehicle = v or boarding
	local rows = {}
	if v and v.type.status then
		for _, row in ipairs(v.type.status(v, session.clock)) do
			if session.occupants.action_owner(v, row.action) == occupant then
				local binding = v.type.actions[row.action]
				local alias = Managers.ui:get_input_alias_key(binding, "Ingame")
				local key = InputUtils.input_text_for_current_input_device("Ingame", alias, false)
				row.label = key .. " " .. row.label
				rows[#rows + 1] = row
			end
		end
	end
	if self._weapon_count ~= #rows then
		UIWidget.destroy(ui_renderer, self._widgets_by_name.status)
		self._widgets[1] = self:_create_widget("status", status_definition(#rows))
		self._weapon_count = #rows
	end
	local content = self._widgets_by_name.status.content
	content.title = mod:localize(vehicle.type.name)
	local key = InputUtils.input_text_for_current_input_device("Ingame", "interact", false)
	self._interaction_progress = session.interaction.progress()
	content.health = ""
	content.summary = ""
	self._health_reference = nil
	self._summary_reference = nil
	if v then
		content.exit = mod:localize(occupant.seat.movement and "hud_exit" or "hud_switch_exit", key)
		local max_health = v.health:max_health()
		content.health = mod:localize("hud_health", v.health:current_health(), max_health)
		self._health_reference = mod:localize("hud_health", max_health, max_health)
		if v.type.summary then
			content.summary, self._summary_reference = v.type.summary(v)
		end
	else
		local free = session.occupants.free_seat(boarding)
		content.exit = free and mod:localize("hud_board", key) or mod:localize("hud_full")
		self._interaction_progress = free and self._interaction_progress or 0
	end
	for index, row in ipairs(rows) do
		local id = "weapon_" .. index
		content[id .. "_label"] = row.label
		content[id .. "_text"] = row.text
	end
	self:_layout(ui_renderer, rows)
end

HudElementVehicleStatus.draw = function (self, ...)
	if self._active then
		HudElementVehicleStatus.super.draw(self, ...)
	end
end

return HudElementVehicleStatus
