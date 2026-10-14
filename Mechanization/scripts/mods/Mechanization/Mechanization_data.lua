local mod = get_mod("Mechanization")
local Configuration = mod:io_dofile("Mechanization/scripts/mods/Mechanization/configuration")

local function number_input (id, title, description, default, positive)
	return {
		setting_id = id,
		type = "text",
		title = title,
		tooltip = description,
		default_value = tostring(default),
		validate = function (value)
			return Configuration.valid_text(value, positive)
		end,
	}
end

local widgets = {
	{
		setting_id = "enabled",
		type = "checkbox",
		default_value = true,
	},
	{
		setting_id = "spawn_cooldown",
		type = "numeric",
		tooltip = "spawn_cooldown_description",
		default_value = 0,
		range = {0, 600},
	},
}
local custom_properties = {
	setting_id = "custom_vehicle_properties",
	type = "checkbox",
	default_value = false,
	sub_widgets = {},
}
widgets[#widgets + 1] = custom_properties
for _, vehicle in ipairs(Configuration.vehicles) do
	local id = vehicle.id
	local values = {
		number_input(id .. "_health", "vehicle_health", "vehicle_health_description", vehicle.values.health, true),
	}
	for _, weapon in ipairs(vehicle.weapons) do
		local key = weapon .. "_damage"
		values[#values + 1] = number_input(id .. "_" .. key, key, "weapon_damage_description", vehicle.values[key])
	end
	custom_properties.sub_widgets[#custom_properties.sub_widgets + 1] = {
		setting_id = "vehicle_" .. id,
		type = "group",
		sub_widgets = values,
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = widgets,
	},
}
