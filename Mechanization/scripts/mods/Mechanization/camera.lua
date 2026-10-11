local View = {}

View.pose = function (v, yaw, pitch)
	local settings = v.type.camera
	local rotation = Quaternion.from_yaw_pitch_roll(yaw, math.clamp(pitch, settings.min_pitch, settings.max_pitch), 0)
	local pivot = v.position:unbox() + Vector3(0, 0, settings.height)
	local travel = -Quaternion.forward(rotation) * settings.distance + Quaternion.right(rotation) * settings.offset
	local distance = Vector3.length(travel)
	local hits = PhysicsWorld.raycast(
		World.physics_world(v.world), pivot, Vector3.normalize(travel), distance,
		"all", "collision_filter", "filter_player_mover"
	)
	local nearest = distance
	for _, hit in ipairs(hits or {}) do
		if Actor.unit(hit[4]) ~= v.unit and hit[2] < nearest then
			nearest = math.max(0, hit[2] - 0.4)
		end
	end
	local camera_position = pivot + Vector3.normalize(travel) * nearest

	return camera_position, rotation
end

View.target = function (v, yaw, pitch, range)
	local position, rotation = View.pose(v, yaw, pitch)
	local direction = Quaternion.forward(rotation)
	local hits = PhysicsWorld.raycast(
		World.physics_world(v.world), position, direction, range,
		"all", "collision_filter", "filter_player_character_shooting_raycast"
	)
	local nearest = range
	local target = position + direction * nearest

	for _, hit in ipairs(hits or {}) do
		local unit = Actor.unit(hit[4])
		local occupant_hit = false
		for _, occupant in pairs(v.occupants) do
			occupant_hit = occupant_hit or occupant.unit == unit
		end
		if unit ~= v.unit and not occupant_hit and hit[2] < nearest then
			nearest = hit[2]
			target = hit[1]
		end
	end

	return target
end

View.direction = function (v, yaw, pitch, pivot, range)
	local target = View.target(v, yaw, pitch, range)
	local _, rotation = View.pose(v, yaw, pitch)
	local forward = Quaternion.forward(rotation)
	local direction = target - pivot
	-- A camera obstruction behind the gun cannot represent a backward aiming intent.
	if Vector3.dot(direction, forward) <= 0 then
		return forward
	end
	return Vector3.normalize(direction)
end

return View
