local mod = get_mod("FoundYa")
local WorldMarkerTemplateInteraction = require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_interaction")
local HUDElementInteractionSettings = require("scripts/ui/hud/elements/interaction/hud_element_interaction_settings")
local HUDElementSmartTagging = require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging")

mod.on_enabled = function(initial_call)
	local max_distance = mod:get("max_distance") or 15
	local max_spawn_distance_sq = max_distance * max_distance
	if max_spawn_distance_sq < 1000 then
		max_spawn_distance_sq = 1000
	end
	HUDElementInteractionSettings.max_spawn_distance_sq = max_spawn_distance_sq
end

mod.on_setting_changed = function(setting_id)
	local max_distance = mod:get("max_distance") or 15
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
	local max_distance = mod:get("max_distance") or 15
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
