local mod = get_mod("Mechanization")
local Terrain = mod.load_module("physics/wheel_terrain")
local Collision = mod.load_module("physics/collision")
local Motion = mod.load_module("physics/motion")
local Chassis = {}

Chassis.capture_actors = function (unit, origin, rotation)
	local actors = {}
	for index = 1, Unit.num_actors(unit) do
		local actor = Unit.actor(unit, index)
		actors[index] = {
			actor = actor,
			position = Vector3Box(Quaternion.rotate(rotation, Actor.position(actor) - origin)),
			rotation = QuaternionBox(Quaternion.multiply(rotation, Actor.rotation(actor))),
		}
	end
	return actors
end

Chassis.pose_actors = function (actors, position, rotation)
	-- Static prop actors do not follow their scene graph after spawning.
	for _, entry in ipairs(actors) do
		Actor.teleport_position(entry.actor, position + Quaternion.rotate(rotation, entry.position:unbox()))
		Actor.teleport_rotation(entry.actor, Quaternion.multiply(rotation, entry.rotation:unbox()))
	end
end

Chassis.can_spawn = function (v, vehicles, ignored_units)
	local position = v.position:unbox()
	local normal = Terrain.support(v, position, v.yaw)
	if not normal then
		return false
	end
	local rotation = Terrain.rotation(v.yaw, normal)
	local height = Terrain.height(v, position, rotation)
	if not height then
		return false
	end
	position.z = height
	v.position:store(position)
	v.normal:store(normal)
	v.type.controller.pose(v)
	if not Collision.clear_players(v, position, rotation, ignored_units) or not Collision.clear_vehicles(v, position, rotation, vehicles) then
		return false
	end
	for _, filter in ipairs({ "filter_player_mover", "filter_player_character_shooting_raycast" }) do
		for _, actor in ipairs(Motion.overlap(v, position, rotation, filter)) do
			local unit = Actor.unit(actor)
			local relevant = filter == "filter_player_mover" or ScriptUnit.has_extension(unit, "health_system")
			if relevant and not Collision.contains_unit(v, unit) and not ignored_units[unit] then
				return false
			end
		end
	end
	return true
end

Chassis.animate = function (v, dt)
	local settings = v.type.settings
	local rotation = Terrain.rotation(v.yaw, v.normal:unbox())
	local heights = Terrain.contacts(v, v.position:unbox(), rotation)
	local response = 1 - math.exp(-(settings.wheel_response or settings.suspension_response) * dt)
	for index, wheel in ipairs(v.wheels) do
		wheel.phase = (wheel.phase - v.wheel_speed * dt / settings.wheel_radius) % (math.pi * 2)
		local height = heights[index]
		local target = height and math.clamp((height - v.position:unbox().z) / Quaternion.up(rotation).z, -settings.suspension_travel, settings.suspension_travel) or -settings.suspension_travel
		wheel.compression = math.lerp(wheel.compression, target, response)
	end
end

return Chassis
