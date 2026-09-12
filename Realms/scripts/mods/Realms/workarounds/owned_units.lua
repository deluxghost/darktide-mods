local mod = get_mod("Realms")
local PackageSynchronizerHost = require("scripts/loading/package_synchronizer_host")

local OwnedUnits = {}

local function remove_stale_units(player, player_unit_spawn_manager)
	local owned_units = player.owned_units
	local removed = 0

	for unit in pairs(owned_units) do
		if unit ~= player.player_unit and not Unit.alive(unit) then
			if player_unit_spawn_manager:owner(unit) == player then
				player_unit_spawn_manager:relinquish_unit_ownership(unit)
			else
				-- Units from a previous world are absent from the current ownership map.
				owned_units[unit] = nil
			end

			removed = removed + 1
		end
	end

	if removed > 0 then
		mod:info("Removed %d stale owned unit references for player %s", removed, player:unique_id())
	end
end

function OwnedUnits.install(Session)
	mod:hook(PackageSynchronizerHost, "_cleanup_owned_units", function (func, self, player)
		local player_unit_spawn_manager = Managers.state.player_unit_spawn

		if Session.is_active_host() and Managers.state.unit_spawner and player_unit_spawn_manager then
			remove_stale_units(player, player_unit_spawn_manager)
		end

		return func(self, player)
	end)
end

return OwnedUnits
