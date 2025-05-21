local mod = get_mod("FoundYa")
local WorldMarkerTemplateInteraction = require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_interaction")
local HudElementWorldMarkers = require("scripts/ui/hud/elements/world_markers/hud_element_world_markers")
local HUDElementInteractionSettings = require("scripts/ui/hud/elements/interaction/hud_element_interaction_settings")
local HUDElementSmartTagging = require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging")
local BaseInteraction = require("scripts/extension_systems/interaction/interactions/base_interaction")
local InteractionTemplates = require("scripts/settings/interaction/interaction_templates")
local Pickups = require("scripts/settings/pickup/pickups")

local memory = mod:persistent_table("memory")

local DEFAULT_COMMON_ICON = "content/ui/materials/hud/interactions/icons/default"
local DEFAULT_AMMO_ICON = "content/ui/materials/hud/interactions/icons/ammunition"
local ALTER_CHEST_ICON = "content/ui/materials/icons/system/settings/category_video"
local ALTER_LUGGABLE_ICON = "content/ui/materials/icons/presets/preset_18"
local ALTER_LARGE_AMMO_ICON = "content/ui/materials/icons/presets/preset_16"
local ALTER_SKULL_ICON = "content/ui/materials/hud/interactions/icons/enemy"
local LIGHTER_ICON_COLOR = { 255, 232, 255, 204 }

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
	cosmetics_vendor = "vendor",
	moveable_platform = "button",
	side_mission = "book",
	forge_material = "material",
	penance_collectible = "penance",
	tainted_skull = "event",
	pocketable = function (pickup_data)
		if pickup_data.name == "communications_hack_device" then
			return "device"
		end
		if pickup_data.is_side_mission_pickup then
			return "book"
		end
		return "supply"
	end,
}

local all_categories = {
	"unknown", "supply", "chest", "button", "station", "luggable", "vendor", "book", "material", "penance", "event",
}

mod.load_package = function (self, package_name)
	if not Managers.package:is_loading(package_name) and not Managers.package:has_loaded(package_name) then
		Managers.package:load(package_name, "FoundYa", nil, true)
	end
end

mod.on_all_mods_loaded = function ()
	mod:load_package("packages/ui/views/options_view/options_view")
	mod:load_package("packages/ui/views/inventory_background_view/inventory_background_view")
end

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
	memory.alter_chest_icon = mod:get("alter_chest_icon")
	memory.alter_luggable_icon = mod:get("alter_luggable_icon")
	memory.alter_large_ammo_icon = mod:get("alter_large_ammo_icon")
	memory.alter_skull_icon = mod:get("alter_skull_icon")
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
	if memory.alter_chest_icon then
		InteractionTemplates.chest.interaction_icon = ALTER_CHEST_ICON
	else
		InteractionTemplates.chest.interaction_icon = DEFAULT_COMMON_ICON
	end
	if memory.alter_luggable_icon then
		InteractionTemplates.luggable.interaction_icon = ALTER_LUGGABLE_ICON
		InteractionTemplates.luggable_socket.interaction_icon = ALTER_LUGGABLE_ICON
	else
		InteractionTemplates.luggable.interaction_icon = DEFAULT_COMMON_ICON
		InteractionTemplates.luggable_socket.interaction_icon = DEFAULT_COMMON_ICON
	end
end

mod.on_enabled = function ()
	local legacy_max_distance = mod:get("max_distance")
	if legacy_max_distance then
		for _, category in ipairs(all_categories) do
			set_max_distance(category, legacy_max_distance)
		end
		mod:set("max_distance", nil)
	end
	update_settings()
end

mod.on_setting_changed = function (setting_id)
	update_settings()
end

mod.on_disabled = function ()
	HUDElementInteractionSettings.max_spawn_distance_sq = 1000
	InteractionTemplates.chest.interaction_icon = DEFAULT_COMMON_ICON
	InteractionTemplates.luggable.interaction_icon = DEFAULT_COMMON_ICON
	InteractionTemplates.luggable_socket.interaction_icon = DEFAULT_COMMON_ICON
end

local function get_pickup_type(marker)
	if marker.type ~= "interaction" then
		return
	end
	if not marker.unit or not Unit then
		return
	end
	if not Unit.alive(marker.unit) then
		return
	end
	if not Unit.has_data(marker.unit, "pickup_type") then
		return
	end
	local pickup_type = Unit.get_data(marker.unit, "pickup_type")
	return pickup_type
end

local function get_interaction_category(marker, pickup_type)
	if not marker.data then
		return
	end
	local marker_type = marker.data:interaction_type()
	local marker_category = interaction_types[marker_type]
	if type(marker_category) == "function" then
		local pickup_data = Pickups.by_name[pickup_type]
		if pickup_data then
			return marker_category(pickup_data)
		end
		return
	end
	return marker_category
end

local function update_marker(widget, marker, elem)
	local marker_category = marker.__foundya_marker_category
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

local function post_update_marker(widget, marker, elem)
	if marker.__foundya_marker_category == "luggable" and memory.alter_luggable_icon then
		widget.style.icon.size[1] = widget.style.icon.size[1] * 0.85
		widget.style.icon.size[2] = widget.style.icon.size[2] * 0.85
		widget.style.icon.color = LIGHTER_ICON_COLOR
	end

	if marker.__foundya_pickup_type == "large_clip" then
		if memory.alter_large_ammo_icon then
			widget.content.icon = ALTER_LARGE_AMMO_ICON
			widget.style.icon.size[1] = widget.style.icon.size[1] * 0.8
			widget.style.icon.size[2] = widget.style.icon.size[2] * 0.8
			widget.style.icon.color = LIGHTER_ICON_COLOR
		else
			widget.content.icon = DEFAULT_AMMO_ICON
		end
	elseif marker.__foundya_pickup_type == "collectible_01_pickup" then
		if memory.alter_skull_icon then
			widget.content.icon = ALTER_SKULL_ICON
		else
			widget.content.icon = DEFAULT_COMMON_ICON
		end
	end
end

mod:hook(WorldMarkerTemplateInteraction, "on_enter", function (func, widget, marker, self)
	local pickup_type = get_pickup_type(marker)
	marker.__foundya_pickup_type = pickup_type
	local marker_category = get_interaction_category(marker, pickup_type)
	marker.__foundya_marker_category = marker_category

	update_marker(widget, marker, self)
	func(widget, marker, self)
	post_update_marker(widget, marker, self)
end)


mod:hook(WorldMarkerTemplateInteraction, "update_function", function (func, parent, ui_renderer, widget, marker, self, dt, t)
	update_marker(widget, marker, self)
	func(parent, ui_renderer, widget, marker, self, dt, t)
	post_update_marker(widget, marker, self)
end)

mod:hook(HudElementWorldMarkers, "_template_by_type", function (func, self, marker_type, clone)
	if marker_type == "interaction" then
		return table.clone(self._marker_templates[marker_type])
	end
	return func(self, marker_type, clone)
end)

mod:hook(HUDElementSmartTagging, "_is_marker_valid_for_tagging", function (func, self, player_unit, marker, distance)
	local template = marker.template
	if template and template.name == "interaction" then
		local max_tag_distance = mod:get("max_tag_distance") or 15
		if distance and distance >= max_tag_distance then
			return false
		end
	end
	return func(self, player_unit, marker, distance)
end)

mod:hook(BaseInteraction, "_interactor_disabled", function (func, self, interactor_unit)
	local unit_data_extension = ScriptUnit.extension(interactor_unit, "unit_data_system")
	if not unit_data_extension then
		return false, false
	end
	return func(self, interactor_unit)
end)
