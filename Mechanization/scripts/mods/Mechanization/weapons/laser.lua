local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local HitScan = require("scripts/utilities/attack/hit_scan")
local HitZone = require("scripts/utilities/attack/hit_zone")
local Health = require("scripts/utilities/health")
local Attack = require("scripts/utilities/attack/attack")
local Explosion = require("scripts/utilities/attack/explosion")
local DamageProfileTemplates = require("scripts/settings/damage/damage_profile_templates")
local Damage = mod.load_module("weapons/damage")
local Laser = {}
local BEAM = "content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_charged"
local TRAIL = "content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger_bfg"
local MUZZLE = "content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle"
local IMPACT = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_surface_bfg_player"
local TRAIL_LENGTH = 5

Laser.profile = function (power, armor, radius, splash_fraction)
	local direct = Damage.profile(DamageProfileTemplates.default_lasgun_bfg, power, armor)
	local splash_power = power * splash_fraction
	local splash = Damage.profile(DamageProfileTemplates.default_lasgun_bfg, splash_power, armor)
	splash.power_distribution_ranged = {
		attack = { near = splash_power, far = 0 },
		impact = { near = splash.power_distribution.impact, far = 0 },
	}
	return {
		direct = direct,
		explosion = {
			name = "mechanization_laser_impact",
			radius = radius,
			-- Props receive the direct hit; splash fades from the impact and queries characters only.
			close_radius = 0,
			broadphase_explosion_filter = { "heroes", "villains" },
			damage_profile = splash,
			close_damage_profile = splash,
			damage_type = "laser_bfg",
			close_damage_type = "laser_bfg",
			damage_falloff = true,
			skip_ragdoll_interaction = true,
		},
	}
end

Laser.damage = function (v, profile, hit, rotation, attacker)
	local actor = hit[4]
	local unit = Actor.unit(actor)
	local endpoint = hit[1]
	if HEALTH_ALIVE[unit] then
		Attack.execute(
			unit, profile.direct, "power_level", 500, "charge_level", 1,
			"attack_direction", Quaternion.forward(rotation), "hit_zone_name", HitZone.get_name(unit, actor),
			"hit_actor", actor, "hit_world_position", endpoint, "attacking_unit", attacker,
			"attack_type", "ranged", "damage_type", "laser_bfg"
		)
	end

	local explosion = table.shallow_copy(profile.explosion)
	explosion.target_validation_func = function (target)
		return target ~= unit and not Collision.contains_unit(v, target) and not Collision.contains_player(v, target)
	end
	-- Vehicle fire events already synchronize the impact effects; this template only queues damage.
	Explosion.create_explosion(
		v.world, World.physics_world(v.world), endpoint, rotation, attacker, explosion,
		500, 1, "ranged", false, false, nil, nil, nil, nil, nil, nil, nil, true
	)
end

Laser.trace = function (v, position, rotation, range, radius)
	local direction = Quaternion.forward(rotation)
	local physics = World.physics_world(v.world)
	local hits
	if radius then
		hits = HitScan.sphere_sweep(physics, position, direction, range, "both", nil, nil, radius)
		for index, hit in ipairs(hits or {}) do
			hits[index] = { hit.position, hit.distance, hit.normal, hit.actor }
		end
	else
		hits = HitScan.raycast(physics, position, direction, range)
	end
	local nearest, selected = range, nil
	for _, hit in ipairs(hits or {}) do
		local unit = Actor.unit(hit[4])
		local damageable = Health.can_actor_collide_with_attack_type(unit, hit[4], "ranged")
		if not Collision.contains_unit(v, unit) and not Collision.contains_player(v, unit)
			and HitZone.get_name(unit, hit[4]) ~= "afro" and damageable and hit[2] < nearest
		then
			nearest, selected = hit[2], hit
		end
	end
	return selected and selected[1] or position + direction * range, selected
end

Laser.effect = function (world, position, rotation, endpoint, hit, settings)
	local direction = Quaternion.forward(rotation)
	local distance = math.max(0, Vector3.dot(endpoint - position, direction))
	local muzzle_scale = settings.muzzle_scale
	World.create_particles(world, MUZZLE, position, rotation, Vector3(muzzle_scale, muzzle_scale, muzzle_scale))
	local beam = World.create_particles(world, BEAM, position, rotation)
	local variable = World.find_particles_variable(world, BEAM, "hit_distance")
	World.set_particles_variable(world, beam, variable, Vector3(settings.beam_width, distance, distance))
	local scale = Vector3(settings.trail_scale, 1, settings.trail_scale)
	for offset = 1, distance - TRAIL_LENGTH, TRAIL_LENGTH do
		World.create_particles(world, TRAIL, position + direction * offset, rotation, scale)
	end
	if hit then
		local impact_scale = settings.impact_scale
		World.create_particles(world, IMPACT, endpoint, Quaternion.look(-direction), Vector3(impact_scale, impact_scale, impact_scale))
	end
end

return Laser
