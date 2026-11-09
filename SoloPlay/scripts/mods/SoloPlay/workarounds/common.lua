local mod = get_mod("SoloPlay")

-- Boss injections must mutate mission-owned data, not a shared mutator template.
mod:hook("MinionSpawnManager", "mutator_breed_init", function (func, self, mutator_context)
	if mod.has_local_gameplay_authority() then
		mutator_context = table.clone(mutator_context)
	end
	return func(self, mutator_context)
end)

mod:hook("MinionSpawnManager", "inject_replacement_breeds", function (func, self, breeds_to_add)
	if mod.has_local_gameplay_authority() and not self._mutator_breed_data then
		breeds_to_add = table.clone(breeds_to_add)
	end
	return func(self, breeds_to_add)
end)

local TORMENT_SPAWN_CHANCES = { 0.15, 0.35, 1 }

mod:hook("MutatorGameplayLiveEventTorment", "_on_daemonhost_killed_event", function (func, self, unit, breed)
	if not mod.has_local_gameplay_authority() then
		return func(self, unit, breed)
	end
	if self._torment_spawned or not breed or breed.name ~= "chaos_daemonhost" or self:_event_reached_max_tier() then
		return
	end

	-- Native init resets this counter; the module's consumable probability queue survives missions.
	self._daemonhost_kills = self._daemonhost_kills + 1
	local chance = TORMENT_SPAWN_CHANCES[math.min(self._daemonhost_kills, #TORMENT_SPAWN_CHANCES)]
	if chance <= math.random() then
		return
	end

	Managers.event:trigger("on_torment_daemonhost_should_spawn_event")
end)

-- when a colored outline is adding to an invalid unit, the game crashes
mod:hook(Unit, "set_vector3_for_material", function(func, unit, ...)
	if not Unit.alive(unit) then
		return
	end
	func(unit, ...)
end)
