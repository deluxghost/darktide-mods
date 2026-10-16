local mod = get_mod("GoodOldOutlines")
local OutlineSettings = require("scripts/settings/outline/outline_settings")
local MAX_ID = 4194303
local layers = { goo_tagged_item_outline = true }
local records, owners = {}, {}
local next_id = 0
local enabled = false

for _, settings in pairs(OutlineSettings) do
	for _, outline in pairs(settings) do
		if type(outline) == "table" and outline.material_layers then
			for _, layer in ipairs(outline.material_layers) do
				if layer ~= "" then
					layers[layer] = true
				end
			end
		end
	end
end

local function write_tree(unit, owner, layer, id)
	owners[unit] = owner
	-- This existing parameter is unused by the original outline pixel shaders.
	Unit.set_vector4_for_material(unit, layer, "dev_wireframe_color", Color(0, 0, 0, id))
	for _, child in ipairs(Unit.get_child_units(unit)) do
		write_tree(child, owner, layer, id)
	end
end

local function set_layer(unit, layer, visible)
	local owner = owners[unit] or unit
	local record = records[owner]
	if not visible then
		if record then
			record.layers[layer] = nil
		end
		return
	end
	if not record then
		next_id = next_id + 1
		assert(next_id <= MAX_ID, "Outline target identity space exhausted")
		record = { id = next_id, layers = {} }
		records[owner] = record
	end
	record.layers[layer] = true
	write_tree(unit, owner, layer, record.id)
end

mod:hook_safe(Unit, "set_material_layer", function(unit, layer, visible)
	if enabled and layers[layer] then
		set_layer(unit, layer, visible)
	end
end)

mod:hook_safe(World, "link_unit", function(world, unit, node, parent)
	if not enabled or records[unit] then
		return
	end
	local owner = owners[parent] or parent
	local record = records[owner]
	if record then
		for layer in pairs(record.layers) do
			write_tree(unit, owner, layer, record.id)
		end
	end
end)

local function forget_tree(unit)
	owners[unit] = nil
	records[unit] = nil
	for _, child in ipairs(Unit.get_child_units(unit)) do
		forget_tree(child)
	end
end

mod:hook_safe(World, "unlink_unit", function(world, unit)
	-- Detached equipment can become an independently highlighted object.
	if enabled and owners[unit] and owners[unit] ~= unit then
		forget_tree(unit)
	end
end)

mod:hook(World, "destroy_unit", function(func, world, unit, ...)
	if enabled then
		forget_tree(unit)
	end
	return func(world, unit, ...)
end)

local function set_enabled(value)
	enabled = value
	if not enabled then
		records, owners = {}, {}
		next_id = 0
		return
	end
	local manager = Managers.state.extension
	if manager and manager:has_system("outline_system") then
		for unit, extension in pairs(manager:system("outline_system")._unit_extension_data) do
			for _, layer in ipairs(extension.visible_material_layers or {}) do
				set_layer(unit, layer, true)
			end
		end
	end
end

return { set_enabled = set_enabled }
