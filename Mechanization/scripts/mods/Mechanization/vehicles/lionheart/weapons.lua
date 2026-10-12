local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/lionheart/settings")
local Explosion = require("scripts/utilities/attack/explosion")
local ExplosionTemplates = require("scripts/settings/damage/explosion_templates")
local DamageProfileTemplates = require("scripts/settings/damage/damage_profile_templates")
local Damage = mod.load_module("weapons/damage")
local Weapons = {}
local Laser = mod.load_module("weapons/laser")
local LASER_EFFECT = {
	muzzle_scale = Settings.front_muzzle_scale,
	beam_width = Settings.front_beam_width,
	trail_scale = Settings.front_trail_width_scale,
	impact_scale = Settings.front_impact_scale,
}
local SHELL_IMPACT = "content/fx/particles/explosions/tank_wall_explosion"
local MAIN_DAMAGE = Damage.profile(DamageProfileTemplates.no_mans_land_tank_wall_explosion, Settings.main_attack_power, Settings.main_armor)
local FRONT_DAMAGE = Laser.profile(Settings.front_attack_power, Settings.front_armor, Settings.front_splash_radius, Settings.front_splash_fraction)
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
	Laser.effect(v.world, position, rotation, endpoint, hit, LASER_EFFECT)
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
	local endpoint, hit = Laser.trace(v, position, rotation, Settings.shot_range, secondary and Settings.front_beam_radius)
	if secondary then
		v.front_rounds = v.front_rounds - 1
		local delay = v.front_rounds == 0 and Settings.front_reload_time or Settings.front_shot_interval
		v.next_front_shot = time + delay
		if hit then
			Laser.damage(v, FRONT_DAMAGE, hit, rotation, attacker)
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
