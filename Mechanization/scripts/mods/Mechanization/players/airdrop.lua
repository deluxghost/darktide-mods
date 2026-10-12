local mod = get_mod("Mechanization")
local PlayerMovement = require("scripts/utilities/player_movement")
local Fall = require("scripts/extension_systems/character_state_machine/character_states/utilities/fall")
local Airdrop = { units = {} }

Airdrop.teleport = function (player, point, descent_speed)
	local position = Vector3Box(Vector3(unpack(point)))
	Managers.state.game_mode:register_physics_safe_callback(function ()
		local unit = player.player_unit
		if not ALIVE[unit] then
			return
		end
		PlayerMovement.teleport_fixed_update(unit, position:unbox())
		local data = ScriptUnit.extension(unit, "unit_data_system")
		local inair = data:write_component("inair_state")
		inair.on_ground, inair.standing_frames = false, 0
		Airdrop.units[unit] = descent_speed
	end)
end

Airdrop.update = function ()
	for unit in pairs(Airdrop.units) do
		if not HEALTH_ALIVE[unit] then
			Airdrop.units[unit] = nil
		else
			local data = ScriptUnit.extension(unit, "unit_data_system")
			local inair = data:write_component("inair_state")
			local locomotion = data:read_component("locomotion")
			inair.fell_from_height = locomotion.position.z
			if inair.on_ground or inair.standing_frames > 0 then
				Airdrop.units[unit] = nil
			end
		end
	end
end

Airdrop.install = function ()
	mod:hook(Fall, "check_damage", function (func, unit, ...)
		if Airdrop.units[unit] then
			return
		end
		return func(unit, ...)
	end)
	mod:hook(CLASS.PlayerUnitLocomotionExtension, "_update_script_driven_movement", function (func, self, unit, dt, t, locomotion, steering, position, falling, on_ground, mover)
		local descent = Airdrop.units[unit]
		if descent and falling then
			local velocity = locomotion.velocity_current
			velocity.z = math.max(velocity.z, -descent + self._constants.gravity * dt)
			locomotion.velocity_current = velocity
		end
		return func(self, unit, dt, t, locomotion, steering, position, falling, on_ground, mover)
	end)
end

return Airdrop
