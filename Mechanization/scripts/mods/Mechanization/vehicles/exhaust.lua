local Exhaust = {}
local EFFECT = "content/fx/particles/environment/smoke_cooling_ground_directional_thin"
local SCALE = 0.7
local EMISSION = 2

Exhaust.create = function (world, unit, emitters)
	local exhaust = { world = world, group = World.create_particle_group(world), particles = {} }
	local scale = Vector3(SCALE, SCALE, SCALE)
	for _, emitter in ipairs(emitters) do
		local offset = Vector3(unpack(emitter.offset))
		local rotation = Unit.world_rotation(unit, emitter.node)
		local position = Unit.world_position(unit, emitter.node) + Quaternion.rotate(rotation, offset)
		local effect = World.create_particles(world, EFFECT, position, Quaternion.identity(), scale, exhaust.group)
		World.set_particles_emit_rate_multiplier(world, effect, EMISSION)
		local pose = Matrix4x4.from_quaternion_position(Quaternion.inverse(rotation), offset)
		Matrix4x4.set_scale(pose, scale)
		World.link_particles(world, effect, unit, emitter.node, pose, "destroy")
		exhaust.particles[#exhaust.particles + 1] = effect
	end
	return exhaust
end

Exhaust.destroy = function (exhaust)
	for _, effect in ipairs(exhaust.particles) do
		World.destroy_particles(exhaust.world, effect)
	end
	World.destroy_particle_group(exhaust.world, exhaust.group)
end

return Exhaust
