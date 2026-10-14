local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Platform = mod.load_module("players/platform")
local Movement = {}

local function pose (session, vehicle, occupant)
	local position, rotation = session.occupants.pose(vehicle, occupant)
	Unit.set_local_position(occupant.unit, 1, position)
	Unit.set_local_rotation(occupant.unit, 1, rotation)
	World.update_unit_and_children(vehicle.world, occupant.unit)
	return position
end

local function update_husk (self, occupant, dt)
	local speed = occupant.platform and Vector3.length(occupant.platform.velocity:unbox()) or 0
	self._move_speed, self._move_speed_squared = speed, speed * speed
	if occupant.platform then
		local variable = self._animation_extension:anim_variable_id(self._move_speed_variable)
		local previous = Unit.animation_get_variable(occupant.unit, variable)
		Unit.animation_set_variable(occupant.unit, variable, math.lerp(previous, math.min(speed, 19.9), math.min(dt * 10, 1)))
	end
	local first = self._first_person_extension
	if first:is_in_first_person_mode() then
		first:update_unit_position_and_rotation(Unit.world_position(occupant.unit, 1), first:spectated_aim_rotation(), true)
	end
end

Movement.install = function (session)
	local posing_occupant
	mod:hook(CLASS.MoveablePlatformExtension, "movement_since_last_fixed_update", function (func, self)
		-- The rendered vehicle transform already includes its supporting platform's movement.
		if posing_occupant then
			return Vector3.zero()
		end
		return func(self)
	end)
	mod:hook(CLASS.PlayerUnitLocomotionExtension, "_update_movement", function (func, self, unit, dt, t, locomotion, steering, inair)
		local vehicle, occupant = session.for_unit(unit)
		if occupant and occupant.platform then
			Platform.simulate(vehicle, occupant, self, dt, t)
			return
		end
		local origin = locomotion.position
		func(self, unit, dt, t, locomotion, steering, inair)
		local destination = vehicle and locomotion.position or Collision.push(session.vehicles, unit, locomotion.position, dt)
		local position = vehicle and session.occupants.pose(vehicle, occupant) or Collision.move(session.vehicles, unit, origin, destination)
		if not vehicle and Vector3.equal(position, locomotion.position) then
			return
		end
		Mover.set_position(Unit.mover(unit), position)
		locomotion.position = position
		self._old_position:store(position)
		self._latest_simulated_position:store(position)
		if vehicle then
			locomotion.velocity_current = Vector3.zero()
			inair.fell_from_height = position.z
		end
	end)
	mod:hook(CLASS.PlayerUnitLocomotionExtension, "post_update", function (func, self, unit, dt, t)
		local vehicle, occupant = session.for_unit(unit)
		if not occupant then
			return func(self, unit, dt, t)
		end
		Platform.prepare(occupant, t)
		local position = pose(session, vehicle, occupant)
		-- Pose before native first-person and held-weapon updates, using the same
		-- rendered vehicle transform for every part of the passenger.
		self._old_position:store(position)
		self._latest_simulated_position:store(position)
		local first = ScriptUnit.extension(unit, "unit_data_system"):write_component("first_person")
		first.position = position + Vector3.up() * first.height
		posing_occupant = occupant
		func(self, unit, dt, t)
		posing_occupant = nil
	end)
	mod:hook(CLASS.PlayerHuskLocomotionExtension, "post_update", function (func, self, unit, dt, t)
		local vehicle, occupant = session.for_unit(unit)
		if not occupant then
			return func(self, unit, dt, t)
		end
		-- Native world-coordinate interpolation cannot also move an attached passenger.
		-- Their relative platform position is interpolated with the vehicle snapshot.
		pose(session, vehicle, occupant)
		update_husk(self, occupant, dt)
		self._visual_loadout_extension:update_unit_position(unit, dt, t)
	end)
end

return Movement
