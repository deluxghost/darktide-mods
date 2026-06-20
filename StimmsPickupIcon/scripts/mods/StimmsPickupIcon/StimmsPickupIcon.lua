local mod = get_mod("StimmsPickupIcon")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local settings = mod:persistent_table("settings")
local recolor_mod = nil

local STIMM_COLORS = {
	syringe_corruption_pocketable = { 255, 38, 205, 26 },
	syringe_ability_boost_pocketable = { 255, 230, 192, 13 },
	syringe_power_boost_pocketable = { 255, 205, 51, 26 },
	syringe_speed_boost_pocketable = { 255, 0, 127, 218 },
	syringe_broker_pocketable = { 255, 208, 69, 255 },
}
local STIMM_COOLDOWN_COLOR = { 255, 128, 128, 128 }

local function clone_color(color)
	return color and { color[1], color[2], color[3], color[4] }
end

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

local get_stimm_colors = function (stimm_name, override_color)
	local main_color = clone_color(override_color
		or settings.use_recolor_stimms_mod
		and recolor_mod
		and recolor_mod:is_enabled()
		and recolor_mod.get_stimm_argb_255
		and recolor_mod.get_stimm_argb_255(stimm_name)
		or STIMM_COLORS[stimm_name])
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

local function is_stimm_on_cooldown(stimm_name, ability_extension)
	if not stimm_name or not ability_extension or not string.starts_with(stimm_name, "syringe_") then
		return false
	end

	local equipped_abilities = ability_extension:equipped_abilities()
	local pocketable_ability = equipped_abilities and equipped_abilities["pocketable_ability"]

	return pocketable_ability
		and pocketable_ability.inventory_item_name == "content/items/pocketable/" .. stimm_name
		and ability_extension:max_ability_charges("pocketable_ability") > 0
		and ability_extension:remaining_ability_charges("pocketable_ability") <= 0
end

local function set_color(target, source, include_alpha)
	if not target or not source then
		return false
	end

	local changed = target[2] ~= source[2]
		or target[3] ~= source[3]
		or target[4] ~= source[4]
	if include_alpha and target[1] ~= source[1] then
		target[1] = source[1]
		changed = true
	end
	if changed then
		target[2] = source[2]
		target[3] = source[3]
		target[4] = source[4]
	end

	return changed
end

local function update_weapon_style_colors(icon_widget, background_widget, color, trim_color, light_color, progress)
	local icon_style = icon_widget.style.icon
	local icon_cooldown_done_style = icon_widget.style.icon_cooldown_done
	local background_style = background_widget.style
	local line_style = background_style.line
	local changed = false

	local function apply(target, source, include_alpha)
		changed = set_color(target, source, include_alpha) or changed
	end

	if icon_style then
		apply(icon_style.default_color, color)
		apply(icon_style.highlight_color, light_color)
	end
	if line_style then
		apply(line_style.default_color, color)
		apply(line_style.highlight_color, light_color)
	end
	if background_style.background then
		apply(background_style.background.color, color, true)
	end
	if icon_cooldown_done_style then
		apply(icon_cooldown_done_style.color, light_color)
	end
	if background_style.cooldown_done_glow then
		apply(background_style.cooldown_done_glow.color, light_color)
	end
	if background_style.background_stripe_wide then
		apply(background_style.background_stripe_wide.active_color, light_color)
		apply(background_style.background_stripe_wide.color, light_color)
	end
	if background_style.background_stripe_thin_left then
		apply(background_style.background_stripe_thin_left.active_color, trim_color)
		apply(background_style.background_stripe_thin_left.color, trim_color)
	end
	if background_style.background_stripe_thin_right then
		apply(background_style.background_stripe_thin_right.active_color, color)
		apply(background_style.background_stripe_thin_right.color, color)
	end
	if progress == 1 then
		apply(icon_style and icon_style.color, light_color)
		apply(line_style and line_style.color, light_color)
	elseif progress == 0 then
		apply(icon_style and icon_style.color, color)
		apply(line_style and line_style.color, color)
	end

	return changed
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
				local cooldown_color = is_stimm_on_cooldown(item.weapon_template, extensions and extensions.ability) and STIMM_COOLDOWN_COLOR
				local _, _, color = get_stimm_colors(item.weapon_template, cooldown_color)
				if syringe_icon_widget.style and syringe_icon_widget.style.texture then
					if color then
						syringe_icon_widget.style.texture.color = color
					else
						syringe_icon_widget.style.texture.color = UIHudSettings.color_tint_main_1
					end
					syringe_icon_widget.dirty = true
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
			local weapon_template = self._data.item.weapon_template
			local cooldown_color = is_stimm_on_cooldown(weapon_template, self._ability_extension) and STIMM_COOLDOWN_COLOR
			local color, trim_color, light_color = get_stimm_colors(weapon_template, cooldown_color)
			if color and trim_color and light_color and background_widget.style then
				icon_widget.style = icon_widget.style or {}
				background_widget.style = background_widget.style or {}
				local progress = self._wield_anim_progress or 0

				if update_weapon_style_colors(icon_widget, background_widget, color, trim_color, light_color, progress) then
					self:set_wield_anim_progress(progress, ui_renderer)
					icon_widget.dirty = true
					background_widget.dirty = true
				end
			end
		end
	end
end)
