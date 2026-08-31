local mod = get_mod("Realms")
local dmf = get_mod("DMF")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local TextInputUtils = dmf:io_dofile("dmf/scripts/mods/dmf/modules/ui/options/text_input_utils")
local MaskedTextInput = mod:io_dofile("Realms/scripts/mods/Realms/views/join_view/masked_text_input")
local Style = mod:io_dofile("Realms/scripts/mods/Realms/views/realms_view_style")

local PANEL_SIZE = {
	720,
	480,
}
local PANEL_INSET = 32
local CONTENT_WIDTH = PANEL_SIZE[1] - PANEL_INSET * 2

local scenegraph_definition = {
	screen = {
		scale = "fit",
		size = {
			1920,
			1080,
		},
		position = {
			0,
			0,
			80,
		},
	},
	panel = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "center",
		size = PANEL_SIZE,
		position = {
			0,
			0,
			2,
		},
	},
	title = {
		parent = "panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			CONTENT_WIDTH,
			52,
		},
		position = {
			PANEL_INSET,
			24,
			3,
		},
	},
	server_address_label = {
		parent = "panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			CONTENT_WIDTH,
			30,
		},
		position = {
			PANEL_INSET,
			92,
			3,
		},
	},
	server_address_input = {
		parent = "panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			CONTENT_WIDTH,
			58,
		},
		position = {
			PANEL_INSET,
			126,
			3,
		},
	},
	password_label = {
		parent = "panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			CONTENT_WIDTH,
			30,
		},
		position = {
			PANEL_INSET,
			204,
			3,
		},
	},
	password_input = {
		parent = "panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			CONTENT_WIDTH,
			58,
		},
		position = {
			PANEL_INSET,
			238,
			3,
		},
	},
	error_text = {
		parent = "panel",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = {
			CONTENT_WIDTH,
			58,
		},
		position = {
			PANEL_INSET,
			310,
			3,
		},
	},
	connect_button = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "bottom",
		size = {
			CONTENT_WIDTH,
			64,
		},
		position = {
			0,
			-PANEL_INSET,
			3,
		},
	},
	input_legend = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "bottom",
		size = {
			1920,
			56,
		},
		position = {
			0,
			-10,
			10,
		},
	},
}

local function label_style()
	local style = table.clone(UIFontSettings.header_4)

	style.horizontal_alignment = "left"
	style.vertical_alignment = "center"
	style.offset = {
		0,
		0,
		0,
	}
	style.text_color = Style.color("header_text")
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "center"

	return style
end

local title_style = table.clone(UIFontSettings.header_2)

title_style.text_color = Style.color("body_text")
title_style.text_horizontal_alignment = "left"
title_style.text_vertical_alignment = "top"

local function input_pass_template()
	local passes = TextInputUtils.clone_simple_input_field()

	for i = 1, #passes do
		local pass = passes[i]
		local style = pass.style

		if style then
			if pass.style_id == "focused" then
				style.color = Style.color("control_frame_hover")
			elseif pass.style_id == "background" then
				style.color = Style.color("control_background")
			elseif pass.style_id == "baseline" then
				style.color = Style.color("control_frame")
			elseif pass.style_id == "display_text" then
				style.text_color = Style.color("body_text")
			elseif pass.style_id == "input_caret" then
				style.color = Style.color("header_text")
			elseif pass.style_id == "selection" then
				style.color = Style.color("control_background_selected")
			elseif pass.style_id == "active_placeholder" or pass.style_id == "limit_text" then
				style.text_color = Style.color("secondary_text")
			end
		end
	end

	MaskedTextInput.add_to_passes(passes)

	return passes
end

local widget_definitions = {
	background = Style.create_background("screen"),
	panel = Style.create_panel("panel"),
	title = UIWidget.create_definition({
		{
			pass_type = "text",
			style = title_style,
			value = mod:localize("join_server"),
		},
	}, "title"),
	server_address_label = UIWidget.create_definition({
		{
			pass_type = "text",
			style = label_style(),
			value = mod:localize("join_server_address"),
		},
	}, "server_address_label"),
	server_address_input = UIWidget.create_definition(input_pass_template(), "server_address_input", {
		input_text = "",
		placeholder_text = mod:localize("join_server_address_placeholder"),
		virtual_keyboard_title = mod:localize("join_server_address"),
	}),
	password_label = UIWidget.create_definition({
		{
			pass_type = "text",
			style = label_style(),
			value = mod:localize("join_server_password"),
		},
	}, "password_label"),
	password_input = UIWidget.create_definition(input_pass_template(), "password_input", {
		input_text = "",
		mask_input = true,
		placeholder_text = "",
		virtual_keyboard_title = mod:localize("join_server_password"),
	}),
	error_text = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = table.merge(table.clone(UIFontSettings.body), {
				text_color = Color.ui_red_medium(255, true),
				text_horizontal_alignment = "left",
				text_vertical_alignment = "top",
			}),
		},
	}, "error_text"),
	connect_button = UIWidget.create_definition(Style.button_pass_template(), "connect_button", {
		original_text = mod:localize("join_server_connect"),
	}),
}

return {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
}
