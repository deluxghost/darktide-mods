local mod = get_mod("ItemSorting")
local InventoryWeaponsView = require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view")
local CraftingModifyView = require("scripts/ui/views/crafting_modify_view/crafting_modify_view")
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")
local MarksVendorView = require("scripts/ui/views/marks_vendor_view/marks_vendor_view")
local ProfileUtils = require("scripts/utilities/profile_utils")
local ItemSortingDefinitions = mod:io_dofile("ItemSorting/scripts/mods/ItemSorting/ItemSorting_definitions")
local ItemSortingUtils = mod:io_dofile("ItemSorting/scripts/mods/ItemSorting/ItemSorting_utils")

local function get_valid_new_items()
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local character_id = player and player:character_id()
	local archetype = player and player:archetype_name()
	local save_manager = Managers.save
	local character_data = character_id and save_manager and save_manager:character_data(character_id)
	local account_data = save_manager and save_manager:account_data()

	local new_items = {}
	if character_data and character_data.new_items then
		for item_id, _ in pairs(character_data.new_items) do
			new_items[item_id] = true
		end
	end
	if archetype and account_data and account_data.new_account_items_by_archetype and account_data.new_account_items_by_archetype[archetype] then
		local new_archetype_items = account_data.new_account_items_by_archetype[archetype]
		for item_id, _ in pairs(new_archetype_items) do
			new_items[item_id] = true
		end
	end
	return new_items
end

local function item_equipped_in_loadout(loadout, item)
	if not loadout or not item.slots then
		return false
	end
	for _, slot_name in ipairs(item.slots) do
		local slot_item = loadout[slot_name]
		if slot_item then
			if type(slot_item) == "string" then
				if slot_item == item.gear_id then
					return true
				end
			else
				if slot_item.gear_id == item.gear_id then
					return true
				end
			end
		end
	end
	return false
end

local __isort_extra_keys = {
	"__isort_new",
	"__isort_equipped",
	"__isort_current",
	"__isort_myfav",
	"__isort_type_new",
	"__isort_type_equipped",
	"__isort_type_current",
	"__isort_type_myfav",
}

local function fill_items_extra(view)
	local new_items = get_valid_new_items() or nil
	local inv_items_layout = view and view._offer_items_layout or {}
	local presets = ProfileUtils.get_profile_presets()
	local current_preset_id = ProfileUtils.get_active_profile_preset_id()
	local MyFavorites = get_mod("MyFavorites")

	local new_types, equipped_types, current_types, myfav_types = {}, {}, {}, {}

	for _, layout in ipairs(inv_items_layout) do
		local item = layout.item
		local category = ItemSortingUtils.get_trait_category(item)

		for _, key in ipairs(__isort_extra_keys) do
			item.__master_item[key] = nil
		end

		if new_items[item.gear_id] then
			item.__master_item.__isort_new = true
			new_types[category] = true
		end

		if #presets > 0 then
			for _, preset in ipairs(presets) do
				local current = preset.id and current_preset_id and preset.id == current_preset_id or false
				if item_equipped_in_loadout(preset.loadout, item) then
					item.__master_item.__isort_equipped = true
					equipped_types[category] = true
					if current then
						item.__master_item.__isort_current = true
						current_types[category] = true
					end
				end
			end
		else
			local player = Managers.player:local_player(1)
			local profile = player:profile()
			local loadout = profile.loadout
			if loadout then
				if item_equipped_in_loadout(loadout, item) then
					item.__master_item.__isort_equipped = true
					equipped_types[category] = true
					item.__master_item.__isort_current = true
					current_types[category] = true
				end
			end
		end

		if MyFavorites and MyFavorites:is_enabled() then
			local fav_list = MyFavorites:get("favorite_item_list") or {}
			local fav_group = fav_list[item.gear_id]
			if fav_group then
				item.__master_item.__isort_myfav = fav_group
				if myfav_types[category] and fav_group < myfav_types[category] or not myfav_types[category] then
					myfav_types[category] = fav_group
				end
			end
		end
	end

	for _, layout in ipairs(inv_items_layout) do
		local item = layout.item
		local category = ItemSortingUtils.get_trait_category(item)

		if new_types[category] then
			item.__master_item.__isort_type_new = true
		end
		if equipped_types[category] then
			item.__master_item.__isort_type_equipped = true
		end
		if current_types[category] then
			item.__master_item.__isort_type_current = true
		end
		if myfav_types[category] then
			item.__master_item.__isort_type_myfav = myfav_types[category]
		end
	end
end

mod.on_enabled = function()
	if mod:get("custom_sort_category_mark") then
		mod:set("custom_sort_category_group_by_name", true)
		mod:set("custom_sort_category_mark", nil)
	end
	if Managers.data_service.crafting._trait_sticker_book_cache then
		Managers.data_service.crafting:warm_trait_sticker_book_cache()
	end
end

local function sort_grid_layout(func, self, sort_function)
	if not self._filtered_offer_items_layout then
		return
	end
	fill_items_extra(self)
	func(self, sort_function)
end

mod:hook(InventoryWeaponsView, "_sort_grid_layout", function(func, self, sort_function)
	sort_grid_layout(func, self, sort_function)
end)

mod:hook(CraftingModifyView, "_sort_grid_layout", function(func, self, sort_function)
	sort_grid_layout(func, self, sort_function)
end)

local function setup_sort_options(self, view_type)
	self._sort_options = {}
	if view_type == "inventory" then
		for _, sort_def in ipairs(ItemSortingDefinitions.customized_vanilla_methods.inventory) do
			if mod:get("enable_vanilla_" .. sort_def.id) then
				table.insert(self._sort_options, {
					display_name = sort_def.display_name,
					sort_function = sort_def.sort_function,
				})
			end
		end
		for _, sort_def in ipairs(ItemSortingDefinitions.modded_methods.inventory) do
			if mod:get("custom_sort_" .. sort_def.id) then
				table.insert(self._sort_options, {
					display_name = sort_def.display_name,
					sort_function = sort_def.sort_function,
				})
			end
		end
	elseif view_type == "store" then
		for _, sort_def in ipairs(ItemSortingDefinitions.customized_vanilla_methods.store) do
			if mod:get("enable_vanilla_" .. sort_def.id) then
				table.insert(self._sort_options, {
					display_name = sort_def.display_name,
					sort_function = sort_def.sort_function,
				})
			end
		end
		for _, sort_def in ipairs(ItemSortingDefinitions.modded_methods.store) do
			if mod:get("custom_sort_" .. sort_def.id) then
				table.insert(self._sort_options, {
					display_name = sort_def.display_name,
					sort_function = sort_def.sort_function,
				})
			end
		end
	end
	local sort_callback = callback(self, "cb_on_sort_button_pressed")
	self._item_grid:setup_sort_button(self._sort_options, sort_callback)
end

mod:hook(InventoryWeaponsView, "_setup_sort_options", function(func, self)
	setup_sort_options(self, "inventory")
end)

mod:hook(CraftingModifyView, "_setup_sort_options", function(func, self)
	setup_sort_options(self, "inventory")
end)

mod:hook(CreditsVendorView, "_setup_sort_options", function(func, self)
	setup_sort_options(self, "store")
end)

mod:hook(MarksVendorView, "_setup_sort_options", function(func, self)
	setup_sort_options(self, "store")
end)
