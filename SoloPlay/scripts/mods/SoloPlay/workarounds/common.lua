local mod = get_mod("SoloPlay")

-- when a colored outline is adding to an invalid unit, the game crashes
mod:hook(Unit, "set_vector3_for_material", function(func, unit, ...)
	if not Unit.alive(unit) then
		return
	end
	func(unit, ...)
end)

-- fix arbites execution order keystone crash
mod:hook_require("scripts/settings/buff/buff_templates", function (templates)
	local keystone = templates.adamant_execution_order
	if not keystone.__soloplay_modified then
		local orig_update_func = keystone.update_func
		keystone.update_func = function (template_data, template_context, dt, t)
			--------
			-- local player_unit = template_context.unit
			-- local player_rotation = template_data.first_person_component.rotation
			-- local player_horizontal_look_direction = Vector3.normalize(Vector3.flat(Quaternion.forward(player_rotation)))
			-- local player_position = POSITION_LOOKUP[player_unit]
			-- local broadphase_distance = template_data.distance
			--------
			for marked_unit, t in pairs(template_data.targets) do
				if ALIVE[marked_unit] and not BLACKBOARDS[marked_unit] then
					template_data.targets[marked_unit] = nil
					--------
					-- local marked_unit_position = POSITION_LOOKUP[marked_unit]
					-- local distance_sq = Vector3.distance_squared(player_position, marked_unit_position)
					-- local check_distance = broadphase_distance * broadphase_distance
					-- if check_distance < distance_sq then
					-- 	local direction_to_player = Vector3.normalize(marked_unit_position - player_position)
					-- 	local dot = Vector3.dot(player_horizontal_look_direction, direction_to_player)
					-- 	if dot < 0 then
					-- 		mod:notify("arbites keystone workaround triggered")
					-- 	end
					-- end
					--------
				end
			end
			orig_update_func(template_data, template_context, dt, t)
		end
		keystone.__soloplay_modified = true
	end
end)
