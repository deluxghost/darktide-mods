local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/valkyrie/settings")
local Controller = mod.load_module("vehicles/valkyrie/controller")
local Laser = mod.load_module("weapons/laser")
local View = mod.load_module("camera")
local Damage = mod.load_module("weapons/damage")
local DamageProfileTemplates = require("scripts/settings/damage/damage_profile_templates")
local ProjectileTemplates = require("scripts/settings/projectile/projectile_templates")
local ExplosionTemplates = require("scripts/settings/damage/explosion_templates")
local ProjectileLocomotionSettings = require("scripts/settings/projectile_locomotion/projectile_locomotion_settings")
local MasterItems = require("scripts/backend/master_items")
local Weapons = {}
local AIM_LIMIT = math.rad(8)
local LASER_DAMAGE = Laser.profile(Settings.laser_power, Settings.laser_armor, Settings.laser_splash_radius, Settings.laser_splash_fraction)
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

Weapons.aim = function (v, action, yaw, pitch)
	local position, body = Weapons.muzzle(v, action, v.rocket_side)
	local desired, sight = View.direction(v, yaw, pitch, position, Settings.shot_range)
	local inverse_body = Quaternion.inverse(body)
	local local_aim = Quaternion.rotate(inverse_body, desired)
	local local_sight = Quaternion.rotate(inverse_body, Quaternion.forward(sight))
	local sight_yaw = math.atan2(-local_sight.x, local_sight.y)
	local sight_pitch = math.asin(math.clamp(local_sight.z, -1, 1))
	-- Limit mouse tracking separately from camera-to-muzzle parallax compensation.
	local aim_yaw = math.atan2(-local_aim.x, local_aim.y) + math.clamp(sight_yaw, -AIM_LIMIT, AIM_LIMIT) - sight_yaw
	local aim_pitch = math.asin(math.clamp(local_aim.z, -1, 1)) + math.clamp(sight_pitch, -AIM_LIMIT, AIM_LIMIT) - sight_pitch
	local rotation = Quaternion.multiply(body, Quaternion.from_yaw_pitch_roll(aim_yaw, aim_pitch, 0))
	return position, rotation
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
	local position, rotation = Weapons.aim(v, action, control.yaw, control.pitch)
	local event = { weapon = action, origin = { position.x, position.y, position.z } }
	event.yaw, event.pitch, event.roll = Quaternion.to_yaw_pitch_roll(rotation)
	if action == "laser" then
		local endpoint, hit = Laser.trace(v, position, rotation, Settings.shot_range, Settings.laser_radius)
		event.endpoint, event.hit = { endpoint.x, endpoint.y, endpoint.z }, hit ~= nil
		if hit then
			Laser.damage(v, LASER_DAMAGE, hit, rotation, control.unit)
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
