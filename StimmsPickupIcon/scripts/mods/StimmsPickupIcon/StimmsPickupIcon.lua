local mod = get_mod("StimmsPickupIcon")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local settings = mod:persistent_table("settings")
local recolor_mod = nil

local STIMM_COLORS = {
	syringe_corruption_pocketable = { 255, 38, 205, 26 },
	syringe_ability_boost_pocketable = { 255, 230, 192, 13 },
	syringe_power_boost_pocketable = { 255, 205, 51, 26 },
	syringe_speed_boost_pocketable = { 255, 0, 127, 218 },
}

mod.on_all_mods_loaded = function ()
	recolor_mod = get_mod("RecolorStimms")
end

mod.on_enabled = function ()
	settings.use_recolor_stimms_mod = mod:get("use_recolor_stimms_mod")
	settings.show_pickup_color = mod:get("show_pickup_color")
	settings.show_team_panel_color = mod:get("show_team_panel_color")
	settings.show_self_weapon_color = mod:get("show_self_weapon_color")
end

mod.on_setting_changed = function (setting_id)
	settings.use_recolor_stimms_mod = mod:get("use_recolor_stimms_mod")
	settings.show_pickup_color = mod:get("show_pickup_color")
	settings.show_team_panel_color = mod:get("show_team_panel_color")
	settings.show_self_weapon_color = mod:get("show_self_weapon_color")
end

local get_stimm_colors = function (stimm_name)
	local main_color = settings.use_recolor_stimms_mod
		and recolor_mod
		and recolor_mod:is_enabled()
		and recolor_mod.get_stimm_argb_255
		and recolor_mod.get_stimm_argb_255(stimm_name)
		or STIMM_COLORS[stimm_name]
	if not main_color then
		return nil, nil, nil
	end

	local color_offset = (main_color[2] + main_color[3] + main_color[4]) / 3.0 > 64 and 0 or 128
	local trim_color = { 255,
		math.floor(0.4 * main_color[2] + color_offset),
		math.floor(0.4 * main_color[3] + color_offset),
		math.floor(0.4 * main_color[4] + color_offset),
	}
	local light_color = { 255,
		math.min(255, math.floor(1.2 * main_color[2])),
		math.min(255, math.floor(1.2 * main_color[3])),
		math.min(255, math.floor(1.2 * main_color[4])),
	}
	return main_color, trim_color, light_color
end

local function argb_to_abgr(color)
	return {
		color[1],
		color[4],
		color[3],
		color[2],
	}
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "event_add_world_marker_unit", function (self, marker_type, unit, callback, data)
	if marker_type ~= "interaction" then
		return
	end
	if not unit or not Unit then
		return
	end
	if not Unit.alive(unit) then
		return
	end
	if not Unit.has_data(unit, "pickup_type") then
		return
	end
	local pickup_type = Unit.get_data(unit, "pickup_type")
	if not pickup_type then
		return
	end
	local marker = nil
	for _, m in ipairs(self._markers) do
		if m.unit == unit then
			marker = m
		end
	end
	if not marker then
		return
	end
	local bg_color, color, _ = get_stimm_colors(pickup_type)
	if bg_color and color then
		for _, pass in ipairs(marker.widget.passes) do
			if pass.value_id == "icon" then
				local f = pass.visibility_function
				pass.visibility_function = function (content, style)
					if settings.show_pickup_color then
						style.color = color
					end
					return f(content, style)
				end
			end
			if pass.value_id == "background" then
				local f = pass.visibility_function
				pass.visibility_function = function (content, style)
					if settings.show_pickup_color then
						style.color = bg_color
					end
					return f(content, style)
				end
			end
		end
	end
end)

mod:hook_safe("HudElementTeamPlayerPanel", "_update_player_features", function (self, dt, t, player, ui_renderer)
	if not settings.show_team_panel_color then
		return
	end
	local syringe_icon_widget = self._widgets_by_name.pocketable_small
	local extensions = self:_player_extensions(player)
	local visual_loadout_extension = extensions and extensions.visual_loadout

	if syringe_icon_widget then
		local slot_name = "slot_pocketable_small"
		if visual_loadout_extension then
			local item = visual_loadout_extension:item_from_slot(slot_name)
			if item and item.weapon_template then
				local _, _, color = get_stimm_colors(item.weapon_template)
				if syringe_icon_widget.style and syringe_icon_widget.style.texture then
					if color then
						syringe_icon_widget.style.texture.color = color
					else
						syringe_icon_widget.style.texture.color = UIHudSettings.color_tint_main_1
					end
				end
			end
		end
	end
end)

mod:hook_safe("HudElementPlayerWeapon", "update", function (self, dt, t, ui_renderer)
	if not settings.show_self_weapon_color then
		return
	end
	if self._slot_name == "slot_pocketable_small" then
		local icon_widget = self._widgets_by_name.icon
		local background_widget = self._widgets_by_name.background

		if icon_widget and background_widget and self._data and self._data.item and self._data.item.weapon_template then
			local color, _, light_color = get_stimm_colors(self._data.item.weapon_template)
			if color and light_color and background_widget.style then
				icon_widget.style = icon_widget.style or {}
				background_widget.style = background_widget.style or {}

				if icon_widget.style.icon then
					icon_widget.style.icon.default_color = color
					icon_widget.style.icon.highlight_color = light_color
				end
				if background_widget.style.line then
					background_widget.style.line.default_color = color
					background_widget.style.line.highlight_color = light_color
				end
				if background_widget.style.background then
					-- HACK: why it's bgr instead of rgb?
					background_widget.style.background.color = argb_to_abgr(color)
				end
			end
		end
	end
end)
