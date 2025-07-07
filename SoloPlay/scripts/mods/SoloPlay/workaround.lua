local mod = get_mod("SoloPlay")
local HavocManager = require("scripts/managers/havoc/havoc_manager")
local MechanismOnboarding = require("scripts/managers/mechanism/mechanisms/mechanism_onboarding")
local MutatorMonsterSpawner = require("scripts/managers/mutator/mutators/mutator_monster_spawner")

-- allow starting havoc game without any modifiers
mod:hook(HavocManager, "_initialize_modifiers", function (func, self, havoc_data)
	local havoc_modifiers = havoc_data.modifiers
	if not havoc_modifiers or #havoc_modifiers < 1 or havoc_modifiers[1].level == nil then
		Log.info("HavocManager", "No modifiers found")
		return
	end
	return func(self, havoc_data)
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
