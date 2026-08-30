local mod = get_mod("Realms")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local UIWidget = require("scripts/managers/ui/ui_widget")

local COLORS = {
	background_texture = {
		255,
		34,
		62,
		86,
	},
	panel_background = {
		236,
		30,
		47,
		62,
	},
	panel_frame = {
		210,
		85,
		119,
		143,
	},
	row_background = {
		232,
		40,
		62,
		80,
	},
	row_frame = {
		180,
		82,
		116,
		140,
	},
	header_text = {
		255,
		189,
		205,
		216,
	},
	body_text = {
		255,
		218,
		226,
		232,
	},
	secondary_text = {
		255,
		164,
		184,
		198,
	},
	status_idle = {
		255,
		157,
		174,
		186,
	},
	status_ready = {
		255,
		111,
		210,
		92,
	},
	control_background = {
		255,
		31,
		58,
		77,
	},
	control_background_selected = {
		255,
		47,
		87,
		113,
	},
	control_gradient = {
		150,
		56,
		98,
		124,
	},
	control_frame = {
		255,
		91,
		137,
		165,
	},
	control_frame_hover = {
		255,
		143,
		186,
		210,
	},
	control_icon = {
		255,
		189,
		213,
		226,
	},
}

local Style = {}

function Style.color(name)
	return table.clone(COLORS[name])
end

function Style.create_background(scenegraph_id)
	return UIWidget.create_definition({
		{
			pass_type = "texture",
			value = "content/ui/materials/backgrounds/terminal_basic",
			style = {
				scale_to_material = true,
				size_addition = {
					40,
					40,
				},
				offset = {
					-20,
					-20,
					1,
				},
				color = Style.color("background_texture"),
			},
		},
		{
			pass_type = "rect",
			style = {
				color = Color.black(255, true),
				offset = {
					0,
					0,
					0,
				},
			},
		},
	}, scenegraph_id)
end

function Style.create_panel(scenegraph_id)
	return UIWidget.create_definition({
		{
			pass_type = "rect",
			style = {
				color = Style.color("panel_background"),
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				scale_to_material = true,
				color = Style.color("panel_frame"),
				offset = {
					0,
					0,
					1,
				},
			},
		},
	}, scenegraph_id)
end

function Style.button_pass_template()
	local template = {}

	for i = 1, #ButtonPassTemplates.terminal_button do
		local source = ButtonPassTemplates.terminal_button[i]

		if source.style_id ~= "outer_shadow" and source.style_id ~= "corner" then
			local pass = table.clone(source)
			local style = pass.style

			if pass.style_id == "background" then
				style.default_color = Style.color("control_background")
				style.selected_color = Style.color("control_background_selected")
			elseif pass.style_id == "background_gradient" then
				style.color = Style.color("control_gradient")
				style.default_color = Style.color("control_gradient")
				style.selected_color = Style.color("control_frame")
			elseif pass.style_id == "frame" then
				style.default_color = Style.color("control_frame")
				style.hover_color = Style.color("control_frame_hover")
				style.selected_color = Style.color("control_frame_hover")
			elseif pass.style_id == "text" then
				style.default_color = Style.color("body_text")
				style.hover_color = Style.color("header_text")
				style.selected_color = Style.color("header_text")
			end

			template[#template + 1] = pass
		end
	end

	return template
end

return Style
