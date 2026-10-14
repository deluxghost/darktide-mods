local mod = get_mod("Mechanization")
local Motion = mod.load_module("physics/motion")
local Surfaces = mod.load_module("physics/surfaces")
local MovingGround = {}

local function pose (actor)
	return Matrix4x4.from_quaternion_position(Actor.rotation(actor), Actor.position(actor))
end

MovingGround.capture = function (vehicle)
	vehicle.ground_support = nil
	local support_height = vehicle.type.controller.support_height
	if not support_height or vehicle.airborne then
		return
	end
	local position = vehicle.position:unbox()
	local height, actor = support_height(vehicle, position, Unit.world_rotation(vehicle.unit, 1))
	if not height or math.abs(position.z - height) > vehicle.type.settings.suspension_travel then
		return
	end
	local unit = actor and Actor.unit(actor)
	if unit and ScriptUnit.has_extension(unit, "moveable_platform_system") then
		vehicle.ground_support = { unit = unit, actor = actor, pose = Matrix4x4Box(pose(actor)) }
	end
end

MovingGround.carry = function (vehicle, vehicles)
	local support = vehicle.ground_support
	if not support or not Unit.alive(support.unit) then
		vehicle.ground_support = nil
		return
	end
	local previous = support.pose:unbox()
	local current = pose(support.actor)
	local relative = Matrix4x4.transform(Matrix4x4.inverse(previous), vehicle.position:unbox())
	local destination = Matrix4x4.transform(current, relative)
	local rotation = Unit.world_rotation(vehicle.unit, 1)
	local delta = Quaternion.multiply(Matrix4x4.rotation(current), Quaternion.inverse(Matrix4x4.rotation(previous)))
	local position = Motion.translate(vehicle, destination, rotation, vehicles)
	vehicle.position:store(position)
	vehicle.yaw = vehicle.yaw + Quaternion.yaw(delta)
	vehicle.normal:store(Quaternion.rotate(delta, vehicle.normal:unbox()))
	vehicle.horizontal_velocity:store(Quaternion.rotate(delta, vehicle.horizontal_velocity:unbox()))
	support.pose:store(current)
end

MovingGround.snapshot = function (vehicle)
	local support = vehicle.ground_support
	if not support then
		return false
	end
	local frame = Surfaces.relative(support.actor, vehicle.position:unbox())
	local rotation = Matrix4x4.rotation(Surfaces.pose(frame))
	local normal = Quaternion.rotate(Quaternion.inverse(rotation), vehicle.normal:unbox())
	frame.yaw = vehicle.yaw - Quaternion.yaw(rotation)
	frame.normal = { normal.x, normal.y, normal.z }
	return frame
end

return MovingGround
