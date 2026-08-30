local mod = get_mod("Realms")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local MissionDetailsBlueprints = require("scripts/ui/views/mission_voting_view/mission_voting_view_blueprints")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UISettings = require("scripts/settings/ui/ui_settings")
local Layout = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/preparation_view_layout")
local Loadout = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/loadout")
local Style = mod:io_dofile("Realms/scripts/mods/Realms/views/realms_view_style")

local PLAYER_ROW_HEIGHT = 80
local PLAYER_ROW_WIDTH = Layout.player_row_width
local INFO_ROW_WIDTH = Layout.info_row_width
local COLUMNS = Layout.player_columns
local MAX_SKILLS = 5
local SKILL_SIZE = 40
local SKILL_SPACING = 4
local WEAPON_WIDTH = 144
local WEAPON_HEIGHT = 44
local WEAPON_SPACING = 8

local function text_style(font_size, color)
	local style = table.clone(UIFontSettings.body)

	style.font_size = font_size
	style.horizontal_alignment = "left"
	style.text_color = color
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "center"
	style.vertical_alignment = "center"

	return style
end

local function content_visible(content_id)
	return function (content)
		return content[content_id] ~= nil
	end
end

local function hotspot_visible(content_id)
	return function (content)
		return content.parent[content_id] ~= nil
	end
end

local function selected_frame_visible(content_id, hotspot_id)
	return function (content)
		local hotspot = content[hotspot_id]

		return content[content_id] ~= nil and (hotspot.is_hover or hotspot.is_selected)
	end
end

local function terminal_hover_change(hotspot_id)
	return function (content, style)
		ButtonPassTemplates.terminal_button_hover_change_function(content, style, hotspot_id)
	end
end

local function terminal_color_change(hotspot_id)
	return function (content, style)
		ButtonPassTemplates.terminal_button_change_function(content, style, hotspot_id)
	end
end

local player_pass_template = {
	{
		pass_type = "rect",
		style = {
			color = Style.color("row_background"),
		},
	},
	{
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = {
			scale_to_material = true,
			color = Style.color("row_frame"),
			offset = {
				0,
				0,
				1,
			},
		},
	},
	{
		pass_type = "texture",
		style_id = "character_portrait",
		value = "content/ui/materials/base/ui_portrait_frame_base",
		value_id = "character_portrait",
		style = {
			material_values = {
				texture_icon = "content/ui/textures/icons/items/frames/default",
				use_placeholder_texture = 1,
			},
			offset = {
				COLUMNS.portrait.x,
				8,
				3,
			},
			size = {
				COLUMNS.portrait.width,
				64,
			},
		},
	},
	{
		pass_type = "text",
		style = table.merge(text_style(24, Style.color("body_text")), {
			vertical_alignment = "top",
			offset = {
				COLUMNS.player.x,
				5,
				3,
			},
			size = {
				COLUMNS.player.width,
				34,
			},
		}),
		style_id = "player_name",
		value = "",
		value_id = "player_name",
	},
	{
		pass_type = "text",
		style = table.merge(text_style(21, Style.color("secondary_text")), {
			vertical_alignment = "top",
			offset = {
				COLUMNS.player.x,
				39,
				3,
			},
			size = {
				COLUMNS.player.width,
				30,
			},
		}),
		style_id = "class_name",
		value = "",
		value_id = "class_name",
	},
	{
		pass_type = "text",
		style = table.merge(text_style(32, Style.color("status_idle")), {
			offset = {
				COLUMNS.status.x,
				0,
				3,
			},
			size = {
				COLUMNS.status.width,
				PLAYER_ROW_HEIGHT,
			},
			text_horizontal_alignment = "center",
		}),
		style_id = "ready_status",
		value = "",
		value_id = "ready_status",
	},
}

for i = 1, MAX_SKILLS do
	local content_id = "skill_" .. i
	local hotspot_id = "skill_hotspot_" .. i
	local frame_id = "skill_frame_" .. i
	local offset_x = COLUMNS.talents.x + 4 + (i - 1) * (SKILL_SIZE + SKILL_SPACING)
	local offset_y = math.floor((PLAYER_ROW_HEIGHT - SKILL_SIZE) * 0.5)

	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		style_id = content_id,
		value = "content/ui/materials/frames/talents/talent_icon_container",
		style = {
			color = Color.white(255, true),
			material_values = {},
			offset = {
				offset_x,
				offset_y,
				4,
			},
			size = {
				SKILL_SIZE,
				SKILL_SIZE,
			},
		},
		visibility_function = content_visible(content_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		style_id = frame_id,
		value_id = frame_id,
		style = {
			color = Color.ui_terminal(255, true),
			offset = {
				offset_x,
				offset_y,
				5,
			},
			size = {
				SKILL_SIZE,
				SKILL_SIZE,
			},
		},
		visibility_function = selected_frame_visible(content_id, hotspot_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		content_id = hotspot_id,
		content = {},
		pass_type = "hotspot",
		style_id = hotspot_id,
		style = {
			offset = {
				offset_x,
				offset_y,
				8,
			},
			size = {
				SKILL_SIZE,
				SKILL_SIZE,
			},
		},
		visibility_function = hotspot_visible(content_id),
	}
end

for i = 1, 2 do
	local content_id = "weapon_" .. i
	local hotspot_id = "weapon_hotspot_" .. i
	local offset_x = COLUMNS.weapons.x + (i - 1) * (WEAPON_WIDTH + WEAPON_SPACING)
	local offset_y = math.floor((PLAYER_ROW_HEIGHT - WEAPON_HEIGHT) * 0.5)
	local function weapon_style(offset_z)
		return {
			offset = {
				offset_x,
				offset_y,
				offset_z,
			},
			size = {
				WEAPON_WIDTH,
				WEAPON_HEIGHT,
			},
		}
	end

	player_pass_template[#player_pass_template + 1] = {
		content_id = hotspot_id,
		content = {},
		pass_type = "hotspot",
		style_id = hotspot_id,
		style = weapon_style(10),
		visibility_function = hotspot_visible(content_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		value = "content/ui/materials/frames/dropshadow_medium",
		style = {
			color = Color.black(200, true),
			scale_to_material = true,
			offset = {
				offset_x - 10,
				offset_y - 10,
				2,
			},
			size = {
				WEAPON_WIDTH + 20,
				WEAPON_HEIGHT + 20,
			},
		},
		visibility_function = content_visible(content_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		style_id = content_id .. "_icon",
		value_id = content_id .. "_icon",
		style = table.merge(weapon_style(7), {
			color = Style.color("control_icon"),
			default_color = Style.color("control_icon"),
			hover_color = Style.color("header_text"),
			selected_color = Style.color("header_text"),
		}),
		change_function = terminal_color_change(hotspot_id),
		visibility_function = content_visible(content_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		value = "content/ui/materials/backgrounds/default_square",
		style = table.merge(weapon_style(3), {
			color = Style.color("control_background"),
		}),
		visibility_function = content_visible(content_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		value = "content/ui/materials/gradients/gradient_vertical",
		style = table.merge(weapon_style(4), {
			color = Style.color("control_gradient"),
		}),
		visibility_function = content_visible(content_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		value = "content/ui/materials/gradients/gradient_diagonal_down_right",
		style = table.merge(weapon_style(5), {
			color = Style.color("control_gradient"),
			default_color = Style.color("control_gradient"),
			hover_color = Style.color("control_background_selected"),
			selected_color = Style.color("control_background_selected"),
		}),
		change_function = terminal_hover_change(hotspot_id),
		visibility_function = content_visible(content_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = table.merge(weapon_style(8), {
			color = Style.color("control_frame"),
			default_color = Style.color("control_frame"),
			hover_color = Style.color("control_frame_hover"),
			selected_color = Style.color("control_frame_hover"),
		}),
		change_function = terminal_color_change(hotspot_id),
		visibility_function = content_visible(content_id),
	}
	player_pass_template[#player_pass_template + 1] = {
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_corner_2px",
		style = table.merge(weapon_style(9), {
			color = Style.color("control_frame"),
			default_color = Style.color("control_frame"),
			hover_color = Style.color("control_frame_hover"),
			selected_color = Style.color("control_frame_hover"),
		}),
		change_function = terminal_color_change(hotspot_id),
		visibility_function = content_visible(content_id),
	}
end

local function init_player(parent, widget, element)
	local content = widget.content
	local portrait_style = widget.style.character_portrait
	local material_values = portrait_style.material_values
	local has_portrait = element.portrait_render_target ~= nil

	content.element = element
	content.character_portrait = element.portrait_frame_material or UISettings.portrait_frame_default_material
	content.class_name = element.class_name
	content.player_name = element.player_name
	content.ready_status = element.ready_status
	material_values.columns = element.portrait_columns
	material_values.grid_index = element.portrait_grid_index
	material_values.portrait_frame_texture = element.portrait_frame_texture
	material_values.rows = element.portrait_rows
	material_values.texture_icon = element.portrait_render_target
	material_values.use_placeholder_texture = has_portrait and 0 or 1
	widget.style.ready_status.text_color = element.ready and Style.color("status_ready") or Style.color("status_idle")

	for i = 1, MAX_SKILLS do
		local skill = element.skills[i]
		local content_id = "skill_" .. i
		local hotspot_id = "skill_hotspot_" .. i
		local frame_id = "skill_frame_" .. i

		content[content_id] = skill
		content[hotspot_id].disabled = skill == nil

		if skill then
			local node_settings = Loadout.node_settings(skill.node_type)
			local skill_material_values = widget.style[content_id].material_values

			skill_material_values.frame = node_settings.frame
			skill_material_values.gradient_map = node_settings.gradient_map
			skill_material_values.icon = skill.icon
			skill_material_values.icon_mask = node_settings.icon_mask
			content[frame_id] = node_settings.selected_material
		else
			content[frame_id] = nil
		end
	end

	for i = 1, 2 do
		local weapon = element.weapons[i]
		local content_id = "weapon_" .. i
		local hotspot_id = "weapon_hotspot_" .. i

		content[content_id] = weapon and weapon.item and weapon.icon and weapon or nil
		content[content_id .. "_icon"] = weapon and weapon.icon
		content[hotspot_id].disabled = not weapon or not weapon.item or not weapon.icon
	end
end

local function official_blueprint(template_name)
	local template = MissionDetailsBlueprints.templates[template_name]

	return {
		init = function (parent, widget, element, callback_name, secondary_callback_name, ui_renderer)
			widget.content.element = element
			template.init(widget, element.widget_data, ui_renderer)
		end,
		pass_template = template.pass_template,
		size = {
			INFO_ROW_WIDTH,
			template.size[2],
		},
		style_function = function ()
			return table.clone(template.style)
		end,
	}
end

return {
	max_skills = MAX_SKILLS,
	blueprints = {
		circumstance = official_blueprint("circumstance"),
		player = {
			init = init_player,
			pass_template = player_pass_template,
			size = {
				PLAYER_ROW_WIDTH,
				PLAYER_ROW_HEIGHT,
			},
		},
		side_mission = official_blueprint("side_mission"),
	},
}
