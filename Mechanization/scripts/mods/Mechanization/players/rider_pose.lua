local mod = get_mod("Mechanization")
local PoseMath = mod.load_module("players/pose_math")
local RiderPose = {}
local references = {}
local FINGER_CURL = { math.rad(60), math.rad(75), math.rad(55) }

local function reference_pose (world, resource)
	if references[resource] then
		return references[resource]
	end
	-- Read the rig's rest pose before animation evaluation. Cosmetic meshes use this same rig.
	local unit = World.spawn_unit_ex(world, resource, nil, Vector3.zero(), Quaternion.identity())
	Unit.disable_animation_state_machine(unit)
	local reference = { bones = {}, count = Unit.num_scene_graph_items(unit) }
	for node = 2, reference.count do
		reference.bones[node] = {
			position = Vector3Box(Unit.local_position(unit, node)),
			rotation = QuaternionBox(Unit.local_rotation(unit, node)),
		}
	end
	reference.hips = QuaternionBox(Unit.world_rotation(unit, Unit.node(unit, "j_hips")))
	reference.spine = QuaternionBox(Unit.world_rotation(unit, Unit.node(unit, "j_spine")))
	reference.neck = QuaternionBox(Unit.world_rotation(unit, Unit.node(unit, "j_neck")))
	reference.feet = {}
	for _, side in ipairs({ "left", "right" }) do
		reference.feet[side] = QuaternionBox(Unit.world_rotation(unit, Unit.node(unit, "j_" .. side .. "foot")))
	end
	World.destroy_unit(world, unit)
	references[resource] = reference
	return reference
end

local function limb_nodes (unit, side, upper, lower, tip)
	return {
		upper = Unit.node(unit, "j_" .. side .. upper),
		lower = Unit.node(unit, "j_" .. side .. lower),
		tip = Unit.node(unit, "j_" .. side .. tip),
	}
end

local function reset_bones (unit, reference)
	for node, bone in pairs(reference.bones) do
		Unit.set_local_position(unit, node, bone.position:unbox())
		Unit.set_local_rotation(unit, node, bone.rotation:unbox())
	end
end

local function close_hand (unit, hand)
	for _, finger in ipairs(hand.fingers) do
		Unit.set_local_rotation(unit, finger.node, finger.rotation:unbox())
	end
end

local function grip_offset (unit, side, hand)
	local prefix = "j_" .. side .. "handmiddle"
	local a = Unit.world_position(unit, Unit.node(unit, prefix .. "1"))
	local b = Unit.world_position(unit, Unit.node(unit, prefix .. "2")) - a
	local c = Unit.world_position(unit, Unit.node(unit, prefix .. "3")) - a
	local normal = Vector3.cross(b, c)
	-- The curled middle finger defines the grasp center, including the character's scale.
	local numerator = Vector3.length_squared(b) * Vector3.cross(c, normal) + Vector3.length_squared(c) * Vector3.cross(normal, b)
	local center = a + numerator / (2 * Vector3.length_squared(normal))
	local offset = center - Unit.world_position(unit, hand.tip)
	return Vector3Box(Quaternion.rotate(Quaternion.inverse(Unit.world_rotation(unit, hand.tip)), offset))
end

RiderPose.create = function (unit, settings, resource)
	local world = Managers.world:world("level_world")
	local reference = reference_pose(world, resource)
	assert(Unit.num_scene_graph_items(unit) == reference.count, "Rider rig does not match its base unit")
	local pose = {
		settings = settings,
		reference = reference,
		original = {},
		hips = Unit.node(unit, "j_hips"),
		spine = Unit.node(unit, "j_spine"),
		neck = Unit.node(unit, "j_neck"),
		hands = {},
		feet = {},
	}
	for node = 2, Unit.num_scene_graph_items(unit) do
		pose.original[node] = Matrix4x4Box(Unit.local_pose(unit, node))
	end
	for _, side in ipairs({ "left", "right" }) do
		local hand = limb_nodes(unit, side, "arm", "forearm", "hand")
		hand.fingers = {}
		for _, finger in ipairs({ "index", "middle", "ring", "pinky" }) do
			for joint, angle in ipairs(FINGER_CURL) do
				hand.fingers[#hand.fingers + 1] = {
					node = Unit.node(unit, "j_" .. side .. "hand" .. finger .. joint),
					rotation = QuaternionBox(Quaternion.axis_angle(Vector3.up(), angle)),
				}
			end
		end
		pose.hands[side] = hand
		pose.feet[side] = limb_nodes(unit, side, "upleg", "leg", "foot")
	end
	reset_bones(unit, reference)
	for _, hand in pairs(pose.hands) do
		close_hand(unit, hand)
	end
	World.update_unit_and_children(world, unit)
	local origin = Unit.world_position(unit, 1)
	local up = Quaternion.up(Unit.world_rotation(unit, 1))
	for side, hand in pairs(pose.hands) do
		hand.grip_offset = grip_offset(unit, side, hand)
		local foot = pose.feet[side]
		foot.height = Vector3.dot(Unit.world_position(unit, foot.tip) - origin, up)
	end
	RiderPose.restore(unit, pose)
	World.update_unit_and_children(world, unit)
	return pose
end

RiderPose.restore = function (unit, pose)
	for node, original in pairs(pose.original) do
		Unit.set_local_pose(unit, node, original:unbox())
	end
end

RiderPose.apply = function (vehicle, occupant)
	local pose = occupant.rider_pose
	if not pose then
		return
	end
	local world, unit = vehicle.world, occupant.unit
	local settings, reference = pose.settings, pose.reference
	local body = Unit.world_rotation(vehicle.unit, 1)
	local origin = vehicle.position:unbox()
	-- Preserve every node's scale, including the player's chosen height at the root.
	reset_bones(unit, reference)
	World.update_unit_and_children(world, unit)
	PoseMath.set_rotation(world, unit, pose.hips, Quaternion.multiply(body, reference.hips:unbox()))
	PoseMath.set_position(world, unit, pose.hips, origin + Quaternion.rotate(body, Vector3(unpack(settings.hips))))
	local torso = Quaternion.multiply(body, Quaternion.axis_angle(Vector3.right(), -settings.lean))
	PoseMath.set_rotation(world, unit, pose.spine, Quaternion.multiply(torso, reference.spine:unbox()))
	PoseMath.set_rotation(world, unit, pose.neck, Quaternion.multiply(body, reference.neck:unbox()))
	for side, foot in pairs(pose.feet) do
		local target = settings.feet[side]
		local position = origin + Quaternion.rotate(body, Vector3(unpack(target.position))) + Quaternion.up(body) * foot.height
		local bend = Quaternion.rotate(body, Vector3(unpack(target.bend)))
		PoseMath.limb(world, unit, foot, position, bend)
		PoseMath.set_rotation(world, unit, foot.tip, Quaternion.multiply(body, reference.feet[side]:unbox()))
	end
	for side, hand in pairs(pose.hands) do
		local target = settings.hands[side]
		local rotation = Quaternion.multiply(body, Quaternion.from_yaw_pitch_roll(unpack(target.rotation)))
		local grip = origin + Quaternion.rotate(body, Vector3(unpack(target.position)))
		local position = grip - Quaternion.rotate(rotation, hand.grip_offset:unbox())
		local bend = Quaternion.rotate(body, Vector3(unpack(target.bend)))
		PoseMath.limb(world, unit, hand, position, bend)
		PoseMath.set_rotation(world, unit, hand.tip, rotation)
		close_hand(unit, hand)
	end
	World.update_unit_and_children(world, unit)
end

return RiderPose
