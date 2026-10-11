local mod = get_mod("Mechanization")
local PlayerDeath = require("scripts/utilities/player_death")
local Push = require("scripts/extension_systems/character_state_machine/character_states/utilities/push")
local Stun = require("scripts/utilities/attack/stun")
local Protection = {}

Protection.install = function (session)
	local attack_instances = setmetatable({}, { __mode = "k" })
	mod:hook_require("scripts/utilities/attack/attack", function (Attack)
		if attack_instances[Attack] then
			return
		end
		attack_instances[Attack] = true
		mod:hook(Attack, "execute", function (func, unit, profile, ...)
			if session.protected(unit) then
				return 0, "blocked", "negated", nil, false
			end
			return func(unit, profile, ...)
		end)
	end)
	mod:hook(PlayerDeath, "die", function (func, unit, despawn_time, attacker, reason)
		local _, occupant = session.for_unit(unit)
		if occupant then
			if occupant.seat.protected and reason ~= "kill_volume" then
				return
			end
			session.eject(occupant.peer, false)
		end
		return func(unit, despawn_time, attacker, reason)
	end)

	mod:hook(PlayerDeath, "knock_down", function (func, unit)
		if not session.protected(unit) then
			local _, occupant = session.for_unit(unit)
			if occupant then
				session.eject(occupant.peer, false)
			end
			return func(unit)
		end
	end)

	mod:hook(Push, "add", function (func, unit, ...)
		if not session.protected(unit) then
			return func(unit, ...)
		end
	end)

	mod:hook(Stun, "apply", function (func, unit, ...)
		if not session.protected(unit) then
			return func(unit, ...)
		end
	end)

	mod:hook(CLASS.PlayerUnitHealthExtension, "add_damage", function (func, self, ...)
		if session.protected(self._unit) then
			return 0
		end
		return func(self, ...)
	end)

	mod:hook(CLASS.PlayerUnitToughnessExtension, "add_damage", function (func, self, ...)
		if session.protected(self._unit) then
			return 0
		end
		return func(self, ...)
	end)

	mod:hook(CLASS.CharacterStateMachineExtension, "fixed_update", function (func, self, unit, ...)
		local _, occupant = session.for_unit(unit)
		if occupant then
			local data = ScriptUnit.extension(unit, "unit_data_system")
			local disabled = data:write_component("disabled_state_input")
			local catapulted = data:write_component("catapulted_state_input")
			local stun = data:write_component("stun_state_input")
			if occupant.seat.protected then
				disabled.wants_disable = false
				catapulted.new_input = false
				catapulted.velocity = Vector3.zero()
				stun.disorientation_type = "none"
				stun.push_direction = Vector3.zero()
			elseif disabled.wants_disable or catapulted.new_input or stun.disorientation_type ~= "none" then
				-- Release the seat before the original state machine enters its control animation.
				session.eject(occupant.peer, false)
			end
		end
		return func(self, unit, ...)
	end)
end

return Protection
