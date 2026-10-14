local mod = get_mod("Mechanization")
local Platform = mod.load_module("players/platform")
local Surfaces = mod.load_module("physics/surfaces")
local Interpolation = {}
local BUFFER_TIME = 0.1

local function position (sample)
	return sample.ground and Surfaces.position(sample.ground) or Vector3(unpack(sample.p))
end

local function yaw (sample)
	if sample.ground then
		return sample.ground.yaw + Quaternion.yaw(Matrix4x4.rotation(Surfaces.pose(sample.ground)))
	end
	return sample.yaw
end

local function normal (sample)
	if sample.ground then
		return Quaternion.rotate(Matrix4x4.rotation(Surfaces.pose(sample.ground)), Vector3(unpack(sample.ground.normal)))
	end
	return Vector3(unpack(sample.state.normal))
end

Interpolation.angle = function (from, to, fraction)
	return from + ((to - from + math.pi) % (math.pi * 2) - math.pi) * fraction
end

Interpolation.normal = function (from, to, fraction)
	return Vector3.normalize(Vector3.lerp(Vector3(unpack(from)), Vector3(unpack(to)), fraction))
end

Interpolation.receive = function (vehicle, data, time)
	local stream = vehicle.stream
	if not stream then
		stream = { offset = time - data.time, samples = {} }
		vehicle.stream = stream
	end
	local samples = stream.samples
	if #samples > 0 and data.time <= samples[#samples].time then
		return
	end
	samples[#samples + 1] = data
end

Interpolation.update = function (vehicle, time)
	local stream = vehicle.stream
	local samples = stream.samples
	local cursor = time - stream.offset - BUFFER_TIME
	while #samples > 2 and samples[2].time <= cursor do
		table.remove(samples, 1)
	end
	local from, to = samples[1], samples[2] or samples[1]
	local fraction = to.time > from.time and math.clamp((cursor - from.time) / (to.time - from.time), 0, 1) or 1
	vehicle.position:store(Vector3.lerp(position(from), position(to), fraction))
	vehicle.yaw = Interpolation.angle(yaw(from), yaw(to), fraction)
	vehicle.type.interpolate(vehicle, from.state, to.state, fraction)
	if from.ground or to.ground then
		vehicle.normal:store(Vector3.normalize(Vector3.lerp(normal(from), normal(to), fraction)))
	end
	for index, occupant in pairs(vehicle.occupants) do
		Platform.interpolate(occupant, from.platforms[index], to.platforms[index], fraction)
	end
end

return Interpolation
