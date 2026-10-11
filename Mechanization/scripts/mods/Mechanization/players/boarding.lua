local Boarding = {}
local REACH = 4

Boarding.target = function (vehicles, player)
	local unit = player and player.player_unit
	if not unit or not ALIVE[unit] then
		return
	end
	local first_person = ScriptUnit.extension(unit, "unit_data_system"):read_component("first_person")
	local position = first_person.position
	local direction = Quaternion.forward(first_person.rotation)
	local world = Managers.world:world("level_world")
	local hits = PhysicsWorld.raycast(
		World.physics_world(world), position, direction, REACH,
		"all", "collision_filter", "filter_player_character_shooting_raycast"
	)
	local nearest = REACH
	local hit_unit
	local characters = {}
	for _, other in pairs(Managers.player:players()) do
		if other.player_unit then
			characters[other.player_unit] = true
		end
	end
	for _, hit in ipairs(hits or {}) do
		local candidate = Actor.unit(hit[4])
		if not characters[candidate] and hit[2] < nearest then
			nearest = hit[2]
			hit_unit = candidate
		end
	end
	for _, vehicle in pairs(vehicles) do
		if vehicle.unit == hit_unit then
			return vehicle
		end
	end
end

Boarding.reset = function ()
	Boarding.vehicle = nil
end

return Boarding
