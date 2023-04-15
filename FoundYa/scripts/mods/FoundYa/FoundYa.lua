local mod = get_mod("FoundYa")
local WorldMarkerTemplateInteraction = require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_interaction")
local HudElementWorldMarkers = require("scripts/ui/hud/elements/world_markers/hud_element_world_markers")
local HUDElementInteractionSettings = require("scripts/ui/hud/elements/interaction/hud_element_interaction_settings")
local HUDElementSmartTagging = require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging")

local memory = mod:persistent_table("memory")

local interaction_types = {
	default = "unknown",
	ammunition = "supply",
	chest = "chest",
	door_control_panel = "button",
	grenade = "supply",
	health = "supply",
	health_station = "station",
	luggable = "luggable",
	luggable_socket = "luggable",
	mission_board = "vendor",
	crafting = "vendor",
	penances = "vendor",
	inbox = "vendor",
	body_shop = "vendor",
	vendor = "vendor",
	marks_vendor = "vendor",
	premium_vendor = "vendor",
	training_ground = "vendor",
	contracts = "vendor",
	moveable_platform = "button",
	pocketable = "supply",
	side_mission = "book",
	forge_material = "material",
}

local all_categories = {
	"unknown", "supply", "chest", "button", "station", "luggable", "vendor", "book", "material",
}

local function get_max_distance(category)
	return mod:get("max_distance_" .. category) or 15
end

local function get_cached_max_distance(category)
	local v = memory["max_distance_" .. category]
	if v then
		return v
	end
	return get_max_distance(category)
end

local function set_max_distance(category, distance)
	return mod:set("max_distance_" .. category, distance, false)
end

local function update_settings()
	for _, category in ipairs(all_categories) do
		local category_max_distance = get_max_distance(category)
		memory["max_distance_" .. category] = category_max_distance
	end
end

mod.on_enabled = function(initial_call)
	local legacy_max_distance = mod:get("max_distance")
	if legacy_max_distance then
		for _, category in ipairs(all_categories) do
			set_max_distance(category, legacy_max_distance)
		end
		mod:set("max_distance", nil)
	end
	update_settings()
	local max_distance = 0
	for _, category in ipairs(all_categories) do
		local category_max_distance = get_max_distance(category)
		if category_max_distance > max_distance then
			max_distance = category_max_distance
		end
	end
	local max_spawn_distance_sq = max_distance * max_distance
	if max_spawn_distance_sq < 1000 then
		max_spawn_distance_sq = 1000
	end
	HUDElementInteractionSettings.max_spawn_distance_sq = max_spawn_distance_sq
end

mod.on_setting_changed = function(setting_id)
	update_settings()
	local max_distance = 0
	for _, category in ipairs(all_categories) do
		local category_max_distance = get_max_distance(category)
		if category_max_distance > max_distance then
			max_distance = category_max_distance
		end
	end
	local max_spawn_distance_sq = max_distance * max_distance
	if max_spawn_distance_sq < 1000 then
		max_spawn_distance_sq = 1000
	end
	HUDElementInteractionSettings.max_spawn_distance_sq = max_spawn_distance_sq
end

mod.on_disabled = function(initial_call)
	HUDElementInteractionSettings.max_spawn_distance_sq = 1000
end

local function update_marker(marker, elem)
	if not marker.data then
		return
	end
	local marker_type = marker.data:interaction_type()
	local marker_category = interaction_types[marker_type]
	if not marker_category then
		elem.max_distance = 15
		elem.fade_settings.distance_max = 15
		elem.fade_settings.distance_min = 15 - elem.evolve_distance * 2
		return
	end
	local max_distance = get_cached_max_distance(marker_category)
	elem.max_distance = max_distance
	elem.fade_settings.distance_max = max_distance
	elem.fade_settings.distance_min = max_distance - elem.evolve_distance * 2
end

mod:hook(WorldMarkerTemplateInteraction, "on_enter", function(func, widget, marker, self)
	update_marker(marker, self)
	func(widget, marker, self)
end)


mod:hook(WorldMarkerTemplateInteraction, "update_function", function(func, parent, ui_renderer, widget, marker, self, dt, t)
	update_marker(marker, self)
	func(parent, ui_renderer, widget, marker, self, dt, t)
end)

mod:hook(HudElementWorldMarkers, "_template_by_type", function(func, self, marker_type, clone)
	if marker_type == "interaction" then
		return table.clone(self._marker_templates[marker_type])
	end
	return func(self, marker_type, clone)
end)

mod:hook(HUDElementSmartTagging, "_is_marker_valid_for_tagging", function(func, self, player_unit, marker, distance)
	local template = marker.template
	if not template then
		return func(self, player_unit, marker, distance)
	end
	if template.name == "interaction" then
		local max_tag_distance = mod:get("max_tag_distance") or 15
		if distance and distance >= max_tag_distance then
			return false
		end
	end
	return func(self, player_unit, marker, distance)
end)
