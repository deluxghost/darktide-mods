local mod = get_mod("ItemSorting")
local ItemUtils = require("scripts/utilities/items")
local ItemGridViewBase = require("scripts/ui/views/item_grid_view_base/item_grid_view_base")
local ProfileUtils = require("scripts/utilities/profile_utils")

local rem_sort_index_key = "rem_sort_index"
local memory = mod:persistent_table("memory")

local function character_save_data()
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local character_id = player and player:character_id()
	local save_manager = Managers.save
	local character_data = character_id and save_manager and save_manager:character_data(character_id)
	return character_data
end

local function compare_item_new(view)
	local class = view.__class_name
	if not class or (class ~= "InventoryWeaponsView" and class ~= "CraftingModifyView") then
		return function(a, b)
			return nil
		end
	end
	return function(a, b)
		if not mod:get("always_on_top_new") then
			return nil
		end
		local character_data = character_save_data()
		if not character_data then
			return nil
		end
		local new_items = character_data.new_items
		local a_new = new_items[a.__gear_id]
		local b_new = new_items[b.__gear_id]

		if a_new and not b_new then
			return true
		elseif b_new and not a_new then
			return false
		end
		return nil
	end
end

local function compare_item_type_new(view)
	local class = view.__class_name
	if not class or (class ~= "InventoryWeaponsView" and class ~= "CraftingModifyView") then
		return function(a, b)
			return nil
		end
	end
	return function(a, b)
		if not mod:get("always_on_top_new") then
			return nil
		end
		if not view._inventory_items then
			return nil
		end
		local character_data = character_save_data()
		if not character_data then
			return nil
		end
		local new_items = character_data.new_items

		local a_new = false
		local b_new = false
		for _, item in pairs(view._inventory_items) do
			if new_items[item.__gear_id] then
				if item.trait_category == a.trait_category then
					a_new = true
				end
				if item.trait_category == b.trait_category then
					b_new = true
				end
			end
		end
		if a_new and not b_new then
			return true
		elseif b_new and not a_new then
			return false
		end
		return nil
	end
end

local function item_equipped_in_loadout(loadout, item)
	if not loadout then
		return false
	end
	for _, slot_name in ipairs(item.slots) do
		local slot_item = loadout[slot_name]
		if type(slot_item) == "string" then
			if slot_item == item.__gear_id then
				return true
			end
		else
			if slot_item.__gear_id == item.__gear_id then
				return true
			end
		end
	end
	return false
end

local function compare_item_equipped(view)
	local class = view.__class_name
	if not class or (class ~= "InventoryWeaponsView" and class ~= "CraftingModifyView") then
		return function(a, b)
			return nil
		end
	end
	return function(a, b)
		if not mod:get("always_on_top_equipped") then
			return nil
		end
		if not a.slots then
			return false
		end
		if not b.slots then
			return true
		end
		local presets = ProfileUtils:get_profile_presets()

		local a_equipped = false
		local b_equipped = false
		if #presets > 0 then
			for _, preset in ipairs(presets) do
				if item_equipped_in_loadout(preset.loadout, a) then
					a_equipped = true
				end
				if item_equipped_in_loadout(preset.loadout, b) then
					b_equipped = true
				end
			end
		else
			local player = Managers.player:local_player(1)
			local profile = player:profile()
			local loadout = profile.loadout
			if not loadout then
				return nil
			end
			if item_equipped_in_loadout(loadout, a) then
				a_equipped = true
			end
			if item_equipped_in_loadout(loadout, b) then
				b_equipped = true
			end
		end
		if a_equipped and not b_equipped then
			return true
		elseif b_equipped and not a_equipped then
			return false
		end
		return nil
	end
end

local function compare_item_type_equipped(view)
	local class = view.__class_name
	if not class or (class ~= "InventoryWeaponsView" and class ~= "CraftingModifyView") then
		return function(a, b)
			return nil
		end
	end
	return function(a, b)
		if not mod:get("always_on_top_equipped") then
			return nil
		end
		if not view._inventory_items then
			return nil
		end
		if not a.slots then
			return false
		end
		if not b.slots then
			return true
		end
		local a_slot_item_ids = {}
		local b_slot_item_ids = {}
		local presets = ProfileUtils:get_profile_presets()
		for _, preset in ipairs(presets) do
			for _, slot in ipairs(a.slots) do
				if preset.loadout[slot] then
					a_slot_item_ids[preset.loadout[slot]] = true
				end
			end
			for _, slot in ipairs(b.slots) do
				if preset.loadout[slot] then
					b_slot_item_ids[preset.loadout[slot]] = true
				end
			end
		end
		local player = Managers.player:local_player(1)
		local profile = player:profile()
		local loadout = profile.loadout
		if loadout then
			for _, slot in ipairs(a.slots) do
				if loadout[slot] then
					a_slot_item_ids[loadout[slot].__gear_id] = true
				end
			end
			for _, slot in ipairs(b.slots) do
				if loadout[slot] then
					b_slot_item_ids[loadout[slot].__gear_id] = true
				end
			end
		end

		local a_equipped = false
		local b_equipped = false
		for _, item in pairs(view._inventory_items) do
			for item_id, _ in pairs(a_slot_item_ids) do
				if item.__gear_id == item_id and item.trait_category == a.trait_category then
					a_equipped = true
				end
			end
			for item_id, _ in pairs(b_slot_item_ids) do
				if item.__gear_id == item_id and item.trait_category == b.trait_category then
					b_equipped = true
				end
			end
		end
		if a_equipped and not b_equipped then
			return true
		elseif b_equipped and not a_equipped then
			return false
		end
		return nil
	end
end

local function compare_item_category(view)
	return function(a, b)
		local a_category = a.trait_category or ""
		local b_category = b.trait_category or ""

		if a_category < b_category then
			return true
		elseif b_category < a_category then
			return false
		end
		return nil
	end
end

local function compare_item_base_level(view)
	return function(a, b)
		local a_level = a.baseItemLevel or 0
		local b_level = b.baseItemLevel or 0

		if a_level < b_level then
			return true
		elseif b_level < a_level then
			return false
		end
		return nil
	end
end

local function wrap(sort_func)
	return function(view)
		return sort_func
	end
end

local custom_sorts_def = {
	{
		name = "custom_sort_level",
		display_name = Localize("loc_inventory_item_grid_sort_title_item_power"),
		replace = true,
		sort_functions = {
			{"<", compare_item_new},
			{"<", compare_item_equipped},
			{">", wrap(ItemUtils.compare_item_level)},
			{">", wrap(ItemUtils.compare_item_type)},
			{"<", wrap(ItemUtils.compare_item_name)},
			{"<", wrap(ItemUtils.compare_item_rarity)},
		},
	},
	{
		name = "custom_sort_type",
		display_name = Localize("loc_inventory_item_grid_sort_title_item_type"),
		replace = true,
		sort_functions = {
			{"<", compare_item_new},
			{"<", compare_item_equipped},
			{">", wrap(ItemUtils.compare_item_type)},
			{"<", wrap(ItemUtils.compare_item_name)},
			{">", wrap(ItemUtils.compare_item_level)},
			{"<", wrap(ItemUtils.compare_item_rarity)},
		},
	},
	{
		name = "custom_sort_category",
		display_name = mod:localize("custom_sort_category"),
		sort_functions = {
			{"<", compare_item_type_new},
			{"<", compare_item_type_equipped},
			{">", compare_item_category},
			{">", wrap(ItemUtils.compare_item_rarity)},
			{">", wrap(ItemUtils.compare_item_level)},
			{">", wrap(ItemUtils.compare_item_type)},
			{"<", wrap(ItemUtils.compare_item_name)},
		},
	},
	{
		name = "custom_sort_category_mark",
		display_name = mod:localize("custom_sort_category_mark"),
		sort_functions = {
			{"<", compare_item_type_new},
			{"<", compare_item_type_equipped},
			{">", compare_item_category},
			{">", wrap(ItemUtils.compare_item_type)},
			{"<", wrap(ItemUtils.compare_item_name)},
			{">", wrap(ItemUtils.compare_item_rarity)},
			{">", wrap(ItemUtils.compare_item_level)},
		},
	},
	{
		name = "custom_sort_rarity",
		display_name = mod:localize("custom_sort_rarity"),
		sort_functions = {
			{"<", compare_item_new},
			{"<", compare_item_equipped},
			{">", wrap(ItemUtils.compare_item_rarity)},
			{">", wrap(ItemUtils.compare_item_level)},
			{">", wrap(ItemUtils.compare_item_type)},
			{"<", wrap(ItemUtils.compare_item_name)},
		},
	},
	{
		name = "custom_sort_base_level",
		display_name = mod:localize("custom_sort_base_level"),
		sort_functions = {
			{"<", compare_item_new},
			{"<", compare_item_equipped},
			{">", compare_item_base_level},
			{">", wrap(ItemUtils.compare_item_level)},
			{"<", wrap(ItemUtils.compare_item_rarity)},
			{">", wrap(ItemUtils.compare_item_type)},
			{"<", wrap(ItemUtils.compare_item_name)},
		},
	},
}

mod.on_enabled = function(initial_call)
	memory[rem_sort_index_key] = mod:get(rem_sort_index_key) or 1
end

local function is_cosmetics_store(object)
	if object._optional_store_service ~= nil then
		return true
	end
	return false
end

local function set_extra_sort(self)
	local options = self._sort_options
	if not options then
		return
	end
	if not self._item_sorting_modded then
		self._sort_options = {}
		for _, sort_def in ipairs(custom_sorts_def) do
			if sort_def.replace or mod:get(sort_def.name) then
				local sort_functions = {}
				for _, sort_func_def in ipairs(sort_def.sort_functions) do
					table.insert(sort_functions, sort_func_def[1])
					table.insert(sort_functions, sort_func_def[2](self))
				end
				local sort = {
					display_name = sort_def.display_name,
					sort_function = ItemUtils.sort_comparator(sort_functions),
				}
				table.insert(self._sort_options, sort)
			end
		end
		local sort_callback = callback(self, "cb_on_sort_button_pressed")
		self._item_grid:setup_sort_button(self._sort_options, sort_callback, 1)
		self._item_sorting_modded = true
	end
end

mod:hook_safe(ItemGridViewBase, "on_enter", function(self)
	if is_cosmetics_store(self) then
		return
	end
	set_extra_sort(self)

	if mod:get("remember_sort_index") then
		local options = self._sort_options
		if not options then
			return
		end
		local length = #options
		local index = memory[rem_sort_index_key] or 1
		if index > length then
			index = 1
		end
		local option = options[index]
		self._selected_sort_option_index = index
		self._selected_sort_option = option
		self:trigger_sort_index(index)
	end
end)

mod:hook_safe(ItemGridViewBase, "on_exit", function(self)
	if not mod:get("remember_sort_index") then
		mod:set(rem_sort_index_key, 1)
		memory[rem_sort_index_key] = 1
		return
	end

	if is_cosmetics_store(self) then
		return
	end
	if self._selected_sort_option_index == nil then
		return
	end
	mod:set(rem_sort_index_key, self._selected_sort_option_index)
	memory[rem_sort_index_key] = self._selected_sort_option_index
end)
