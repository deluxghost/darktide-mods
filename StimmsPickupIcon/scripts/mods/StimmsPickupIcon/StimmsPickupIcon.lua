local mod = get_mod("StimmsPickupIcon")

mod:hook_safe(CLASS.HudElementWorldMarkers, "event_add_world_marker_unit", function (self, marker_type, unit, callback, data)
	if not unit then
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
	local color, bg_color = nil, nil
	if pickup_type == "syringe_corruption_pocketable" then
		bg_color = { 255, 38, 205, 26 }
		color = { 255, 0, 76, 0 }
	elseif pickup_type == "syringe_ability_boost_pocketable" then
		bg_color = { 255, 230, 192, 13 }
		color = { 255, 95, 77, 0 }
	elseif pickup_type == "syringe_power_boost_pocketable" then
		bg_color = { 255, 205, 51, 26 }
		color = { 255, 100, 0, 15 }
	elseif pickup_type == "syringe_speed_boost_pocketable" then
		bg_color = { 255, 0, 127, 218 }
		color = { 255, 0, 0, 77 }
	end
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
