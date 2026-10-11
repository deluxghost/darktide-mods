local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/lionheart/settings")
local Attack = require("scripts/utilities/attack/attack")
local Explosion = require("scripts/utilities/attack/explosion")
local ExplosionTemplates = require("scripts/settings/damage/explosion_templates")
local DamageProfileTemplates = require("scripts/settings/damage/damage_profile_templates")
local HitZone = require("scripts/utilities/attack/hit_zone")
local HitScan = require("scripts/utilities/attack/hit_scan")
local Health = require("scripts/utilities/health")
local Weapons = {}
local LASER_BEAM = "content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_charged"
local LASER_TRAIL = "content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger_bfg"
local TRAIL_SEGMENT_LENGTH = 5
local LASER_MUZZLE = "content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle"
local LASER_IMPACT = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_surface_bfg_player"
local SHELL_IMPACT = "content/fx/particles/explosions/tank_wall_explosion"
local MAIN_DAMAGE = table.clone(DamageProfileTemplates.no_mans_land_tank_wall_explosion)
MAIN_DAMAGE.power_distribution.attack = Settings.main_attack_power
local FRONT_DAMAGE = table.clone(DamageProfileTemplates.default_lasgun_bfg)
FRONT_DAMAGE.power_distribution.attack = Settings.front_attack_power
for _, range in pairs(FRONT_DAMAGE.armor_damage_modifier_ranged) do
	for armor in pairs(range.attack) do
		range.attack[armor] = 1
	end
end
local MAIN_EXPLOSION = table.clone(ExplosionTemplates.tank_wall_explosion)
MAIN_EXPLOSION.radius = Settings.main_explosion_radius
MAIN_EXPLOSION.close_radius = Settings.main_explosion_close_radius
MAIN_EXPLOSION.damage_profile = MAIN_DAMAGE
MAIN_EXPLOSION.close_damage_profile = MAIN_DAMAGE

Weapons.update = function (v, time)
	if v.rounds == 0 and time >= v.next_shot then
		v.rounds = Settings.magazine_size
	end
	if v.front_rounds == 0 and time >= v.next_front_shot then
		v.front_rounds = Settings.front_magazine_size
	end
end

local function trace (v, position, rotation, secondary)
	local direction = Quaternion.forward(rotation)
	local physics_world = World.physics_world(v.world)
	local hits
	if secondary then
		hits = HitScan.sphere_sweep(physics_world, position, direction, Settings.shot_range, "both", nil, nil, Settings.front_beam_radius)
		for index, hit in ipairs(hits or {}) do
			hits[index] = { hit.position, hit.distance, hit.normal, hit.actor }
		end
	else
		hits = HitScan.raycast(physics_world, position, direction, Settings.shot_range)
	end
	local nearest = Settings.shot_range
	local selected

	for _, hit in ipairs(hits or {}) do
		local unit = Actor.unit(hit[4])
		local occupant_hit = false
		for _, occupant in pairs(v.occupants) do
			occupant_hit = occupant_hit or occupant.unit == unit
		end
		local hit_zone = HitZone.get_name(unit, hit[4])
		local damageable_actor = Health.can_actor_collide_with_attack_type(unit, hit[4], "ranged")
		if unit ~= v.unit and not occupant_hit and hit_zone ~= "afro" and damageable_actor and hit[2] < nearest then
			nearest = hit[2]
			selected = hit
		end
	end

	return selected and selected[1] or position + direction * Settings.shot_range, selected
end

Weapons.effect = function (vehicle, v, secondary, endpoint, hit)
	vehicle.pose(v)
	if not secondary then
		vehicle.fire_fx(v)
		if hit then
			World.create_particles(v.world, SHELL_IMPACT, endpoint, Quaternion.identity())
		end
		return
	end

	local position, rotation = vehicle.front_muzzle(v)
	-- A sweep contact can lie off the beam axis; keep the beam aligned with the barrel.
	local distance = math.max(0, Vector3.dot(endpoint - position, Quaternion.forward(rotation)))
	local muzzle_scale = Settings.front_muzzle_scale
	World.create_particles(v.world, LASER_MUZZLE, position, rotation, Vector3(muzzle_scale, muzzle_scale, muzzle_scale))
	local beam = World.create_particles(v.world, LASER_BEAM, position, rotation)
	local variable = World.find_particles_variable(v.world, LASER_BEAM, "hit_distance")
	World.set_particles_variable(v.world, beam, variable, Vector3(Settings.front_beam_width, distance, distance))
	-- The stock BFG trail covers fixed five-metre segments rather than one full beam.
	local direction = Quaternion.forward(rotation)
	local trail_scale = Vector3(Settings.front_trail_width_scale, 1, Settings.front_trail_width_scale)
	for offset = 1, distance - TRAIL_SEGMENT_LENGTH, TRAIL_SEGMENT_LENGTH do
		World.create_particles(v.world, LASER_TRAIL, position + direction * offset, rotation, trail_scale)
	end
	if hit then
		local scale = Settings.front_impact_scale
		World.create_particles(v.world, LASER_IMPACT, endpoint, Quaternion.look(-direction), Vector3(scale, scale, scale))
	end
	WwiseWorld.trigger_resource_event(v.wwise, "wwise/events/world/play_valkyrie_lascannon_near", v.source)
end

Weapons.fire = function (vehicle, v, secondary, time, attacker)
	Weapons.update(v, time)
	local next_shot = secondary and v.next_front_shot or v.next_shot
	if time < next_shot then
		return
	end

	vehicle.pose(v)
	local muzzle = secondary and vehicle.front_muzzle or vehicle.muzzle
	local position, rotation = muzzle(v)
	local endpoint, hit = trace(v, position, rotation, secondary)
	if secondary then
		v.front_rounds = v.front_rounds - 1
		local delay = v.front_rounds == 0 and Settings.front_reload_time or Settings.front_shot_interval
		v.next_front_shot = time + delay
		if hit then
			local actor = hit[4]
			local unit = Actor.unit(actor)
			if HEALTH_ALIVE[unit] then
				Attack.execute(
					unit, FRONT_DAMAGE, "power_level", 500, "charge_level", 1,
					"attack_direction", Quaternion.forward(rotation), "hit_zone_name", HitZone.get_name(unit, actor),
					"hit_actor", actor, "hit_world_position", endpoint, "attacking_unit", attacker,
					"attack_type", "ranged", "damage_type", "laser_bfg"
				)
			end
		end
	else
		v.rounds = v.rounds - 1
		v.next_shot = time + Settings.reload_time
		if hit then
			Explosion.create_explosion(
				v.world, World.physics_world(v.world), endpoint, rotation, attacker,
				MAIN_EXPLOSION, 500, 1, "ranged", false, false
			)
		end
	end

	Weapons.effect(vehicle, v, secondary, endpoint, hit ~= nil)
	return endpoint, hit ~= nil
end

return Weapons
