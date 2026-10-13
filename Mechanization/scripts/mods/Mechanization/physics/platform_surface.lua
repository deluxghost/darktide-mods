local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Surface = {}
local CONTACT_GAP = 0.03

local function clearance (region, position)
	local distance = position.x - region.min[1]
	local normal = Vector3.right()
	local boundaries = {
		{ region.max[1] - position.x, -Vector3.right() },
		{ position.y - region.min[2], Vector3.forward() },
		{ region.max[2] - position.y, -Vector3.forward() },
	}
	for _, boundary in ipairs(boundaries) do
		if boundary[1] < distance then
			distance, normal = boundary[1], boundary[2]
		end
	end
	for _, obstacle in ipairs(region.obstacles) do
		local center = Vector3(obstacle.center[1], obstacle.center[2], 0)
		center.y = math.clamp(position.y, center.y - obstacle.half_length, center.y + obstacle.half_length)
		local offset = Vector3.flat(position - center)
		local length = Vector3.length(offset)
		local gap = length - obstacle.radius
		if gap < distance then
			distance, normal = gap, Vector3.normalize(offset)
		end
	end
	return distance, normal
end

Surface.height = function (vehicle, occupant, position)
	local region = assert(vehicle.type.platforms[occupant.seat.platform], "Unknown vehicle platform")
	local radius = Collision.player_footprint(occupant.unit) + CONTACT_GAP
	if clearance(region, position) >= radius then
		return region.floor_height
	end
end

Surface.normal = function (vehicle, occupant, position)
	local region = assert(vehicle.type.platforms[occupant.seat.platform], "Unknown vehicle platform")
	local _, normal = clearance(region, position)
	return normal
end

return Surface
