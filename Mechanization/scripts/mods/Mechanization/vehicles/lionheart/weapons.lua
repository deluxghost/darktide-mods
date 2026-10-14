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
local SHELL_EXPLOSION_SOUND = "wwise/events/weapon/play_explosion_grenade_frag_ogryn"
-- The original event delays its main cannon report by 400 ms.
local FIRE_SOUND_DELAY = 0.4
local MAIN_EXPLOSION = table.clone(ExplosionTemplates.tank_wall_explosion)
MAIN_EXPLOSION.radius = Settings.main_explosion_radius
MAIN_EXPLOSION.close_radius = Settings.main_explosion_close_radius

Weapons.configure = function (v)
	local main = table.clone(MAIN_EXPLOSION)
	local damage = Damage.profile(DamageProfileTemplates.no_mans_land_tank_wall_explosion, v.config.main_damage, Settings.main_armor)
	main.damage_profile, main.close_damage_profile = damage, damage
	v.weapon_profiles = {
		main = main,
		front = Laser.profile(v.config.front_damage, Settings.front_armor, Settings.front_splash_radius, Settings.front_splash_fraction),
	}
end

Weapons.update = function (vehicle, v, time)
	if v.rounds == 0 and time >= v.next_shot then
		v.rounds = Settings.magazine_size
	end
	if v.front_rounds == 0 and time >= v.next_front_shot then
		v.front_rounds = Settings.front_magazine_size
	end
	local shell = v.shell
	if not shell then
		return
	end
	if shell.phase == "fire" then
		if time < shell.fires_at then
			return
		end
		vehicle.pose(v)
		local position, rotation = vehicle.muzzle(v)
		local endpoint, hit = Laser.trace(v, position, rotation, Settings.shot_range)
		if hit then
			shell.phase = "impact"
			shell.arrives_at = time + Vector3.distance(position, endpoint) / Settings.main_shell_speed
			shell.position = Vector3Box(endpoint)
			shell.rotation = QuaternionBox(rotation)
		else
			v.shell = nil
		end
		return { weapon = "main", phase = "fire" }
	end
	if time < shell.arrives_at then
		return
	end

	v.shell = nil
	local endpoint = shell.position:unbox()
	Explosion.create_explosion(
		v.world, World.physics_world(v.world), endpoint, shell.rotation:unbox(), shell.attacker,
		v.weapon_profiles.main, 500, 1, "ranged", false, false
	)
	return { weapon = "main", phase = "impact", endpoint = { endpoint.x, endpoint.y, endpoint.z }, hit = true }
end

Weapons.effect = function (vehicle, v, event)
	if event.weapon == "main" then
		if event.phase == "prepare" then
			WwiseWorld.trigger_resource_event(v.wwise, "wwise/events/world/play_tank_mission_turret_fire", v.source)
		elseif event.phase == "fire" then
			vehicle.fire_fx(v)
		else
			local endpoint = Vector3(unpack(event.endpoint))
			World.create_particles(v.world, SHELL_IMPACT, endpoint, Quaternion.identity())
			local source = WwiseWorld.make_auto_source(v.wwise, endpoint)
			WwiseWorld.trigger_resource_event(v.wwise, SHELL_EXPLOSION_SOUND, source)
		end
		return
	end

	vehicle.pose(v)
	local position, rotation = vehicle.front_muzzle(v)
	Laser.effect(v.world, position, rotation, Vector3(unpack(event.endpoint)), event.hit, LASER_EFFECT)
	WwiseWorld.trigger_resource_event(v.wwise, "wwise/events/world/play_valkyrie_lascannon_near", v.source)
end

Weapons.fire = function (vehicle, v, secondary, time, attacker)
	local next_shot = secondary and v.next_front_shot or v.next_shot
	if time < next_shot then
		return
	end

	if not secondary then
		v.rounds = v.rounds - 1
		v.next_shot = time + Settings.reload_time
		v.shell = { phase = "fire", fires_at = time + FIRE_SOUND_DELAY, attacker = attacker }
		return { weapon = "main", phase = "prepare" }
	end

	vehicle.pose(v)
	local position, rotation = vehicle.front_muzzle(v)
	local endpoint, hit = Laser.trace(v, position, rotation, Settings.shot_range, Settings.front_beam_radius)
	v.front_rounds = v.front_rounds - 1
	local delay = v.front_rounds == 0 and Settings.front_reload_time or Settings.front_shot_interval
	v.next_front_shot = time + delay
	if hit then
		Laser.damage(v, v.weapon_profiles.front, hit, rotation, attacker)
	end
	return { weapon = "front", phase = "fire", endpoint = { endpoint.x, endpoint.y, endpoint.z }, hit = hit ~= nil }
end

return Weapons
