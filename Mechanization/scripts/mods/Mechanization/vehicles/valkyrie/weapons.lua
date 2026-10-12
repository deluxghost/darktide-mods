local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/valkyrie/settings")
local Controller = mod.load_module("vehicles/valkyrie/controller")
local Laser = mod.load_module("weapons/laser")
local View = mod.load_module("camera")
local Attack = require("scripts/utilities/attack/attack")
local HitZone = require("scripts/utilities/attack/hit_zone")
local DamageProfileTemplates = require("scripts/settings/damage/damage_profile_templates")
local Damage = mod.load_module("weapons/damage")
local ProjectileTemplates = require("scripts/settings/projectile/projectile_templates")
local ExplosionTemplates = require("scripts/settings/damage/explosion_templates")
local ProjectileLocomotionSettings = require("scripts/settings/projectile_locomotion/projectile_locomotion_settings")
local MasterItems = require("scripts/backend/master_items")
local Weapons = {}
local LASER_DAMAGE = Damage.profile(DamageProfileTemplates.default_lasgun_bfg, Settings.laser_power, Settings.laser_armor)
local LASER_EFFECT = { muzzle_scale = 4, beam_width = 5, trail_scale = 2.5, impact_scale = 3 }
local ROCKET_TEMPLATE = table.clone(ProjectileTemplates.attack_valkyrie_missile)
local ROCKET_EXPLOSION = table.clone(ExplosionTemplates.attack_valkyrie_missile)
local ROCKET_DAMAGE = Damage.profile(DamageProfileTemplates.no_mans_land_tank_wall_explosion, Settings.rocket_power, Settings.rocket_armor)
ROCKET_EXPLOSION.radius = Settings.rocket_radius
ROCKET_EXPLOSION.min_radius = Settings.rocket_radius
ROCKET_EXPLOSION.close_radius = Settings.rocket_radius * 0.5
ROCKET_EXPLOSION.min_close_radius = Settings.rocket_radius * 0.5
ROCKET_EXPLOSION.damage_profile, ROCKET_EXPLOSION.close_damage_profile = ROCKET_DAMAGE, ROCKET_DAMAGE
ROCKET_TEMPLATE.damage.fuse.explosion_template = ROCKET_EXPLOSION
ROCKET_TEMPLATE.damage.impact.explosion_template = ROCKET_EXPLOSION
local WEAPONS = {
	laser = { capacity = Settings.laser_capacity, interval = Settings.laser_interval, reload = Settings.laser_reload },
	rocket = { capacity = Settings.rocket_capacity, interval = Settings.rocket_interval, reload = Settings.rocket_reload },
}

Weapons.update = function (v, time)
	for action, weapon in pairs(WEAPONS) do
		if v[action .. "_rounds"] == 0 and time >= v["next_" .. action] then
			v[action .. "_rounds"] = weapon.capacity
		end
	end
end

Weapons.muzzle = function (v, action, side)
	if action == "rocket" then
		local node = Unit.node(v.unit, "fx_wpn_node_" .. side)
		return Unit.world_position(v.unit, node), Controller.rotation(v)
	end
	-- The three nose-gun meshes are detail levels of one barrel, not three weapons.
	local offset = Vector3(1.25, 5.78, 2.16)
	return v.position:unbox() + Quaternion.rotate(Controller.rotation(v), offset), Controller.rotation(v)
end

Weapons.effect = function (v, event)
	local position = Vector3(unpack(event.origin))
	local rotation = Quaternion.from_yaw_pitch_roll(event.yaw, event.pitch, event.roll)
	if event.weapon == "laser" then
		Laser.effect(v.world, position, rotation, Vector3(unpack(event.endpoint)), event.hit, LASER_EFFECT)
		WwiseWorld.trigger_resource_event(v.wwise, "wwise/events/world/play_valkyrie_lascannon_near", v.source)
	else
		WwiseWorld.trigger_resource_event(v.wwise, "wwise/events/world/play_expeditions_attack_valkyrie_shoot", v.source)
	end
	if event.reloading then
		local sound = event.weapon == "laser" and "wwise/events/world/play_valkyrie_lascannon_fire_charge_01"
			or "wwise/events/world/play_expeditions_attack_valkyrie_ready_missiles"
		WwiseWorld.trigger_resource_event(v.wwise, sound, v.source)
	end
end

Weapons.fire = function (v, action, control, time)
	local weapon = WEAPONS[action]
	if time < v["next_" .. action] then
		return
	end
	Controller.pose(v)
	local position, body = Weapons.muzzle(v, action, v.rocket_side)
	local desired = View.direction(v, control.yaw, control.pitch, position, Settings.shot_range)
	local local_aim = Quaternion.rotate(Quaternion.inverse(body), desired)
	-- Fixed aircraft weapons converge on the reticle within a small forward firing cone.
	local yaw = math.clamp(math.atan2(-local_aim.x, local_aim.y), math.rad(-8), math.rad(8))
	local pitch = math.clamp(math.asin(math.clamp(local_aim.z, -1, 1)), math.rad(-8), math.rad(8))
	local rotation = Quaternion.multiply(body, Quaternion.from_yaw_pitch_roll(yaw, pitch, 0))
	local event = { weapon = action, origin = { position.x, position.y, position.z } }
	event.yaw, event.pitch, event.roll = Quaternion.to_yaw_pitch_roll(rotation)
	if action == "laser" then
		local endpoint, hit = Laser.trace(v, position, rotation, Settings.shot_range, Settings.laser_radius)
		event.endpoint, event.hit = { endpoint.x, endpoint.y, endpoint.z }, hit ~= nil
		if hit and HEALTH_ALIVE[Actor.unit(hit[4])] then
			Attack.execute(
				Actor.unit(hit[4]), LASER_DAMAGE, "power_level", 500, "charge_level", 1,
				"attacking_unit", control.unit, "attack_direction", Quaternion.forward(rotation),
				"hit_actor", hit[4], "hit_zone_name", HitZone.get_name(Actor.unit(hit[4]), hit[4]),
				"hit_world_position", endpoint, "attack_type", "ranged", "damage_type", "laser_bfg"
			)
		end
	else
		local template = ROCKET_TEMPLATE
		local item = MasterItems.get_cached()[template.item_name]
		local side_name = Managers.state.extension:system("side_system").side_by_unit[control.unit]:name()
		Managers.state.unit_spawner:spawn_network_unit(
			nil, "item_projectile", position, rotation, nil, item, template, ProjectileLocomotionSettings.states.manual_physics,
			Quaternion.forward(rotation), Settings.rocket_speed, Vector3.zero(), control.unit,
			false, nil, 1, nil, nil, nil, nil, side_name
		)
	end
	if action == "rocket" then
		v.rocket_side = v.rocket_side % 2 + 1
	end
	v[action .. "_rounds"] = v[action .. "_rounds"] - 1
	v["next_" .. action] = time + (v[action .. "_rounds"] == 0 and weapon.reload or weapon.interval)
	event.reloading = v[action .. "_rounds"] == 0
	Weapons.effect(v, event)
	return event
end

return Weapons
