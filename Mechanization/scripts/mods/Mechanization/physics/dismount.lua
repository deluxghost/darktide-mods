local mod = get_mod("Mechanization")
local NavQueries = require("scripts/utilities/nav_queries")
local Collision = mod.load_module("physics/collision")
local Dismount = {}
local SEARCH_MARGIN = 24
local SEARCH_SPACING = 0.75
local MAX_SEARCH_NODES = 4096
local NAV_HEIGHT = 1
local GROUND_TOLERANCE = 0.25
local BORDER_MARGIN = 0.25
local PLAYER_MARGIN = 0.25
local EDGE_SAMPLES = 8
local NEIGHBORS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }

local function dangerous (position, height)
	local volumes = Managers.state.extension:system("volume_event_system")._level_volumes_by_name
	for name, volume in pairs(volumes) do
		if volume.type == "content/volume_types/player_instakill" then
			for _, level in ipairs(volume.levels) do
				for _, offset in ipairs({ 0.1, height * 0.5, height }) do
					if Level.is_point_inside_volume(level, name, position + Vector3.up() * offset) then
						return true
					end
				end
			end
		end
	end
	return Managers.state.extension:system("liquid_area_system"):is_position_in_liquid(position)
end

local function outside_vehicles (vehicles, position, radius, height)
	for _, vehicle in pairs(vehicles) do
		if not Collision.outside(vehicle, position, radius + PLAYER_MARGIN, height) then
			return false
		end
	end
	return true
end

local function separated (position, radius, reserved, unit)
	for _, other in ipairs(reserved) do
		if Vector3.distance(position, other.position:unbox()) < radius + other.radius + PLAYER_MARGIN then
			return false
		end
	end
	for _, player in pairs(Managers.player:players()) do
		local other = player.player_unit
		if other and other ~= unit and ALIVE[other] then
			local other_radius = Collision.player_footprint(other)
			if Vector3.distance(position, Unit.world_position(other, 1)) < radius + other_radius + PLAYER_MARGIN then
				return false
			end
		end
	end
	return true
end

local function validate (context, candidate)
	local position = NavQueries.position_on_mesh(context.nav_world, candidate, NAV_HEIGHT, NAV_HEIGHT, context.traverse)
	if not position or not outside_vehicles(context.vehicles, position, context.radius, context.height) then
		return
	end
	local hit, ground = PhysicsWorld.raycast(
		World.physics_world(context.vehicle.world), position + Vector3.up() * GROUND_TOLERANCE, Vector3.down(),
		GROUND_TOLERANCE * 2, "closest", "types", "statics", "collision_filter", "filter_player_mover"
	)
	if not hit or Vector3.distance(ground, position) > GROUND_TOLERANCE then
		return
	end
	if not Unit.mover_fits_at(context.occupant.unit, "default", ground) or dangerous(ground, context.height) then
		return
	end
	if not separated(ground, context.radius, context.reserved, context.occupant.unit) then
		return
	end
	for index = 1, EDGE_SAMPLES do
		local angle = index * math.pi * 2 / EDGE_SAMPLES
		local edge = position + Vector3(math.cos(angle), math.sin(angle), 0) * (context.radius + BORDER_MARGIN)
		edge = NavQueries.position_on_mesh(context.nav_world, edge, NAV_HEIGHT, NAV_HEIGHT, context.traverse)
		if not edge
			or not GwNavQueries.raycango(context.nav_world, position, edge, context.traverse)
			or dangerous(edge, context.height)
		then
			return
		end
	end
	return ground
end

local function expand (context, node, offset, search)
	local x, y = node.x + offset[1], node.y + offset[2]
	local from = node.position:unbox()
	local candidate = context.anchor + Vector3(x * SEARCH_SPACING, y * SEARCH_SPACING, 0)
	candidate.z = from.z
	if Vector3.distance(candidate, context.anchor) > search.limit then
		return
	end
	local point = NavQueries.position_on_mesh(context.nav_world, candidate, NAV_HEIGHT, NAV_HEIGHT, context.traverse)
	if not point then
		return
	end
	local key = string.format("%d:%d:%d", x, y, math.floor(point.z / NAV_HEIGHT))
	if search.visited[key] or not GwNavQueries.raycango(context.nav_world, from, point, context.traverse) then
		return
	end
	if dangerous(point, context.height) then
		return
	end
	-- Reaching the hull boundary represents getting out of the vehicle, not walking through its decorative mesh.
	local outside_hull = Collision.outside(context.vehicle, point, context.radius + PLAYER_MARGIN, context.height)
	if outside_hull and not Unit.mover_fits_at(context.occupant.unit, "default", point) then
		return
	end
	for _, other in pairs(context.vehicles) do
		if other ~= context.vehicle and not Collision.outside(other, point, context.radius, context.height) then
			return
		end
	end
	search.visited[key] = true
	search.queue[#search.queue + 1] = { position = Vector3Box(point), x = x, y = y }
end

local function find_position (context)
	local _, half = context.vehicle.type.controller.bounds(context.vehicle)
	local search = {
		limit = math.max(half.x, half.y) + SEARCH_MARGIN,
		queue = { { position = Vector3Box(context.anchor), x = 0, y = 0 } },
		visited = {},
	}
	local index = 1
	-- Connected navmesh edges can lead around corners but never jump into a disconnected nearby room.
	while index <= #search.queue and index <= MAX_SEARCH_NODES do
		local node = search.queue[index]
		local point = validate(context, node.position:unbox())
		if point then
			return point
		end
		for _, offset in ipairs(NEIGHBORS) do
			expand(context, node, offset, search)
		end
		index = index + 1
	end
end

Dismount.plan = function (vehicle, occupants, vehicles)
	local reserved, positions = {}, {}
	local nav_world = Managers.state.nav_mesh:nav_world()
	for _, occupant in ipairs(occupants) do
		if ALIVE[occupant.unit] then
			local navigation = ScriptUnit.extension(occupant.unit, "navigation_system")
			local traverse = navigation:traverse_logic()
			local anchor = NavQueries.position_on_mesh(nav_world, vehicle.position:unbox(), NAV_HEIGHT, NAV_HEIGHT, traverse)
			if not anchor then
				return
			end
			local radius = Collision.player_footprint(occupant.unit)
			local first = ScriptUnit.extension(occupant.unit, "first_person_system")
			local context = {
				vehicle = vehicle,
				occupant = occupant,
				vehicles = vehicles,
				nav_world = nav_world,
				traverse = traverse,
				anchor = anchor,
				radius = radius,
				height = first:default_height("default") + radius,
				reserved = reserved,
			}
			local point = find_position(context)
			if not point then
				return
			end
			positions[occupant.peer or occupant.unit] = { point.x, point.y, point.z }
			reserved[#reserved + 1] = { position = Vector3Box(point), radius = radius }
		end
	end
	return positions
end

Dismount.removal = function (vehicle)
	-- Removing the hull makes its current position available to all occupants.
	local point = vehicle.position:unbox()
	local positions = {}
	for _, occupant in pairs(vehicle.occupants) do
		if ALIVE[occupant.unit] then
			positions[occupant.peer] = { point.x, point.y, point.z }
		end
	end
	return positions
end

return Dismount
