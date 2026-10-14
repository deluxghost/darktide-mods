local mod = get_mod("Mechanization")
local Surfaces = mod.load_module("physics/surfaces")
local PlayerMovement = require("scripts/utilities/player_movement")
local Teleport = {}

Teleport.player = function (player, point, frame)
	if not frame then
		PlayerMovement.teleport(player, Vector3(unpack(point)))
		return
	end
	local unit = player.player_unit
	Managers.state.game_mode:register_physics_safe_callback(function ()
		if ALIVE[unit] then
			PlayerMovement.teleport_fixed_update(unit, Surfaces.position(frame))
		end
	end)
end

return Teleport
