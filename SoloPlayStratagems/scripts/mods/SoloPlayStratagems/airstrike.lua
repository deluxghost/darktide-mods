-- reference: scripts/managers/game_mode/game_modes/expedition/expedition_logic_server.lua
local mod = get_mod("SoloPlayStratagems")
local MasterItems = require("scripts/backend/master_items")
local ProjectileLocomotionSettings = require("scripts/settings/projectile_locomotion/projectile_locomotion_settings")
local ProjectileTemplates = require("scripts/settings/projectile/projectile_templates")
local Vo = require("scripts/utilities/vo")
local locomotion_states = ProjectileLocomotionSettings.states

local AIRSTRIKE_LEVELS = {
	bomb = "content/levels/expeditions/airstrikes/airstrikes_01/world",
	supply = "content/levels/expeditions/airstrikes/airstrikes_02/world",
}

local state = mod:persistent_table("airstrike")

state.airstrike_levels = state.airstrike_levels or {}
state.airstrike_levels_to_despawn = state.airstrike_levels_to_despawn or {}
state.airstrike_bomb_spawning = state.airstrike_bomb_spawning or {}
state.airstrike_supply_spawning = state.airstrike_supply_spawning or {}

mod.airstrike_register_events = function ()
	local event_manager = Managers.event

	if not event_manager then
		return
	end

	if state.registered_events and state.registered_event_manager == event_manager then
		return
	end

	event_manager:register(mod, "event_expedition_smoke_grenade_airstrike_call_in", "airstrike_smoke_grenade_airstrike_call_in")
	event_manager:register(mod, "event_airstrike_drop_bomb", "airstrike_drop_bomb")
	event_manager:register(mod, "event_airstrike_drop_supply", "airstrike_drop_supply")
	event_manager:register(mod, "event_airstrike_done", "airstrike_done")

	state.registered_events = true
	state.registered_event_manager = event_manager
end

mod.airstrike_unregister_events = function ()
	local event_manager = state.registered_event_manager or Managers.event

	if not state.registered_events or not event_manager then
		return
	end

	event_manager:unregister(mod, "event_expedition_smoke_grenade_airstrike_call_in")
	event_manager:unregister(mod, "event_airstrike_drop_bomb")
	event_manager:unregister(mod, "event_airstrike_drop_supply")
	event_manager:unregister(mod, "event_airstrike_done")

	state.registered_events = false
	state.registered_event_manager = nil
end

local function _despawn_airstrike_level(level)
	if not state.airstrike_levels[level] then
		return
	end

	state.airstrike_levels[level] = nil
	state.airstrike_levels_to_despawn[level] = nil

	Level.trigger_level_shutdown(level)

	local level_units = Level.units(level, true)
	local extension_manager = Managers.state.extension

	if extension_manager then
		extension_manager:unregister_units(level_units, #level_units)
	end

	local networked_flow_state_manager = Managers.state.networked_flow_state

	if networked_flow_state_manager then
		networked_flow_state_manager:unregister_level(level)
	end

	local network_story_manager = Managers.state.network_story

	if network_story_manager then
		network_story_manager:unregister_level(level)
	end

	local world = mod.game_world()

	if world then
		World.destroy_level(world, level)
	end
end

mod.airstrike_destroy = function ()
	for level, _ in pairs(state.airstrike_levels) do
		_despawn_airstrike_level(level)
	end

	table.clear(state.airstrike_levels)
	table.clear(state.airstrike_levels_to_despawn)
	table.clear(state.airstrike_bomb_spawning)
	table.clear(state.airstrike_supply_spawning)
end

local function _spawn_airstrike_bomb(spawn_data)
	local unit_spawner_manager = Managers.state.unit_spawner
	if not unit_spawner_manager then
		return
	end

	local forward_rotation = Quaternion.flat_no_roll(spawn_data.boxed_rotation:unbox())
	local fwd = Quaternion.forward(forward_rotation)
	local right = Quaternion.right(forward_rotation)
	local up = Quaternion.up(forward_rotation)
	local offset = fwd * 2.75 + right * 0 + up * -0.15
	local position = spawn_data.boxed_position:unbox() + offset
	local direction = Vector3.down()
	local check_vector = Vector3.dot(direction, Vector3.right()) < 1 and Vector3.right() or Vector3.forward()
	local start_axis = Vector3.cross(direction, check_vector)
	local angle_distribution = math.pi
	local random_start_rotation = math.pi * 2 * math.random()
	local projectile_template = ProjectileTemplates.expedition_airstrike_nuke
	local material
	local item_name = "content/items/weapons/player/ranged/bullets/attack_valkyrie_bomb"
	local item_definitions = MasterItems.get_cached()
	local item = item_definitions[item_name]
	if not item then
		return
	end

	local starting_state = locomotion_states.manual_physics
	local max = math.pi / 10
	local angular_velocity = Vector3(math.random() * max, math.random() * max, math.random() * max)
	local random_position = position + Quaternion.right(forward_rotation) * math.random_range(2, -2)
	local angle = angle_distribution + random_start_rotation + math.lerp(-angle_distribution * 0.5, angle_distribution * 0.5, math.random())
	local random_rotation = Quaternion.axis_angle(direction, angle)
	local flat_direction = Quaternion.rotate(random_rotation, start_axis)
	local random_alpha = math.random_range(0.9, 0.975)
	local random_direction = Vector3.lerp(flat_direction, direction, random_alpha) or Vector3.down()
	local speed = math.random_range(50, 60)
	local unit_template_name = projectile_template.unit_template_name or "item_projectile"

	unit_spawner_manager:spawn_network_unit(nil, unit_template_name, random_position, random_rotation, material, item, projectile_template, starting_state, random_direction, speed, angular_velocity)
end

mod.airstrike_update = function ()
	if not state.registered_events then
		mod.airstrike_register_events()
	end

	if not state.registered_events or not mod.is_server() then
		return
	end

	for level, _ in pairs(state.airstrike_levels_to_despawn) do
		_despawn_airstrike_level(level)
	end

	local next_bomb_to_spawn = table.remove(state.airstrike_bomb_spawning)
	if next_bomb_to_spawn then
		_spawn_airstrike_bomb(next_bomb_to_spawn)
	end

	local next_supply_to_spawn = table.remove(state.airstrike_supply_spawning)
	if next_supply_to_spawn then
		local unit_spawner_manager = Managers.state.unit_spawner
		if not unit_spawner_manager then
			return
		end

		local position = next_supply_to_spawn.boxed_position:unbox() + Vector3(0, 0, -5)
		local rotation = Quaternion.axis_angle(Vector3.forward(), 1)
		local projectile_unit_name = "content/environment/artsets/imperial/expeditions/airstrike/supply_drop/stock_pallet_crates_supply_drop_01"
		local random_direction = Vector3(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
		local force_direction_boxed = Vector3Box(Vector3.normalize(random_direction))
		local unit_template_name = "expedition_airstrike_supply"

		unit_spawner_manager:spawn_network_unit(projectile_unit_name, unit_template_name, position, rotation, nil, force_direction_boxed)
	end
end

mod.airstrike_smoke_grenade_airstrike_call_in = function (self, unit, position, direction)
	if not mod.is_server() or not direction then
		return
	end

	local world = mod.game_world()
	local level_path = AIRSTRIKE_LEVELS.bomb
	if not world or not level_path then
		return
	end

	local flat_dir = Vector3(direction.x, direction.y, 0)
	flat_dir = Vector3.normalize(flat_dir) * -1

	local rotation = Quaternion.look(flat_dir, Vector3.up())
	local level = World.spawn_level(world, level_path, position or Vector3(0, 0, 0), rotation, 1)

	Level.set_data(level, "runtime_loaded_level", true)

	local level_units = Level.units(level, true)

	Level.trigger_unit_spawned(level)

	local extension_manager = Managers.state.extension
	if extension_manager then
		extension_manager:add_and_register_units(world, level_units, nil, nil)
	end

	Level.trigger_event(level, "expedition_play_airstrike")

	local uuid = math.uuid()

	Level.set_data(level, "uuid", uuid)
	state.airstrike_levels[level] = uuid

	Vo.mission_giver_mission_info_vo("selected_voice", "pilot_a", "expeditions_valkyrie_support_a")
end

mod.airstrike_drop_bomb = function (self, origin_unit)
	if not mod.is_server() then
		return
	end

	state.airstrike_bomb_spawning[#state.airstrike_bomb_spawning + 1] = {
		boxed_position = Vector3Box(Unit.world_position(origin_unit, 1)),
		boxed_rotation = QuaternionBox(Unit.world_rotation(origin_unit, 1)),
	}
end

mod.airstrike_drop_supply = function (self, origin_unit)
	if not mod.is_server() then
		return
	end

	state.airstrike_supply_spawning[#state.airstrike_supply_spawning + 1] = {
		boxed_position = Vector3Box(Unit.world_position(origin_unit, 1)),
		boxed_rotation = QuaternionBox(Unit.world_rotation(origin_unit, 1)),
	}
end

mod.airstrike_done = function (self, level)
	if level then
		state.airstrike_levels_to_despawn[level] = true
	end
end
