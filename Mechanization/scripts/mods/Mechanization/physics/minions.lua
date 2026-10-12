local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Blackboard = require("scripts/extension_systems/blackboard/utilities/blackboard")
local Minions = {}
local APPROACH_MARGIN = 5

local function nearby (vehicles)
	local system = Managers.state.extension:system("broadphase_system")
	local positions = {}
	for _, vehicle in pairs(vehicles) do
		local center, half = vehicle.type.controller.bounds(vehicle)
		local units = {}
		local radius = Vector3.length(center) + Vector3.length(half) + APPROACH_MARGIN
		local count = system.broadphase.query(system.broadphase, vehicle.position:unbox(), radius, units, { "villains" })
		for index = 1, count do
			local unit = units[index]
			if HEALTH_ALIVE[unit] then
				positions[unit] = Vector3Box(Unit.world_position(unit, 1))
			end
		end
	end
	return positions
end

Minions.constrain = function (session, positions, dt)
	for unit, origin in pairs(positions) do
		if HEALTH_ALIVE[unit] then
			local position = Unit.world_position(unit, 1)
			local destination = Collision.move(session.vehicles, unit, origin:unbox(), position)
			destination = Collision.push(session.vehicles, unit, destination, dt)
			if not Vector3.equal(destination, position) then
				local locomotion = ScriptUnit.extension(unit, "locomotion_system")
				locomotion:teleport_to(destination, Unit.world_rotation(unit, 1))
			end
		end
	end
end

Minions.target = function (session, unit)
	local blackboard = BLACKBOARDS[unit]
	local perception = blackboard.perception
	local vehicle, occupant = session.for_unit(perception.target_unit)
	if not occupant or not occupant.seat.protected then
		return
	end
	local position = Unit.world_position(unit, 1)
	local breed = ScriptUnit.extension(unit, "unit_data_system"):breed()
	local eye = position + Vector3(0, 0, breed.base_height * 0.5)
	local target = Collision.closest_point(vehicle, eye)
	local component = Blackboard.write_component(blackboard, "perception")
	component.target_distance = Vector3.length(Vector3.flat(position - target))
	component.target_distance_z = math.abs(position.z - target.z)
	component.target_position:store(target)
	local direction, length = Vector3.direction_length(target - eye)
	local hit, _, _, _, actor = PhysicsWorld.raycast(
		World.physics_world(vehicle.world), eye, direction, length,
		"closest", "types", "both", "collision_filter", breed.line_of_sight_collision_filter
	)
	component.has_line_of_sight = not hit or Collision.contains_unit(vehicle, Actor.unit(actor))
	local extension = ScriptUnit.extension(unit, "perception_system")
	extension._line_of_sight_lookup[perception.target_unit] = component.has_line_of_sight
end

Minions.install = function (session)
	mod:hook(CLASS.LocomotionSystem, "update", function (func, self, context, dt, ...)
		if not self._is_server or not next(session.vehicles) then
			return func(self, context, dt, ...)
		end
		local positions = nearby(session.vehicles)
		func(self, context, dt, ...)
		-- Walking AI follows the navmesh directly and therefore needs the same swept hull boundary as players.
		Minions.constrain(session, positions, dt)
	end)
	mod:hook(CLASS.AiBrain, "update", function (func, self, unit, ...)
		if next(session.vehicles) then
			Minions.target(session, unit)
		end
		return func(self, unit, ...)
	end)
end

return Minions
