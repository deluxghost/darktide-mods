local mod = get_mod("FoundYa")
local WorldMarkerTemplateInteraction = require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_interaction")
local HUDElementInteractionSettings = require("scripts/ui/hud/elements/interaction/hud_element_interaction_settings")
local HUDElementSmartTagging = require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging")

local interaction_types = {
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
	"supply", "chest", "button", "station", "luggable", "vendor", "book", "material",
}

local function get_max_distance(category)
	return mod:get("max_distance_" .. category) or 15
end

local function set_max_distance(category, distance)
	return mod:set("max_distance_" .. category, distance, false)
end

mod.on_enabled = function(initial_call)
	local legacy_max_distance = mod:get("max_distance")
	if legacy_max_distance then
		for _, category in ipairs(all_categories) do
			set_max_distance(category, legacy_max_distance)
		end
		mod:set("max_distance", nil)
	end
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

mod:hook(WorldMarkerTemplateInteraction, "on_enter", function(func, widget, marker, self)
	if not marker.data then
		return func(widget, marker, self)
	end
	local marker_type = marker.data:interaction_type()
	local marker_category = interaction_types[marker_type]
	if not marker_category then
		return func(widget, marker, self)
	end
	local max_distance = get_max_distance(marker_category) or 15
	self.max_distance = max_distance
	self.fade_settings.distance_max = max_distance
	self.fade_settings.distance_min = max_distance - self.evolve_distance * 2
	return func(widget, marker, self)
end)

mod:hook(HudElementSmartTagging, "_is_marker_valid_for_tagging", function(func, self, player_unit, marker, distance)
	local template = marker.template
	if not template then
		return func(self, player_unit, marker, distance)
	end
	if template.name ~= "interaction" then
		return func(self, player_unit, marker, distance)
	end
	local max_distance = mod:get("max_distance") or 15
	local max_tag_distance = mod:get("max_tag_distance") or 15
	if max_tag_distance > max_distance then
		max_tag_distance = max_distance
	end
	if distance and distance >= max_tag_distance then
		return false
	end
	return func(self, player_unit, marker, distance)
end)
