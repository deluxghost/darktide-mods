local mod = get_mod("SoloPlay")
local HavocManager = require("scripts/managers/havoc/havoc_manager")

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
