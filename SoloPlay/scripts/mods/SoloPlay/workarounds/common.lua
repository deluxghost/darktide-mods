local mod = get_mod("SoloPlay")

-- when a colored outline is adding to an invalid unit, the game crashes
mod:hook(Unit, "set_vector3_for_material", function(func, unit, ...)
	if not Unit.alive(unit) then
		return
	end
	func(unit, ...)
end)
