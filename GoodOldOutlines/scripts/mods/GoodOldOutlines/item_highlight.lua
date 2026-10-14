local mod = get_mod("GoodOldOutlines")
local LAYER = "goo_tagged_item_outline"
local MATERIAL = "content/characters/materials/minion_outline"
local records = {}
local enabled = false

local function outline_color()
	local color = mod:get("item_outline_color")
	return Vector3(color[2] / 255, color[3] / 255, color[4] / 255)
end

local function set_color(unit, color)
	Unit.set_vector3_for_material(unit, LAYER, "outline_color", color)
	local children = Unit.get_child_units(unit)
	if children then
		for _, child in pairs(children) do
			set_color(child, color)
		end
	end
end

local function hide_outline(unit)
	if Unit.alive(unit) then
		Unit.set_material_layer(unit, LAYER, false)
	end
	records[unit] = nil
end

local function add_tag(tag)
	local unit = tag:target_unit()
	if not unit or not Unit.alive(unit) then
		return
	end
	local target_type = Unit.get_data(unit, "smart_tag_target_type")
	if not target_type or target_type == "breed" then
		return
	end
	local tags = records[unit]
	if not tags then
		-- Keep the layer for the unit's lifetime; queued render updates can still reference it.
		if not Unit.get_data(unit, LAYER) then
			Unit.add_material_layer(unit, LAYER, MATERIAL, true)
			Unit.set_data(unit, LAYER, true)
		end
		Unit.set_material_layer(unit, LAYER, true)
		tags = {}
		records[unit] = tags
		set_color(unit, outline_color())
	end
	tags[tag:id()] = true
end

local function remove_tag(tag)
	local unit = tag:target_unit()
	local tags = records[unit]
	if not tags then
		return
	end
	tags[tag:id()] = nil
	-- Several players can tag one object; retain its layer until the last tag ends.
	if not next(tags) then
		hide_outline(unit)
	end
end

mod:hook_safe(CLASS.SmartTagSystem, "_create_tag_locally", function(system, tag_id)
	if enabled then
		add_tag(system._all_tags[tag_id])
	end
end)

mod:hook(CLASS.SmartTagSystem, "_remove_tag_locally", function(func, system, tag_id, ...)
	local tag = system._all_tags[tag_id]
	if tag then
		remove_tag(tag)
	end
	return func(system, tag_id, ...)
end)

local function set_enabled(value)
	if enabled == value then
		return
	end
	enabled = value
	if not enabled then
		for unit in pairs(records) do
			hide_outline(unit)
		end
		return
	end
	local manager = Managers.state.extension
	if manager and manager:has_system("smart_tag_system") then
		for _, tag in pairs(manager:system("smart_tag_system")._all_tags) do
			add_tag(tag)
		end
	end
end

local function update_color()
	local color = outline_color()
	for unit in pairs(records) do
		if Unit.alive(unit) then
			set_color(unit, color)
		end
	end
end

return { set_enabled = set_enabled, update_color = update_color }
