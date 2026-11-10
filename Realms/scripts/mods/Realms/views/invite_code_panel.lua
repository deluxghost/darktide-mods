local mod = get_mod("Realms")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local Style = mod:io_dofile("Realms/scripts/mods/Realms/views/realms_view_style")

-- Host-only invite code shown in the top-right corner of Realms menus. The code stays masked
-- until revealed so it does not leak on stream. Revealing applies to one view and resets on reopen.
local InviteCodePanel = {}

local PANEL_ID = "realms_invite_code"
local TOGGLE_ID = "realms_invite_code_toggle"
local COPY_ID = "realms_invite_code_copy"
local MASK = string.rep("•", 6)
local PADDING = 12
local TEXT_WIDTH = 156
local LABEL_HEIGHT = 26
local CODE_HEIGHT = 36
local BUTTON_WIDTH = 84
local BUTTON_HEIGHT = 32
local BUTTON_GAP = 6
local PANEL_WIDTH = PADDING + TEXT_WIDTH + PADDING + BUTTON_WIDTH + PADDING
local PANEL_HEIGHT = PADDING + BUTTON_HEIGHT + BUTTON_GAP + BUTTON_HEIGHT + PADDING
local TEXT_TOP = (PANEL_HEIGHT - LABEL_HEIGHT - CODE_HEIGHT) / 2
local TOGGLE_ACTION = "hotkey_menu_special_1"
local COPY_ACTION = "hotkey_menu_special_2"

local function text_style(font_size, color, y, height)
	local style = table.clone(UIFontSettings.body)

	style.font_size = font_size
	style.text_color = Style.color(color)
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "center"
	style.offset = {
		PADDING,
		y,
		2,
	}
	style.size = {
		TEXT_WIDTH,
		height,
	}

	return style
end

local function button_template()
	local template = Style.button_pass_template()

	for i = 1, #template do
		if template[i].style_id == "text" then
			template[i].style.font_size = 18
		end
	end

	return template
end

-- Adds the panel to a view definition. `parent` must be a full-screen 1920x1080 scenegraph node,
-- and `right_offset` leaves room for anything already in that corner.
function InviteCodePanel.extend_definitions(definitions, parent, right_offset, top_offset, layer)
	local scenegraph = definitions.scenegraph_definition
	local widgets = definitions.widget_definitions

	if scenegraph[PANEL_ID] then
		return
	end

	scenegraph[PANEL_ID] = {
		parent = parent,
		horizontal_alignment = "right",
		vertical_alignment = "top",
		size = {
			PANEL_WIDTH,
			PANEL_HEIGHT,
		},
		position = {
			-right_offset,
			top_offset,
			layer,
		},
	}
	scenegraph[TOGGLE_ID] = {
		parent = PANEL_ID,
		horizontal_alignment = "right",
		vertical_alignment = "top",
		size = {
			BUTTON_WIDTH,
			BUTTON_HEIGHT,
		},
		position = {
			-PADDING,
			PADDING,
			3,
		},
	}
	scenegraph[COPY_ID] = {
		parent = PANEL_ID,
		horizontal_alignment = "right",
		vertical_alignment = "bottom",
		size = {
			BUTTON_WIDTH,
			BUTTON_HEIGHT,
		},
		position = {
			-PADDING,
			-PADDING,
			3,
		},
	}

	local panel = Style.create_panel(PANEL_ID)

	UIWidget.add_definition_pass(panel, {
		pass_type = "text",
		value = mod:localize("invite_code"),
		style = text_style(18, "secondary_text", TEXT_TOP, LABEL_HEIGHT),
	})
	UIWidget.add_definition_pass(panel, {
		pass_type = "text",
		value = MASK,
		value_id = "code",
		style = text_style(28, "body_text", TEXT_TOP + LABEL_HEIGHT, CODE_HEIGHT),
	})

	widgets[PANEL_ID] = panel
	widgets[TOGGLE_ID] = UIWidget.create_definition(button_template(), TOGGLE_ID, {
		gamepad_action = TOGGLE_ACTION,
		original_text = "",
	})
	widgets[COPY_ID] = UIWidget.create_definition(button_template(), COPY_ID, {
		gamepad_action = COPY_ACTION,
		original_text = mod:localize("invite_code_copy"),
	})
end

local function set_visible(view, visible)
	local widgets = view._widgets_by_name

	widgets[PANEL_ID].visible = visible
	widgets[TOGGLE_ID].visible = visible
	widgets[COPY_ID].visible = visible
end

local function toggle(view)
	view._realms_invite_code_revealed = not view._realms_invite_code_revealed
end

local function copy(view)
	local code = mod._eos.host_code()

	if not code then
		return
	end

	if Clipboard.put(code) then
		mod:notify("%s", mod:localize("invite_code_copied"))
	end
end

function InviteCodePanel.attach(view)
	local widgets = view._widgets_by_name

	if not widgets[PANEL_ID] then
		return
	end

	view._realms_invite_code_revealed = false
	widgets[TOGGLE_ID].content.hotspot.pressed_callback = function ()
		toggle(view)
	end
	widgets[COPY_ID].content.hotspot.pressed_callback = function ()
		copy(view)
	end
	set_visible(view, false)
end

-- Call every frame after the view's own update. The panel appears and disappears with the host code.
function InviteCodePanel.update(view, input_service)
	local widgets = view._widgets_by_name
	local panel = widgets[PANEL_ID]

	if not panel then
		return
	end

	local code = mod._eos.host_code()

	set_visible(view, code ~= nil)

	if not code then
		return
	end

	if input_service and not input_service:is_null_service() and InputDevice.gamepad_active then
		if input_service:get(TOGGLE_ACTION) then
			toggle(view)
		elseif input_service:get(COPY_ACTION) then
			copy(view)
		end
	end

	local revealed = view._realms_invite_code_revealed

	panel.content.code = revealed and code or MASK
	widgets[TOGGLE_ID].content.original_text = mod:localize(revealed and "invite_code_hide" or "invite_code_show")
end

return InviteCodePanel
