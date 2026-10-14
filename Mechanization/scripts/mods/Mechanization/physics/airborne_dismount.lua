local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Surfaces = mod.load_module("physics/surfaces")
local AirborneDismount = {}
local EXIT_MARGIN = 0.3

AirborneDismount.plan = function (vehicle, occupants, vehicles, ground_plan, removing)
	local origin = vehicle.position:unbox()
	local rotation = Unit.world_rotation(vehicle.unit, 1)
	local center, half = vehicle.type.controller.bounds(vehicle)
	local world_center = origin + Quaternion.rotate(rotation, center)
	local right, forward, up = Quaternion.right(rotation), Quaternion.forward(rotation), Quaternion.up(rotation)
	local bottom = world_center.z - math.abs(right.z) * half.x - math.abs(forward.z) * half.y - math.abs(up.z) * half.z
	local ground = Surfaces.ground(vehicle.world, Vector3(world_center.x, world_center.y, bottom), EXIT_MARGIN, vehicle.type.dismount.near_ground, 0.55)
	if ground and not removing then
		local positions = ground_plan(vehicle, occupants, vehicles, ground)
		if positions then
			return positions, {}
		end
		return
	end
	local positions, drops = {}, {}
	for index, occupant in ipairs(occupants) do
		if ALIVE[occupant.unit] then
			local radius, height = Collision.character_size(occupant.unit)
			local point = Vector3(world_center.x, world_center.y, bottom - height - EXIT_MARGIN)
			point = point + Vector3.flat(right) * ((index - (#occupants + 1) * 0.5) * (radius * 2 + EXIT_MARGIN))
			if ground then
				point.z = math.max(point.z, ground.z)
			end
			if not Unit.mover_fits_at(occupant.unit, "default", point) then
				if not removing then
					return
				end
				-- Removing the aircraft also makes its cabin available for forced evacuation.
				point = world_center
			end
			if not removing then
				for _, other in pairs(vehicles) do
					if other ~= vehicle and not Collision.outside(other, point, radius, height) then
						return
					end
				end
			end
			local peer = occupant.peer or occupant.unit
			positions[peer] = { point.x, point.y, point.z }
			drops[peer] = vehicle.type.dismount.descent_speed
		end
	end
	return positions, drops
end

return AirborneDismount
