local mod = get_mod("Mechanization")

local types = {
	mod.load_module("vehicles/lionheart/definition"),
	mod.load_module("vehicles/valkyrie/definition"),
	mod.load_module("vehicles/wolfquad/definition"),
}

local by_id = {}
for _, vehicle_type in ipairs(types) do
	assert(not by_id[vehicle_type.id], "Duplicate vehicle type: " .. vehicle_type.id)
	by_id[vehicle_type.id] = vehicle_type
end

return {
	list = types,
	by_id = by_id,
}
