local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Motion = mod.load_module("physics/motion")
local MovingObstacles = {}
local QUERY_MARGIN = 1

local function vehicle_part (vehicles, unit)
	for _, vehicle in pairs(vehicles) do
		if Collision.contains_unit(vehicle, unit) then
			return true
		end
	end
	return false
end

MovingObstacles.update = function (vehicle, vehicles)
	local previous = vehicle.moving_contacts or {}
	local current = {}
	for _, actor in ipairs(Motion.nearby(vehicle, QUERY_MARGIN)) do
		local unit = Actor.unit(actor)
		local data = ScriptUnit.has_extension(unit, "unit_data_system")
		local breed = data and data:breed()
		if Actor.is_kinematic(actor) and not breed and not vehicle_part(vehicles, unit) then
			local pose = Matrix4x4.from_quaternion_position(Actor.rotation(actor), Actor.position(actor))
			local old = previous[actor]
			if old then
				Motion.push_from_actor(vehicle, actor, old:unbox(), pose, vehicles)
			end
			current[actor] = Matrix4x4Box(pose)
		end
	end
	vehicle.moving_contacts = current
end

return MovingObstacles
