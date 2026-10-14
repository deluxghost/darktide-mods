local Surfaces = {}

Surfaces.is_ground = function (actor)
	return Actor.is_static(actor) or not not ScriptUnit.has_extension(Actor.unit(actor), "moveable_platform_system")
end

Surfaces.ground = function (world, position, above, below, min_normal)
	local hits = PhysicsWorld.raycast(
		World.physics_world(world), position + Vector3.up() * above, Vector3.down(), above + below,
		"all", "types", "both", "collision_filter", "filter_player_mover"
	)
	local point, normal, actor
	for _, hit in ipairs(hits or {}) do
		if Surfaces.is_ground(hit[4]) and hit[3].z >= min_normal and (not point or hit[1].z > point.z) then
			point, normal, actor = hit[1], hit[3], hit[4]
		end
	end
	return point, normal, actor
end

Surfaces.relative = function (actor, position)
	local unit = Actor.unit(actor)
	local is_level, id, level_hash = Managers.state.unit_spawner:game_object_id_or_level_index(unit)
	local node = Actor.node(actor)
	local relative = Matrix4x4.transform(Matrix4x4.inverse(Unit.world_pose(unit, node)), position)
	return { id = id, level = is_level, level_hash = level_hash, node = node, p = { relative.x, relative.y, relative.z } }
end

Surfaces.frame = function (world, position)
	local ground, _, actor = Surfaces.ground(world, position, 0.25, 0.25, 0.55)
	local unit = actor and Actor.unit(actor)
	if unit and ScriptUnit.has_extension(unit, "moveable_platform_system") then
		return Surfaces.relative(actor, ground)
	end
end

Surfaces.pose = function (frame)
	local unit = Managers.state.unit_spawner:unit(frame.id, frame.level, frame.level_hash)
	assert(unit and Unit.alive(unit), "Moving platform no longer exists")
	assert(frame.node <= Unit.num_scene_graph_items(unit), "Invalid moving platform node")
	return Unit.world_pose(unit, frame.node)
end

Surfaces.position = function (frame)
	return Matrix4x4.transform(Surfaces.pose(frame), Vector3(unpack(frame.p)))
end

Surfaces.validate = function (frame, finite)
	assert(type(frame) == "table", "Invalid platform frame")
	assert(finite(frame.id) and frame.id >= 0 and frame.id % 1 == 0, "Invalid platform id")
	assert(type(frame.level) == "boolean", "Invalid platform type")
	assert(finite(frame.level_hash) and frame.level_hash >= 0 and frame.level_hash % 1 == 0, "Invalid platform level hash")
	assert(finite(frame.node) and frame.node > 0 and frame.node % 1 == 0, "Invalid platform node")
	assert(type(frame.p) == "table" and #frame.p == 3, "Invalid platform position")
	for index = 1, 3 do
		assert(finite(frame.p[index]), "Invalid platform coordinate")
	end
end

return Surfaces
