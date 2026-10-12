local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Blackboard = require("scripts/extension_systems/blackboard/utilities/blackboard")
local Minions = {}
local APPROACH_MARGIN = 5

local function exposed_vehicle (session, target)
	local vehicle, occupant = session.for_unit(target)
	if occupant and not occupant.seat.protected then
		return vehicle
	end
end

local function exposed_attack_vehicle (session, unit)
	local blackboard = BLACKBOARDS[unit]
	local vehicle = exposed_vehicle(session, blackboard.perception.target_unit)
	if not vehicle then
		return
	end
	local behavior = ScriptUnit.extension(unit, "behavior_system")
	local brain = behavior:brain()
	local node = brain._running_leaf_node
	if not brain:running_action() then
		return
	end
	-- Disabling attacks must reach the exposed rider before the seat is released.
	if node.__class_name == "BtChaosHoundLeapAction" or node.__class_name == "BtMutantChargerChargeAction" then
		return vehicle
	end
end

local function disable_hull_queries (vehicle)
	local actors = {}
	for unit in pairs(vehicle.parts) do
		for index = 1, Unit.num_actors(unit) do
			local actor = Unit.actor(unit, index)
			if Actor.is_scene_query_enabled(actor) then
				actors[#actors + 1] = { unit = unit, actor = actor }
				Actor.set_scene_query_enabled(actor, false)
			end
		end
	end
	return actors
end

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
			local attack_vehicle = exposed_attack_vehicle(session, unit)
			local destination = Collision.move(session.vehicles, unit, origin:unbox(), position, attack_vehicle)
			destination = Collision.push(session.vehicles, unit, destination, dt, attack_vehicle)
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
	for _, class_name in ipairs({ "BtChaosHoundApproachAction", "BtChaosHoundLeapAction", "BtMutantChargerChargeAction" }) do
		mod:hook(class_name, "run", function (func, self, unit, breed, blackboard, ...)
			local vehicle = exposed_vehicle(session, blackboard.perception.target_unit)
			if not vehicle then
				return func(self, unit, breed, blackboard, ...)
			end
			-- Native disabler sweeps must reach the rider instead of hitting the seat's prop actor.
			local actors = disable_hull_queries(vehicle)
			local result, evaluate, rate = func(self, unit, breed, blackboard, ...)
			for _, entry in ipairs(actors) do
				if Unit.alive(entry.unit) then
					Actor.set_scene_query_enabled(entry.actor, true)
				end
			end
			return result, evaluate, rate
		end)
	end
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
