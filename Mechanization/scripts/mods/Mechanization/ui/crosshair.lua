local mod = get_mod("Mechanization")
local Crosshair = require("scripts/ui/utilities/crosshair")
local VehicleCrosshair = {}

VehicleCrosshair.state = function (session, vehicle, occupant)
	local states = vehicle.type.crosshairs
	local selected
	for _, action in ipairs(occupant.seat.actions) do
		if session.occupants.action_owner(vehicle, action) == occupant then
			selected = selected or action
			if occupant.input.actions[action] then
				return states[action], action
			end
		end
	end
	return states[selected or "unarmed"], selected
end

VehicleCrosshair.install = function (session)
	mod:hook(CLASS.HudElementCrosshair, "_crosshair_settings", function (func, self)
		local vehicle, occupant = session.local_vehicle()
		if vehicle then
			local state = VehicleCrosshair.state(session, vehicle, occupant)
			return state
		end
		return func(self)
	end)
	mod:hook(CLASS.HudElementCrosshair, "_get_current_crosshair_type", function (func, self, settings)
		local vehicle, occupant = session.local_vehicle()
		if vehicle then
			local state = VehicleCrosshair.state(session, vehicle, occupant)
			return state.crosshair_type
		end
		return func(self, settings)
	end)
	mod:hook(Crosshair, "position", function (func, ...)
		local vehicle, occupant = session.local_vehicle()
		if not vehicle or session.personal_weapons(occupant) then
			return func(...)
		end
		return 0, 0
	end)
end

return VehicleCrosshair
