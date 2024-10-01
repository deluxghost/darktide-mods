local mod = get_mod("MyFavorites")
local Items = require("scripts/utilities/items")
local Promise = require("scripts/foundation/utilities/promise")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local star_icon = "content/ui/materials/icons/presets/preset_15"
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

mod.load_package = function(package_name)
	if not Managers.package:is_loading(package_name) and not Managers.package:has_loaded(package_name) then
		Managers.package:load(package_name, "my_favorites", nil, true)
	end
end

mod.on_all_mods_loaded = function()
	mod.load_package("packages/ui/views/inventory_background_view/inventory_background_view")
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

local function get_save_data()
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local account_id = player and player:account_id()
	local save_manager = Managers.save
	local account_data = account_id and save_manager and save_manager:account_data(account_id)

	return account_data
end

local function switch_to_official()
	if mod:get("switch_to_official_done_fix") then
		return
	end
	Promise.until_true(function()
		return (not not get_save_data()) and Managers.save:state() == "idle"
	end):next(function()
		local favorite_item_list = get_item_cache()
		local account_data = get_save_data()
		if not account_data then
			return
		end
		local character_data = account_data.character_data
		if not character_data then
			return
		end

		local sync_ids = {}
		for id, value in pairs(favorite_item_list) do
			if type(value) == "boolean" and value then
				sync_ids[id] = true
			elseif type(value) == "number" and value > 0 then
				sync_ids[id] = true
				if value <= 1 then
					favorite_item_list[id] = nil
				end
			end
		end

		for char_id, data in pairs(character_data) do
			if not data.favorite_items then
				character_data[char_id].favorite_items = {}
			end
			for id, _ in pairs(sync_ids) do
				character_data[char_id].favorite_items[id] = true
			end
		end

		set_item_cache(favorite_item_list)
		Managers.save:queue_save()
		mod:set("switch_to_official_done_fix", true)
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
	{
		pass_type = "hotspot",
		style_id = "myfav_extra_icon_hotspot",
		style = {
			vertical_alignment = "center",
			horizontal_alignment = "right",
			offset = { 0, 0, 16 },
			size = { 32, 32 },
		},
		content_id = "myfav_extra_icon_hotspot",
		content = {
			on_hover_sound = UISoundEvents.default_mouse_hover,
			on_pressed_sound = UISoundEvents.default_click
		},
	},
	extra_icon = {
		pass_type = "texture",
		value = star_icon,
		value_id = "myfav_extra_icon",
		style_id = "myfav_extra_icon",
		style = {
			vertical_alignment = "center",
			horizontal_alignment = "right",
			offset = { 0, 0, 20 },
			color = Color.white(255, true),
			default_color = Color.white(255, true),
			size = { 32, 32 },
		},
		visibility_function = function(content, style)
			if not content.favorite then
				return false
			end
			if not mod:is_enabled() then
				return false
			end
			if not mod:get("show_extra_icon") then
				return false
			end
			if content.store_item then
				return false
			end
			local item = content_to_item(content)
			if not item then
				return
			end

			local current = get_item_group(item.gear_id)
			local color_name = mod:get("color_definition_" .. tostring(current))
			if current > 0 then
				style.color = Color[color_name](255, true)
				style.default_color = Color[color_name](255, true)
				return true
			end
			return false
		end,
	},
}

mod:hook_require("scripts/ui/pass_templates/item_pass_templates", function(instance)
	local ui_renderer_instance = Managers.ui:ui_constant_elements():ui_renderer()
	local fav_w, fav_h = UIRenderer.text_size(ui_renderer_instance, string.format("%s %s", "", Localize("loc_inventory_menu_favorite_item")), "proxima_nova_bold", 18)
	for name, def in pairs(item_definitions) do
		local idx = nil
		for i, v in ipairs(instance.item) do
			if v.style_id == def.style_id then
				idx = i
				break
			end
		end
		if idx then
			table.remove(instance.item, idx)
		end
		local def_clone = table.clone(def)
		if name == "hotspot" then
			def_clone.style.size = { fav_w, fav_h }
		end
		table.insert(instance.item, def_clone)
	end

	for _, v in ipairs(instance.item) do
		if v.style_id == "favorite_icon" then
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

				local show_extra_icon = mod:get("show_extra_icon")
				if show_extra_icon then
					content.myfav_extra_icon_hotspot.on_hover_sound = UISoundEvents.default_mouse_hover
					content.myfav_extra_icon_hotspot.on_pressed_sound = UISoundEvents.default_click
				else
					content.myfav_extra_icon_hotspot.on_hover_sound = nil
					content.myfav_extra_icon_hotspot.on_pressed_sound = nil
				end
				local hotspot = content.myfav_hotspot
				local hotspot_extra = content.myfav_extra_icon_hotspot
				local current = get_item_group(item.gear_id)
				local color_name = mod:get("color_definition_" .. tostring(current))
				style.text_color = Color[color_name](255, true)
				local is_hover = hotspot.is_hover or (show_extra_icon and hotspot_extra.is_hover)
				if is_hover then
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
	self.__myfav_cb_extra_pressed = function(self, widget)
		if mod:get("show_extra_icon") then
			self.__myfav_cb_main_pressed(self, widget)
		end
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
	if content.myfav_extra_icon_hotspot then
		content.myfav_extra_icon_hotspot.pressed_callback = callback(self, "__myfav_cb_extra_pressed", widget)
	end
	return widget, alignment_widget
end)
