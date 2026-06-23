local mod = get_mod("SoloPlay")
local GameModeExtensionHavoc = require("scripts/managers/game_mode/game_mode_extensions/game_mode_extension_havoc")
local MechanismOnboarding = require("scripts/managers/mechanism/mechanisms/mechanism_onboarding")
local MutatorSpawner = require("scripts/managers/mutator/mutators/mutator_spawner")
local MutatorMonsterSpawner = require("scripts/managers/mutator/mutators/mutator_monster_spawner")

-- allow starting havoc game without any modifiers
mod:hook(GameModeExtensionHavoc, "_initialize_modifiers", function (func, self, havoc_modifiers)
	if not havoc_modifiers or #havoc_modifiers < 1 or havoc_modifiers[1].level == nil then
		Log.info("GameModeExtensionHavoc", "No modifiers found")
		return
	end
	return func(self, havoc_modifiers)
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

-- fix spawner mutator in unsupported missions e.g. shooting range
mod:hook_safe(MutatorMonsterSpawner, "init", function (self, ...)
	self._dirty_spawn_locations = self._dirty_spawn_locations or {}
	self._num_to_spawn = self._num_to_spawn or 0
end)

mod:hook_safe(MutatorSpawner, "_setup", function (self)
	self._dirty_spawn_locations = self._dirty_spawn_locations or {}
	self._num_to_spawn = self._num_to_spawn or 0
end)

mod:hook_require("scripts/settings/mutator/mutator_templates", function (templates)
	for name, template in pairs(templates) do
		if template.class == "scripts/managers/mutator/mutators/mutator_spawner" and not template.__soloplay_modified then
			local orig_spawn_locations = template.spawn_locations
			template.spawn_locations = function ()
				local mission_name
				local game_mode_name = Managers.state.game_mode:game_mode_name()
				if game_mode_name == "expedition" then
					mission_name = Managers.state.game_mode:get_current_level_name()
				else
					mission_name = Managers.state.mission:mission_name()
				end
				if mission_name == "tg_shooting_range" then
					return {}
				end
				return orig_spawn_locations()
			end
			template.__soloplay_modified = true
		end
	end
end)

-- avoid running death side effects while gameplay cleanup destroys minion buff extensions
local function _skip_stop_on_extension_destroyed(templates, template_name)
	local template = templates[template_name]
	local stop_func = template.stop_func

	template.stop_func = function (template_data, template_context, extension_destroyed)
		if extension_destroyed then
			return
		end

		return stop_func(template_data, template_context, extension_destroyed)
	end
end

mod:hook_require("scripts/settings/buff/havoc_buff_templates", function(templates)
	_skip_stop_on_extension_destroyed(templates, "havoc_bolstering")
	_skip_stop_on_extension_destroyed(templates, "havoc_corrupted_enemies")
	_skip_stop_on_extension_destroyed(templates, "havoc_sticky_poxburster")
	_skip_stop_on_extension_destroyed(templates, "mutator_rotten_armor")
end)
