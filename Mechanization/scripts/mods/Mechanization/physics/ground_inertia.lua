local mod = get_mod("Mechanization")
local Motion = mod.load_module("physics/motion")
local Contacts = mod.load_module("physics/contacts")
local GroundInertia = {}
local CONTACT_EPSILON = 0.001

GroundInertia.height = function (v, height, dt)
	local settings = v.type.settings
	local current = v.position:unbox().z
	if not height or current - height > settings.suspension_travel then
		local next_height = current + v.vertical_speed * dt - settings.gravity * dt * dt * 0.5
		v.vertical_speed = v.vertical_speed - settings.gravity * dt
		return height and math.max(height, next_height) or next_height
	end
	local response = settings.suspension_response
	local offset = current - height
	local velocity = v.vertical_speed + response * offset
	local decay = math.exp(-response * dt)
	v.vertical_speed = (v.vertical_speed - response * velocity * dt) * decay
	return height + (offset + velocity * dt) * decay
end

GroundInertia.record = function (v, origin, dt)
	v.horizontal_velocity:store(Vector3.flat(v.position:unbox() - origin) / dt)
end

GroundInertia.step = function (v, height, rotation, dt, vehicles)
	local origin = v.position:unbox()
	local clearance = v.type.settings.suspension_travel + CONTACT_EPSILON
	local supported = height and origin.z - height <= clearance
	if supported and (not v.airborne or v.vertical_speed <= 0) then
		if v.airborne then
			local forward = Vector3.normalize(Vector3.flat(Quaternion.forward(rotation)))
			v.drive_speed = Vector3.dot(v.horizontal_velocity:unbox(), forward)
			v.vertical_speed = 0
		end
		v.airborne = false
		return false
	end
	v.airborne = true
	-- Ground controls cannot redirect momentum or apply braking without contact.
	local velocity = v.horizontal_velocity:unbox()
	local destination = origin + velocity * dt
	local resistance = Contacts.resistance(v, destination, rotation)
	destination = origin + (destination - origin) * resistance
	local next_height = origin.z + v.vertical_speed * dt - v.type.settings.gravity * dt * dt * 0.5
	v.vertical_speed = v.vertical_speed - v.type.settings.gravity * dt
	local floor = v.type.controller.support_height(v, destination, rotation)
	local landing = floor and floor <= origin.z + CONTACT_EPSILON and next_height <= floor and v.vertical_speed <= 0
	if landing then
		next_height = floor
	end
	-- Gravity and momentum share the same slide, so a steep face cannot hold the vehicle in midair.
	destination.z = next_height
	local position, contact_normal = Motion.translate(v, destination, rotation, vehicles)
	local horizontal = Vector3.flat(position - origin) / dt
	v.horizontal_velocity:store(horizontal / resistance)
	local forward = Vector3.normalize(Vector3.flat(Quaternion.forward(rotation)))
	local longitudinal = Vector3.dot(horizontal, forward)
	v.speed = Vector3.length(horizontal) * (longitudinal < 0 and -1 or 1)
	if landing and math.abs(position.z - floor) <= CONTACT_EPSILON then
		v.airborne = false
		v.vertical_speed = 0
		v.drive_speed = longitudinal
	elseif math.abs(position.z - next_height) > CONTACT_EPSILON then
		local supported_hull = contact_normal and v.type.controller.supports_contact(v, contact_normal)
		if supported_hull and position.z > next_height and v.vertical_speed <= 0 then
			-- The chassis can rest on terrain before its wheels reach their landing height.
			v.airborne = false
			v.vertical_speed = 0
			v.drive_speed = longitudinal
		else
			v.vertical_speed = (position.z - origin.z) / dt
		end
	end
	v.position:store(position)
	return true
end

return GroundInertia
