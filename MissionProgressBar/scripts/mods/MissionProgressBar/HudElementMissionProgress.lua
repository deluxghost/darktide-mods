require("scripts/foundation/utilities/color")
local mod = get_mod("MissionProgressBar")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local HudElementMissionProgress = class("HudElementMissionProgress", "HudElementBase")

local bar_size = { 400, 8 }
local player_pos_expand_width = 8
local colors = {
	team = Color.deep_sky_blue(255, true),
	furthest = Color.citadel_teclis_blue(255, true),
}

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	mission_progress_bar_area = {
		parent = "screen",
		vertical_alignment = "bottom",
		horizontal_alignment = "center",
		size = { 400, 40 },
		position = {
			0,
			-20,
			10,
		},
	},
}
local widget_definitions = {
	bar = UIWidget.create_definition({
		{
			style_id = "team_bar",
			pass_type = "rect",
			style = {
				vertical_alignment = "top",
				horizontal_alignment = "left",
				offset = {
					0,
					0,
					30
				},
				size = {
					0,
					bar_size[2],
				},
				color = colors.team,
			}
		},
		{
			style_id = "furthest_bar",
			pass_type = "rect",
			style = {
				vertical_alignment = "top",
				horizontal_alignment = "left",
				offset = {
					0,
					0,
					20
				},
				size = {
					0,
					bar_size[2],
				},
				color = colors.furthest,
			}
		},
		{
			style_id = "background",
			pass_type = "rect",
			style = {
				vertical_alignment = "top",
				horizontal_alignment = "left",
				offset = {
					0,
					0,
					10
				},
				size = bar_size,
				color = { 255, 30, 30, 30 },
			}
		},
		{
			style_id = "border",
			pass_type = "rect",
			style = {
				vertical_alignment = "top",
				horizontal_alignment = "left",
				offset = {
					-1,
					-1,
					0
				},
				size = {
					bar_size[1] + 2,
					bar_size[2] + 2,
				},
				color = { 255, 128, 128, 128 },
			}
		},
	}, "mission_progress_bar_area"),
	label = UIWidget.create_definition({
		{
			value_id = "team_text",
			pass_type = "text",
			value = "",
			style = {
				text_color = colors.team,
				line_spacing = 1.0,
				font_size = 18,
				drop_shadow = true,
				font_type = "machine_medium",
				size = { 100, 25 },
				text_horizontal_alignment = "left",
				text_vertical_alignment = "top",
				horizontal_alignment = "left",
				vertical_alignment = "top",
				offset = {
					0,
					bar_size[2] + 4,
					0
				},
			},
		},
		{
			value_id = "furthest_text",
			pass_type = "text",
			value = "",
			style = {
				text_color = colors.furthest,
				line_spacing = 1.0,
				font_size = 18,
				drop_shadow = true,
				font_type = "machine_medium",
				size = { 100, 25 },
				text_horizontal_alignment = "center",
				text_vertical_alignment = "top",
				horizontal_alignment = "center",
				vertical_alignment = "top",
				offset = {
					0,
					bar_size[2] + 4,
					0
				},
			},
		},
		{
			value_id = "total_text",
			pass_type = "text",
			value = "",
			style = {
				text_color = { 255, 210, 210, 210 },
				line_spacing = 1.0,
				font_size = 18,
				drop_shadow = true,
				font_type = "machine_medium",
				size = { 100, 25 },
				text_horizontal_alignment = "right",
				text_vertical_alignment = "top",
				horizontal_alignment = "right",
				vertical_alignment = "top",
				offset = {
					0,
					bar_size[2] + 4,
					0
				},
			},
		},
	}, "mission_progress_bar_area"),
}

HudElementMissionProgress.init = function(self, parent, draw_layer, start_scale)
	HudElementMissionProgress.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = scenegraph_definition,
		widget_definitions = widget_definitions,
	})
end

HudElementMissionProgress.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudElementMissionProgress.super.update(self, dt, t, ui_renderer, render_settings, input_service)
	if not Managers.state or not Managers.state.main_path then
		return
	end
	if not Managers.state.main_path:is_main_path_ready() then
		return
	end
	local total = EngineOptimized.main_path_total_length() or 0
	local seg = 0
	if total > 0 then
		seg = bar_size[1] / total
	end
	self._widgets_by_name.label.content.total_text = string.format("%.f", total)

	if not Managers.player then
		return
	end
	local players = Managers.player:players()
	local near, far = nil, nil
	local furthest_pos = mod.cache["furthest_pos"] or 0
	for _, player in pairs(players) do
		if player:unit_is_alive() and ALIVE[player.player_unit] then
			local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system")
			if unit_data_extension then
				local character_state_component = unit_data_extension:read_component("character_state")
				if character_state_component and not PlayerUnitStatus.is_hogtied(character_state_component) then
					local player_position = Unit.world_position(player.player_unit, 1)
					local _, travel_distance, travel_percentage, _, _ = EngineOptimized.closest_pos_at_main_path(player_position)
					if travel_distance then
						if near == nil then
							near = travel_distance
						end
						if far == nil then
							far = travel_distance
						end
						if travel_distance < near then
							near = travel_distance
						end
						if travel_distance > far then
							far = travel_distance
						end
						if travel_distance > furthest_pos then
							furthest_pos = travel_distance
						end
					end
				end
			end
		end
	end

	mod.cache["furthest_pos"] = furthest_pos
	self._widgets_by_name.label.content.furthest_text = string.format("%.f", furthest_pos)
	local furthest_length = bar_size[1]
	if total > 0 then
		furthest_length = furthest_pos * seg
	end
	self._widgets_by_name.bar.style.furthest_bar.size[1] = furthest_length

	if near ~= nil and far ~= nil then
		if near > far then
			near, far = far, near
		end
		self._widgets_by_name.label.content.team_text = string.format("%.f", far)

		local length = bar_size[1]
		local pos = 0
		if total > 0 then
			near = near - player_pos_expand_width
			far = far + player_pos_expand_width
			if near < 0 then
				near = 0
			end
			if far > total then
				far = total
			end
			length = (far - near) * seg
			pos = near * seg
		end
		if length < player_pos_expand_width then
			length = player_pos_expand_width
		end
		if pos + length > bar_size[1] then
			length = bar_size[1] - pos
		end
		self._widgets_by_name.bar.style.team_bar.size[1] = length
		self._widgets_by_name.bar.style.team_bar.offset[1] = pos
	end
end

return HudElementMissionProgress
