local mod = get_mod("StimmsPickupIcon")

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

mod.on_enabled = function()
	settings.use_recolor_stimms_mod = mod:get("use_recolor_stimms_mod")
end

mod.on_setting_changed = function(setting_id)
	settings.use_recolor_stimms_mod = mod:get("use_recolor_stimms_mod")
end

local _get_stimm_colors = function (stimm_name)
	local main_color = settings.use_recolor_stimms_mod
		and recolor_mod
		and recolor_mod:is_enabled()
		and recolor_mod.get_stimm_argb_255
		and recolor_mod.get_stimm_argb_255(stimm_name)
		or STIMM_COLORS[stimm_name]
	if not main_color then
		return nil, nil
	end

	local color_offset = (main_color[2] + main_color[3] + main_color[4]) / 3.0 > 64 and 0 or 128
	local math_floor = math.floor
	local trim_color = { 255,
		math_floor(0.4 * main_color[2] + color_offset),
		math_floor(0.4 * main_color[3] + color_offset),
		math_floor(0.4 * main_color[4] + color_offset),
	}
	return trim_color, main_color
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
	local color, bg_color = _get_stimm_colors(pickup_type)
	if color and bg_color then
		for _, pass in ipairs(marker.widget.passes) do
			if pass.value_id == "icon" then
				local f = pass.visibility_function
				pass.visibility_function = function (content, style)
					style.color = color
					return f(content, style)
				end
			end
			if pass.value_id == "background" then
				local f = pass.visibility_function
				pass.visibility_function = function (content, style)
					style.color = bg_color
					return f(content, style)
				end
			end
		end
	end
end)
