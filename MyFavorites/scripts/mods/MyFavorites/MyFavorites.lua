local mod = get_mod("MyFavorites")
local Items = require("scripts/utilities/items")
local Promise = require("scripts/foundation/utilities/promise")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local item_definitions = {
	hotspot = {
		pass_type = "hotspot",
		style_id = "myfav_hotspot",
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			offset = {
				15,
				-5,
				16,
			},
			size = { 10, 10 },
		},
		content_id = "myfav_hotspot",
		content = {
			on_hover_sound = UISoundEvents.default_mouse_hover,
			on_pressed_sound = UISoundEvents.default_click
		},
	},
}

local item_cache = mod:persistent_table("item_cache")

local function get_item_cache()
	if item_cache.favorites == nil then
		item_cache.favorites = mod:get("favorite_item_list") or {}
	end
	item_cache.favorites = item_cache.favorites or {}
	return item_cache.favorites
end

local function set_item_cache(item_list)
	item_cache.favorites = item_list or {}
	mod:set("favorite_item_list", item_cache.favorites)
end

mod.on_enabled = function()
	local favorite_item_list = mod:get("favorite_item_list") or {}
	set_item_cache(favorite_item_list)
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "favorite_item_list" then
		local favorite_item_list = mod:get("favorite_item_list") or {}
		set_item_cache(favorite_item_list)
	end
end

local function max_color_group()
	return mod:get("favorite_preset_count") or 5
end

local function next_color_group(current)
	local max_group = max_color_group()
	if current >= max_group then
		return 0
	end
	return current + 1
end

local function get_item_group(id)
	local favorite_item_list = get_item_cache()
	local group = favorite_item_list[id] or 1
	if group > max_color_group() then
		group = max_color_group()
	end
	return group
end

local function switch_item_group(id)
	local current = get_item_group(id)
	local next = next_color_group(current)
	local favorite_item_list = get_item_cache()
	if next > 1 then
		favorite_item_list[id] = next
	else
		favorite_item_list[id] = nil
	end
	set_item_cache(favorite_item_list)
end

local function clear_item_group(id)
	local favorite_item_list = get_item_cache()
	favorite_item_list[id] = nil
	set_item_cache(favorite_item_list)
end

local function content_to_item(content)
	if (not content.element) or (not content.element.item) then
		return nil
	end
	return content.element.item
end

local function get_character_save_data()
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local character_id = player and player:character_id()
	local save_manager = Managers.save
	local character_data = character_id and save_manager and save_manager:character_data(character_id)

	return character_data
end

local function switch_to_official()
	if mod:get("switch_to_official_done") then
		return
	end
	Promise.until_true(function()
		return (not not get_character_save_data()) and Managers.save:state() == "idle"
	end):next(function()
		local favorite_item_list = get_item_cache()
		local character_data = get_character_save_data()
		if not character_data then
			return
		end
		if not character_data.favorite_items then
			character_data.favorite_items = {}
		end

		local favorite_items = character_data.favorite_items
		for id, value in pairs(favorite_item_list) do
			if type(value) == "boolean" and value then
				favorite_items[id] = true
			elseif type(value) == "number" and value > 0 then
				favorite_items[id] = true
				if value <= 1 then
					favorite_item_list[id] = nil
				end
			end
		end
		mod:dump(character_data, "character_data", 3)
		set_item_cache(favorite_item_list)
		Managers.save:queue_save()
		mod:set("switch_to_official_done", true)
	end)
end

mod.on_game_state_changed = function(status, state_name)
	if state_name ~= "StateMainMenu" then
		return
	end
	if status ~= "enter" then
		return
	end
	switch_to_official()
end


mod:hook_safe(Items, "set_item_id_as_favorite", function(item_gear_id, state)
	if not state then
		clear_item_group(item_gear_id)
	end
end)

mod:hook_require("scripts/ui/pass_templates/item_pass_templates", function(instance)
	local ui_renderer_instance = Managers.ui:ui_constant_elements():ui_renderer()
	local fav_w, fav_h = UIRenderer.text_size(ui_renderer_instance, string.format("%s %s", "", Localize("loc_inventory_menu_favorite_item")), "proxima_nova_bold", 18)
	local idx = nil
	for i, v in ipairs(instance.item) do
		if v.style_id == "myfav_hotspot" then
			idx = i
		elseif v.style_id == "favorite_icon" then
			v.value_id = "favorite_icon"
			v.visibility_function = function(content, style)
				if not content.favorite then
					return false
				end
				if not mod:is_enabled() then
					return true
				end
				local item = content_to_item(content)
				if not item then
					return true
				end

				local hotspot = content.myfav_hotspot
				local current = get_item_group(item.gear_id)
				local color_name = mod:get("color_definition_" .. tostring(current))
				style.text_color = Color[color_name](255, true)
				if hotspot.is_hover then
					content.favorite_icon = string.format("%s %s", "", mod:localize("color_definition") .. " " .. tostring(current))
					style.font_size = 18.5
				else
					content.favorite_icon = string.format("%s %s", "", Localize("loc_inventory_menu_favorite_item"))
					style.font_size = 18
				end
				return true
			end
		end
	end
	if idx then
		table.remove(instance.item, idx)
	end
	local def = table.clone(item_definitions.hotspot)
	def.style.size = { fav_w, fav_h }
	table.insert(instance.item, def)
end)

mod:hook_safe("ViewElementGrid", "init", function(self)
	self.__myfav_cb_main_pressed = function(self, widget)
		local content = widget.content
		if not content then
			return
		end
		local item = content_to_item(content)
		if not item then
			return
		end

		local item_id = item.gear_id
		if not Items.is_item_id_favorited(item_id) then
			return
		end
		switch_item_group(item_id)
	end
end)

mod:hook("ViewElementGrid", "_create_entry_widget_from_config", function(func, self, config, suffix, callback_name, secondary_callback_name, double_click_callback_name)
	local widget, alignment_widget = func(
		self, config, suffix, callback_name, secondary_callback_name, double_click_callback_name
	)
	if (not widget) or (widget.type ~= "item") then
		return widget, alignment_widget
	end
	local content = widget.content
	if (not content) or (not content.myfav_hotspot) then
		return widget, alignment_widget
	end
	content.myfav_hotspot.pressed_callback = callback(self, "__myfav_cb_main_pressed", widget)
	return widget, alignment_widget
end)
