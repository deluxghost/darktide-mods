local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Damage = require("scripts/utilities/attack/damage")
local DamageProfileTemplates = require("scripts/settings/damage/damage_profile_templates")
local Contacts = {}
local MIN_ADVANCE = 0.0001

local function distance (vehicle, position, origin, rotation, radius, height)
	local center, half = vehicle.type.controller.bounds(vehicle)
	local inverse = Quaternion.inverse(rotation)
	local local_position = Quaternion.rotate(inverse, position + Vector3.up() * height * 0.5 - origin) - center
	local upright = Quaternion.rotate(inverse, Vector3.up())
	local extent = half + Vector3(math.abs(upright.x), math.abs(upright.y), math.abs(upright.z)) * height * 0.5
	extent = extent + Vector3(radius, radius, 0)
	local x, y, z = math.abs(local_position.x), math.abs(local_position.y), math.abs(local_position.z)
	local gap = math.max(x - extent.x, y - extent.y, z - extent.z)
	return gap, (x / extent.x)^2 + (y / extent.y)^2 + (z / extent.z)^2
end

local function candidates (vehicle, origin, rotation, destination, heading)
	local settings = vehicle.type.contacts
	local center, half = vehicle.type.controller.bounds(vehicle)
	local radius = Vector3.length(center) + Vector3.length(half) + settings.contact_margin + Vector3.distance(origin, destination)
	local system = Managers.state.extension:system("broadphase_system")
	local units = {}
	local count = system.broadphase.query(system.broadphase, origin, radius, units, { "villains" })
	local contacts = {}
	for index = 1, count do
		local unit = units[index]
		if HEALTH_ALIVE[unit] and not Collision.contains_player(vehicle, unit) then
			local data = ScriptUnit.extension(unit, "unit_data_system")
			local breed = data:breed()
			local position = Unit.world_position(unit, 1)
			local footprint = breed.broadphase_radius
			local height = breed.base_height
			local before, previous_depth = distance(vehicle, position, origin, rotation, footprint, height)
			local after, depth = distance(vehicle, position, destination, heading, footprint, height)
			local advancing = after < before - MIN_ADVANCE
				or math.abs(after - before) <= MIN_ADVANCE and depth < previous_depth - MIN_ADVANCE
			if after <= settings.contact_margin and advancing then
				contacts[#contacts + 1] = { unit = unit, breed = breed }
			end
		end
	end
	return contacts
end

Contacts.resistance = function (vehicle, destination, rotation)
	local settings = vehicle.type.contacts
	if not settings then
		return 1
	end
	local origin = vehicle.position:unbox()
	local contacts = candidates(vehicle, origin, Unit.world_rotation(vehicle.unit, 1), destination, rotation)
	local multiplier = 1
	for _, contact in ipairs(contacts) do
		local breed = contact.breed
		local category = breed.is_boss and "boss" or breed.tags.ogryn and "ogryn" or breed.tags.elite and "elite" or "ordinary"
		multiplier = math.min(multiplier, settings.speed_multiplier[category])
	end
	return multiplier
end

Contacts.update = function (vehicle, origin, rotation, time)
	local settings = vehicle.type.contacts
	if not settings then
		return
	end
	local contacts = candidates(vehicle, origin, rotation, vehicle.position:unbox(), Unit.world_rotation(vehicle.unit, 1))
	vehicle.contact_ticks = vehicle.contact_ticks or {}
	local driver
	for _, occupant in pairs(vehicle.occupants) do
		if occupant.seat.movement then
			driver = occupant.unit
			break
		end
	end
	if not driver then
		return
	end
	for unit, ready_at in pairs(vehicle.contact_ticks) do
		if time >= ready_at then
			vehicle.contact_ticks[unit] = nil
		end
	end
	for _, contact in ipairs(contacts) do
		local unit = contact.unit
		if not vehicle.contact_ticks[unit] then
			vehicle.contact_ticks[unit] = time + settings.tick_interval
			local position = Unit.world_position(unit, 1)
			local movement = vehicle.position:unbox() - origin
			local direction = Vector3.length_squared(movement) > MIN_ADVANCE^2 and Vector3.normalize(movement)
				or Vector3.normalize(position + Vector3.up() * contact.breed.base_height * 0.5 - origin)
			local health = ScriptUnit.extension(unit, "health_system")
			local result = health:current_health() <= settings.damage and "died" or "damaged"
			-- Apply a fixed amount before armor scaling; all enemy classes use the same crushing damage.
			local damage = Damage.deal_damage(
				unit, contact.breed, driver, driver, result, "melee", DamageProfileTemplates.default,
				settings.damage, 0, 0, nil, direction, "torso", nil, false, "physical", position, nil, false, 0
			)
			result = health:health_depleted() and "died" or "damaged"
			Managers.state.attack_report:add_attack_result(
				DamageProfileTemplates.default, unit, driver, direction, position, false, damage, result, "melee", "full", false
			)
			if HEALTH_ALIVE[unit] then
				local locomotion = ScriptUnit.extension(unit, "locomotion_system")
				locomotion:set_external_velocity(direction * settings.push_speed)
			end
		end
	end
end

return Contacts
