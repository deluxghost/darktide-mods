local mod = get_mod("GoodOldOutlines")
local FILL_LAYERS = {
	minion_outline_reversed_depth = true,
	minion_outline_combat_ability_reversed_depth = true,
}
local original_layers = setmetatable({}, { __mode = "k" })
local hidden = false

local function update_outline(outline)
	local original = original_layers[outline]
	if not hidden then
		if not original then
			return false
		end
		outline.material_layers = original
		original_layers[outline] = nil
		return true
	end
	if original then
		return false
	end
	local layers = {}
	for _, layer in ipairs(outline.material_layers) do
		if not FILL_LAYERS[layer] then
			layers[#layers + 1] = layer
		end
	end
	if #layers == #outline.material_layers then
		return false
	end
	-- Keep each outline's original list without changing the shared game templates.
	original_layers[outline] = outline.material_layers
	outline.material_layers = layers
	return true
end

local function update_unit(system, unit, extension)
	if extension.name ~= "MinionOutlineExtension" then
		return
	end
	for index, outline in ipairs(extension.outlines) do
		if update_outline(outline) and index == 1 then
			-- The next normal visibility update applies the changed material layers.
			system:_hide_outline(unit, extension)
		end
	end
end

mod:hook_safe(CLASS.OutlineSystem, "add_outline", function(system, unit)
	if not hidden then
		return
	end
	local extension = system._unit_extension_data[unit]
	if extension then
		update_unit(system, unit, extension)
	end
end)

local function set_hidden(value)
	if hidden == value then
		return
	end
	hidden = value
	local manager = Managers.state.extension
	if not manager or not manager:has_system("outline_system") then
		return
	end
	local system = manager:system("outline_system")
	for unit, extension in pairs(system._unit_extension_data) do
		update_unit(system, unit, extension)
	end
end

return { set_hidden = set_hidden }
