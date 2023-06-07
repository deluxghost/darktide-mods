local mod = get_mod("MyFavorites")
local Promise = require("scripts/foundation/utilities/promise")
local ColorUtilities = require("scripts/utilities/ui/colors")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local CraftingSettings = require("scripts/settings/item/crafting_settings")
local RaritySettings = require("scripts/settings/item/rarity_settings")

local fav_icon = "content/ui/materials/icons/presets/preset_15"
local remove_icon = "content/ui/materials/icons/system/settings/category_interface"

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

local function is_valid_crafting_item(item)
	return item and not item.no_crafting and RaritySettings[item.rarity]
end

local function get_item_group(id)
	local favorite_item_list = mod:get("favorite_item_list") or {}
	local group = favorite_item_list[id] or 0
	if group > max_color_group() then
		group = max_color_group()
	end
	return group
end

local function is_item_fav(id)
	local group = get_item_group(id)
	return group > 0
end

local function switch_item_group(id)
	local current = get_item_group(id)
	local next = next_color_group(current)
	local favorite_item_list = mod:get("favorite_item_list") or {}
	if next > 0 then
		favorite_item_list[id] = next
	else
		favorite_item_list[id] = nil
	end
	mod:set("favorite_item_list", favorite_item_list)
end

local function content_to_item(content)
	if (not content.element) or (not content.element.item) then
		return nil
	end
	return content.element.item
end

mod.load_package = function(self, package_name)
	if not Managers.package:is_loading(package_name) and not Managers.package:has_loaded(package_name) then
		Managers.package:load(package_name, "my_favorites", nil, true)
	end
end

mod.on_enabled = function(initial_call)
	local favorite_item_list = mod:get("favorite_item_list") or {}
	for id, value in pairs(favorite_item_list) do
		if type(value) == "boolean" and value then
			favorite_item_list[id] = 1
		end
	end
	mod:set("favorite_item_list", favorite_item_list)
	CraftingSettings.recipes.extract_trait.is_valid_item = function(item)
		if not is_valid_crafting_item(item) then
			return false
		end
		if is_item_fav(item.__gear_id) then
			return false
		end
		return (item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED") and item.traits and #item.traits > 0
	end
end

mod.on_disabled = function(initial_call)
	CraftingSettings.recipes.extract_trait.is_valid_item = function (item)
		return is_valid_crafting_item(item) and (item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED") and item.traits and #item.traits > 0
	end
end

mod.on_all_mods_loaded = function()
	mod:load_package("packages/ui/views/inventory_background_view/inventory_background_view")
end

local item_definitions = {
	{
		pass_type = "hotspot",
		style_id = "myfav_hotspot",
		style = {
			vertical_alignment = "center",
			horizontal_alignment = "right",
			offset = { 0, 0, 1 },
			size = { 32, 32 },
		},
		content_id = "myfav_hotspot",
		content = {
			on_hover_sound = UISoundEvents.default_mouse_hover,
			on_pressed_sound = UISoundEvents.default_click
		},
	},
	{
		pass_type = "texture",
		value = fav_icon,
		value_id = "myfav_item_icon",
		style_id = "myfav_item_icon",
		style = {
			vertical_alignment = "center",
			horizontal_alignment = "right",
			offset = { 0, 0, 1 },
			color = Color.white(255, true),
			default_color = Color.white(255, true),
			hover_color = Color.spring_green(255, true),
			size = { 32, 32 },
		},
		change_function = function(content, style)
			local item = content_to_item(content)
			if not item then
				return
			end

			local current = get_item_group(item.__gear_id)
			local next = next_color_group(current)
			if next == 0 then
				style.hover_color = Color.red(255, true)
			else
				local color_name = mod:get("color_definition_" .. tostring(next))
				style.hover_color = Color[color_name](255, true)
			end
			local hotspot = content.myfav_hotspot
			local color = style.color
			local default_color = hotspot.disabled and style.disabled_color or style.default_color
			local hover_color = style.hover_color
			local hover_progress = hotspot.anim_hover_progress or 0
			local ignore_alpha = true
			ColorUtilities.color_lerp(default_color, hover_color, hover_progress, color, ignore_alpha)
		end,
		visibility_function = function(content, style)
			if not mod:is_enabled() then
				return false
			end
			if content.store_item then
				return false
			end
			local item = content_to_item(content)
			if not item then
				return
			end

			local hotspot = content.myfav_hotspot
			local item_hotspot = content.hotspot
			local current = get_item_group(item.__gear_id)
			local next = next_color_group(current)
			local color_name = mod:get("color_definition_" .. tostring(current))
			local next_color_name = mod:get("color_definition_" .. tostring(next))
			content.myfav_item_icon = fav_icon
			if current > 0 and next == 0 and hotspot.is_hover then
				content.myfav_item_icon = remove_icon
			end
			if current > 0 then
				style.color = Color[color_name](255, true)
				style.default_color = Color[color_name](255, true)
			else
				style.color = Color[next_color_name](255, true)
				style.default_color = Color[next_color_name](255, true)
			end
			return current > 0 or item_hotspot.is_hover
		end,
	},
}

mod:hook_require("scripts/ui/pass_templates/item_pass_templates", function(instance)
	for _, def in ipairs(item_definitions) do
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
		table.insert(instance.item, def)
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

		local item_id = item.__gear_id
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

-- last checks
mod:hook("GearService", "delete_gear", function(func, self, gear_id)
	if is_item_fav(gear_id) then
		mod:notify(mod:localize("unexpected_delete_message"))
		local promise = Promise.new()
		promise:reject("gear deleting is stopped by MyFavorites mod")
		return promise
	end
	return func(self, gear_id)
end)

mod:hook("CraftingService", "extract_trait_from_weapon", function(func, self, gear_id, trait_index, costs)
	if is_item_fav(gear_id) then
		mod:notify(mod:localize("unexpected_extract_message"))
		local promise = Promise.new()
		promise:reject("gear extracting is stopped by MyFavorites mod")
		return promise
	end
	return func(self, gear_id, trait_index, costs)
end)

-- Inventory: hide legend
mod:hook_safe("InventoryWeaponsView", "_setup_input_legend", function(self)
	for _, entry in ipairs(self._input_legend_element._entries) do
		if entry.input_action == "hotkey_item_discard" then
			entry.visibility_function = function(parent)
				local selected_grid_widget = parent:selected_grid_widget()
				if not selected_grid_widget then
					return false
				end
				local is_item_equipped = parent:is_selected_item_equipped()
				local content = selected_grid_widget.content
				if not content then
					return false
				end
				local item = content_to_item(content)
				if not item then
					return false
				end
				local is_fav = is_item_fav(item.__gear_id)
				return (not is_item_equipped) and (not is_fav)
			end
		end
	end
end)

-- Crafting: hide legend
mod:hook("CraftingView", "_setup_tab_bar", function(func, self, tab_bar_params, additional_context)
	if tab_bar_params and tab_bar_params.tabs_params then
		local params = tab_bar_params.tabs_params
		for _, param in ipairs(params) do
			if param.view == "crafting_modify_view" then
				local legends = param.input_legend_buttons
				if legends then
					for _, legend in ipairs(legends) do
						if legend.input_action == "hotkey_item_discard" then
							legend.visibility_function = function(parent)
								local view = Managers.ui:view_instance("crafting_modify_view")
								if (not view) or (not view._item_grid) then
									return false
								end
								local selected_grid_widget = view:selected_grid_widget()
								if not selected_grid_widget then
									return false
								end
								local content = selected_grid_widget.content
								if not content then
									return false
								end
								local equipped = content.equipped
								local item = content_to_item(content)
								if not item then
									return false
								end
								local is_fav = is_item_fav(item.__gear_id)
								return (not equipped) and (not is_fav)
							end
						end
					end
				end
			end
		end
	end
	return func(self, tab_bar_params, additional_context)
end)
