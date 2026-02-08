local mod = get_mod("SoloPlay")
local GameModeExtensionHavoc = require("scripts/managers/game_mode/game_mode_extensions/game_mode_extension_havoc")
local MechanismOnboarding = require("scripts/managers/mechanism/mechanisms/mechanism_onboarding")
local MutatorMonsterSpawner = require("scripts/managers/mutator/mutators/mutator_monster_spawner")

local LiquidArea = require("scripts/extension_systems/liquid_area/utilities/liquid_area")
local LiquidAreaTemplates = require("scripts/settings/liquid_area/liquid_area_templates")
local HavocMutatorLocalSettings = require("scripts/settings/havoc/havoc_mutator_local_settings")

-- allow starting havoc game without any modifiers
mod:hook(GameModeExtensionHavoc, "_initialize_modifiers", function (func, self, havoc_modifiers)
	if not havoc_modifiers or #havoc_modifiers < 1 or havoc_modifiers[1].level == nil then
		Log.info("GameModeExtensionHavoc", "No modifiers found")
		return
	end
	return func(self, havoc_modifiers)
end)

-- when a colored outline is adding to an invalid unit, the game crashes
mod:hook(Unit, "set_vector3_for_material", function(func, unit, ...)
	if not Unit.alive(unit) then
		return
	end
	func(unit, ...)
end)

-- shooting range with circumstances
mod:hook_safe(MechanismOnboarding, "init", function (self, ...)
	local context = self._context
	local data = self._mechanism_data

	data.circumstance_name = context.circumstance_name or data.circumstance_name
	data.side_mission = context.side_mission or data.side_mission
	data.challenge = context.challenge or data.challenge
	data.resistance = context.resistance or data.resistance
	data.pacing_control = context.pacing_control or data.pacing_control
	data.havoc_data = context.havoc_data or data.havoc_data
end)

-- fix boss mutator in unsupported missions
mod:hook_safe(MutatorMonsterSpawner, "init", function (self, ...)
	self._dirty_spawn_locations = self._dirty_spawn_locations or {}
	self._num_to_spawn = self._num_to_spawn or 0
end)

-- fix arbites execution order keystone crash
mod:hook_require("scripts/settings/buff/buff_templates", function (templates)
	local keystone = templates.adamant_execution_order
	if not keystone.__soloplay_modified then
		local orig_update_func = keystone.update_func
		keystone.update_func = function (template_data, template_context, dt, t)
			--------
			-- local player_unit = template_context.unit
			-- local player_rotation = template_data.first_person_component.rotation
			-- local player_horizontal_look_direction = Vector3.normalize(Vector3.flat(Quaternion.forward(player_rotation)))
			-- local player_position = POSITION_LOOKUP[player_unit]
			-- local broadphase_distance = template_data.distance
			--------
			for marked_unit, t in pairs(template_data.targets) do
				if ALIVE[marked_unit] and not BLACKBOARDS[marked_unit] then
					template_data.targets[marked_unit] = nil
					--------
					-- local marked_unit_position = POSITION_LOOKUP[marked_unit]
					-- local distance_sq = Vector3.distance_squared(player_position, marked_unit_position)
					-- local check_distance = broadphase_distance * broadphase_distance
					-- if check_distance < distance_sq then
					-- 	local direction_to_player = Vector3.normalize(marked_unit_position - player_position)
					-- 	local dot = Vector3.dot(player_horizontal_look_direction, direction_to_player)
					-- 	if dot < 0 then
					-- 		mod:notify("arbites keystone workaround triggered")
					-- 	end
					-- end
					--------
				end
			end
			orig_update_func(template_data, template_context, dt, t)
		end
		keystone.__soloplay_modified = true
	end
end)

-- fix for rotten armour crash on exit
-- basically replaced the position check to avoid a UNIT_POSITION[] lookup fail. Update this function in future updates if the function changes

local rotten_armor_data = HavocMutatorLocalSettings.mutator_havoc_rotten_armor.buff_settings

local function _on_rotten_armor_death(template_data, template_context)
	local unit = template_context.unit
	local nav_world = template_data.nav_world
	local position = Unit.world_position(unit, 1)

	if not position then
		return
	end

	local node_position = position + Vector3(0, 0, 0.25)
	local fx_system = Managers.state.extension:system("fx_system")
	local rotation = Unit.local_rotation(unit, 1)

	fx_system:trigger_vfx(rotten_armor_data.vfx_name, node_position, rotation)
	fx_system:trigger_wwise_event(rotten_armor_data.sfx_death_name, position)
	LiquidArea.try_create(position, Vector3.down(), nav_world, LiquidAreaTemplates.rotten_armor, nil, nil, true)
end

mod:hook_require("scripts/settings/buff/havoc_buff_templates", function(templates)
	templates.mutator_rotten_armor.stop_func = function (template_data, template_context)
		if template_context.is_server then
			_on_rotten_armor_death(template_data, template_context)
		end
	end
end)
