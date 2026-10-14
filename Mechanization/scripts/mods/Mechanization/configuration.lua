local mod = get_mod("Mechanization")
local Configuration = {}

Configuration.vehicles = {
	{
		id = "lionheart",
		values = { health = 50000, main_damage = 4000, front_damage = 1200 },
		weapons = { "main", "front" },
	},
	{
		id = "valkyrie",
		values = { health = 35000, laser_damage = 800, rocket_damage = 3600 },
		weapons = { "laser", "rocket" },
	},
	{ id = "wolfquad", values = { health = 2000 }, weapons = {} },
	{ id = "goliath", values = { health = 15000 }, weapons = {} },
}

local by_id = {}
for _, vehicle in ipairs(Configuration.vehicles) do
	by_id[vehicle.id] = vehicle
end

Configuration.valid_number = function (value, positive)
	return type(value) == "number" and value < math.huge and (positive and value > 0 or not positive and value >= 0)
end

Configuration.valid_text = function (value, positive)
	return type(value) == "string" and Configuration.valid_number(tonumber(value), positive)
end

Configuration.validate = function (id, values)
	local vehicle = assert(by_id[id], "Unknown vehicle configuration")
	assert(type(values) == "table", "Invalid vehicle configuration")
	for key in pairs(vehicle.values) do
		assert(Configuration.valid_number(values[key], key == "health"), "Invalid vehicle value: " .. key)
	end
end

Configuration.read = function (id)
	local vehicle = assert(by_id[id], "Unknown vehicle configuration")
	if not mod:get("custom_vehicle_properties") then
		return table.clone(vehicle.values)
	end
	local values = {}
	for key in pairs(vehicle.values) do
		local value = mod:get(id .. "_" .. key)
		assert(Configuration.valid_text(value, key == "health"), "Invalid vehicle setting: " .. id .. "_" .. key)
		values[key] = tonumber(value)
	end
	return values
end

Configuration.cooldown = function ()
	local value = mod:get("spawn_cooldown")
	assert(Configuration.valid_number(value), "Invalid spawn cooldown")
	return value
end

return Configuration
