local mod = get_mod("Mechanization")
local Attack = require("scripts/utilities/attack/attack")
local ArmorSettings = require("scripts/settings/damage/armor_settings")
local Collision = mod.load_module("physics/collision")
local Health = {}
Health.__index = Health

Health.attach = function (vehicle, network)
	local maximum = vehicle.type.max_health
	assert(type(maximum) == "number" and maximum > 0 and maximum < math.huge, "Invalid vehicle health")
	vehicle.health = setmetatable({ vehicle = vehicle, network = network, maximum = maximum, remaining = maximum }, Health)
	Managers.state.position_lookup:register(vehicle.unit, vehicle.position:unbox())
	for part in pairs(vehicle.parts) do
		ScriptUnit.set_extension(part, "health_system", vehicle.health)
		if part ~= vehicle.unit then
			Managers.state.position_lookup:register(part, Unit.world_position(part, 1))
		end
		HEALTH_ALIVE[part] = true
		for index = 1, Unit.num_actors(part) do
			Actor.set_collision_filter(Unit.actor(part, index), "filter_destructible")
		end
	end
	local system = Managers.state.extension:system("broadphase_system")
	local center, half_extents = vehicle.type.controller.bounds(vehicle)
	local radius = Vector3.length(center) + Vector3.length(half_extents)
	vehicle.health.broadphase = system.broadphase
	-- Explosion queries require an actor on the registered unit; a composite vehicle's root may have none.
	vehicle.health.broadphase_unit = Actor.unit(vehicle.hit_actor)
	local position = POSITION_LOOKUP[vehicle.health.broadphase_unit]
	vehicle.health.broadphase_id = Broadphase.add(system.broadphase, vehicle.health.broadphase_unit, position, radius, { "destructibles" })
end

Health.detach = function (vehicle)
	local health = vehicle.health
	Broadphase.remove(health.broadphase, health.broadphase_id)
	for part in pairs(vehicle.parts) do
		ScriptUnit.remove_extension(part, "health_system")
		if part ~= vehicle.unit then
			Managers.state.position_lookup:unregister(part)
		end
		HEALTH_ALIVE[part] = nil
	end
	Managers.state.position_lookup:unregister(vehicle.unit)
end

Health.is_alive = function (self)
	return self.remaining > 0
end

Health.update = function (vehicle)
	local position = vehicle.position:unbox()
	local health = vehicle.health
	Broadphase.move(health.broadphase, health.broadphase_id, position)
	local volumes = Managers.state.extension:system("volume_event_system")._level_volumes_by_name
	for name, volume in pairs(volumes) do
		if volume.type == "content/volume_types/player_instakill" then
			for _, level in ipairs(volume.levels) do
				if Level.is_point_inside_volume(level, name, position) then
					vehicle.health:add_damage(vehicle.health:current_health())
					return
				end
			end
		end
	end
end

Health.is_invulnerable = function (self)
	return false
end

Health.max_health = function (self)
	return self.maximum
end

Health.current_health = function (self)
	return self.remaining
end

Health.current_health_percent = function (self)
	return self.remaining / self.maximum
end

Health.damage_taken = function (self)
	return self.maximum - self.remaining
end

Health.permanent_damage_taken = function (self)
	return 0
end

Health.max_wounds = function (self)
	return 1
end

Health.add_damage = function (self, damage)
	if not self.network.is_host() then
		return 0
	end
	assert(type(damage) == "number" and damage >= 0 and damage < math.huge, "Invalid vehicle damage")
	local dealt = math.min(self.remaining, damage)
	self.remaining = self.remaining - dealt
	for part in pairs(self.vehicle.parts) do
		HEALTH_ALIVE[part] = self.remaining > 0
	end
	return dealt
end

local function melee_hit (vehicle, unit, action, profile, damage_type, event, origin)
	local breed = ScriptUnit.extension(unit, "unit_data_system"):breed()
	origin = origin or Unit.world_position(unit, 1) + Vector3(0, 0, breed.base_height * 0.5)
	local target = Collision.closest_point(vehicle, origin)
	local offset = target - origin
	local reach = type(action.weapon_reach) == "table" and (action.weapon_reach[event] or action.weapon_reach.default)
		or action.weapon_reach
		or action.range
	assert(type(reach) == "number", "Vehicle melee attack has no reach")
	if Vector3.length(offset) > reach then
		return false
	end
	local direction = Vector3.normalize(offset)
	local forward = Vector3.normalize(Vector3.flat(Quaternion.forward(Unit.world_rotation(unit, 1))))
	if action.attack_type ~= "broadphase" and Vector3.dot(direction, forward) < (action.weapon_reach_cone or 0.75) then
		return false
	end
	local power = Managers.state.difficulty:get_minion_attack_power_level(breed, action.power_level_type or "melee")
	Attack.execute(
		vehicle.unit, profile or action.damage_profile,
		"power_level", power, "attacking_unit", unit, "hit_world_position", target,
		"hit_actor", vehicle.hit_actor, "attack_direction", direction,
		"attack_type", "melee", "damage_type", damage_type or action.damage_type
	)
	return true
end

Health.install = function (session)
	local hooked = setmetatable({}, { __mode = "k" })
	local function hook_file (path, callback)
		mod:hook_require(path, function (instance)
			if not hooked[instance] then
				hooked[instance] = true
				callback(instance)
			end
		end)
	end
	hook_file("scripts/utilities/attack/armor", function (Armor)
		mod:hook(Armor, "armor_type", function (func, unit, ...)
			if unit and getmetatable(ScriptUnit.has_extension(unit, "health_system")) == Health then
				-- Minion profiles only damage player armor; untyped props otherwise receive zero damage.
				return ArmorSettings.types.player
			end
			return func(unit, ...)
		end)
	end)
	hook_file("scripts/utilities/attack/damage", function (Damage)
		mod:hook(Damage, "deal_damage", function (func, unit, breed, attacker, owner, result, attack_type, profile, damage, ...)
			local health = ScriptUnit.has_extension(unit, "health_system")
			if getmetatable(health) == Health then
				if owner and Managers.player:player_by_unit(owner) or attacker and Managers.player:player_by_unit(attacker) then
					return 0
				end
				return health:add_damage(damage)
			end
			return func(unit, breed, attacker, owner, result, attack_type, profile, damage, ...)
		end)
	end)
	hook_file("scripts/extension_systems/locomotion/utilities/projectile_locomotion", function (ProjectileLocomotion)
		mod:hook(ProjectileLocomotion, "check_collision", function (func, unit, position, integration, bounce)
			local vehicle, occupant = session.for_unit(integration.owner_unit)
			if vehicle and not session.personal_weapons(occupant) and Collision.contains_unit(vehicle, unit) then
				return false
			end
			return func(unit, position, integration, bounce)
		end)
	end)
	hook_file("scripts/utilities/minion_attack", function (MinionAttack)
		mod:hook(MinionAttack, "melee", function (func, unit, breed, scratchpad, blackboard, target, action, physics, profile, damage_type, event)
			local vehicle, occupant = session.for_unit(target)
			if occupant and occupant.seat.protected then
				return melee_hit(vehicle, unit, action, profile, damage_type, event)
			end
			return func(unit, breed, scratchpad, blackboard, target, action, physics, profile, damage_type, event)
		end)
		mod:hook(MinionAttack, "sweep", function (
			func, unit, breed, node, scratchpad, blackboard, target, action, physics, cache, profile, damage_type, event, ignore_target
		)
			local hit = func(unit, breed, node, scratchpad, blackboard, target, action, physics, cache, profile, damage_type, event, ignore_target)
			local vehicle, occupant = session.for_unit(target)
			if occupant and occupant.seat.protected and not ignore_target and not cache[vehicle.unit] then
				local origin = Unit.world_position(unit, Unit.node(unit, node))
				local hull_hit = melee_hit(vehicle, unit, action, profile, damage_type, event, origin)
				cache[vehicle.unit] = hull_hit
				hit = hit or hull_hit
			end
			return hit
		end)
	end)
end

return Health
