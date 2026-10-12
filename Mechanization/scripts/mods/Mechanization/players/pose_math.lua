local PoseMath = {}
local REACH_MARGIN = 0.001
local AXIS_EPSILON = 0.00001

PoseMath.set_rotation = function (world, unit, node, rotation)
	local parent = Unit.scene_graph_parent(unit, node)
	local local_rotation = Quaternion.multiply(Quaternion.inverse(Unit.world_rotation(unit, parent)), rotation)
	Unit.set_local_rotation(unit, node, local_rotation)
	World.update_unit_and_children(world, unit)
end

PoseMath.set_position = function (world, unit, node, position)
	local parent = Unit.scene_graph_parent(unit, node)
	local local_position = Matrix4x4.transform(Matrix4x4.inverse(Unit.world_pose(unit, parent)), position)
	Unit.set_local_position(unit, node, local_position)
	World.update_unit_and_children(world, unit)
end

local function point_bone (world, unit, node, from, to)
	local a, b = Vector3.normalize(from), Vector3.normalize(to)
	local axis = Vector3.cross(a, b)
	local length = Vector3.length(axis)
	local cosine = math.clamp(Vector3.dot(a, b), -1, 1)
	if length < AXIS_EPSILON then
		if cosine > 0 then
			return
		end
		local perpendicular = math.abs(a.z) < 0.9 and Vector3.up() or Vector3.right()
		axis = Vector3.cross(a, perpendicular)
		length = Vector3.length(axis)
	end
	local delta = Quaternion.axis_angle(axis / length, math.acos(cosine))
	PoseMath.set_rotation(world, unit, node, Quaternion.multiply(delta, Unit.world_rotation(unit, node)))
end

PoseMath.limb = function (world, unit, limb, target, bend)
	local origin = Unit.world_position(unit, limb.upper)
	local joint = Unit.world_position(unit, limb.lower)
	local end_position = Unit.world_position(unit, limb.tip)
	local upper_length = Vector3.distance(origin, joint)
	local lower_length = Vector3.distance(joint, end_position)
	local direction, distance = Vector3.direction_length(target - origin)
	distance = math.clamp(distance, math.abs(upper_length - lower_length) + REACH_MARGIN, upper_length + lower_length - REACH_MARGIN)
	local along = (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2 * distance)
	local height = math.sqrt(math.max(0, upper_length * upper_length - along * along))
	bend = Vector3.normalize(bend - direction * Vector3.dot(bend, direction))
	local desired_joint = origin + direction * along + bend * height
	point_bone(world, unit, limb.upper, joint - origin, desired_joint - origin)
	joint = Unit.world_position(unit, limb.lower)
	end_position = Unit.world_position(unit, limb.tip)
	point_bone(world, unit, limb.lower, end_position - joint, target - joint)
end

return PoseMath
