local mod = get_mod("ItemSorting")
local ItemUtils = require("scripts/utilities/items")
local ItemGridViewBase = require("scripts/ui/views/item_grid_view_base/item_grid_view_base")
local InventoryCosmeticsView = require("scripts/ui/views/inventory_cosmetics_view/inventory_cosmetics_view")
local ProfileUtils = require("scripts/utilities/profile_utils")

local rem_sort_index_prefix = "rem_sort_index_view_"
local view_context_handler = {
	cosmetics_vendor_view = function(self)
		return self._optional_store_service or nil
	end,
	inventory_cosmetics_view = function(self)
		if not self._cosmetic_layout then
			return nil
		end
		for i = 1, #self._cosmetic_layout do
			local layout = self._cosmetic_layout[i]
			if layout.item and layout.item.rarity then
				return "_isort_invcos_rarity"
			end
		end
		return "_isort_invcos_basic"
	end
}

local function get_view_rem_key(view)
	if not view or not view.view_name then
		return ""
	end
	local key = rem_sort_index_prefix .. view.view_name
	if view_context_handler[view.view_name] then
		local context = view_context_handler[view.view_name](view)
		if context == nil then
			return ""
		end
		key = key .. "_" .. context
	end
	return key
end

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

local function get_items_extra(a, b, view, with_type_new, with_equipped, with_type_equipped, with_type_myfav)
	local a_extra = {}
	local b_extra = {}
	local new_items = get_valid_new_items() or nil
	local inv_items_array = view and view._inventory_items or {}
	local presets = ProfileUtils.get_profile_presets()
	local current_preset_id = ProfileUtils.get_active_profile_preset_id()

	local inv_items = nil
	if #inv_items_array > 0 then
		inv_items = {}
		for _, inv_item in ipairs(inv_items_array) do
			inv_items[inv_item.gear_id] = inv_item
		end
	end

	if new_items then
		a_extra.new = new_items[a.gear_id]
		b_extra.new = new_items[b.gear_id]
		if inv_items and with_type_new then
			for new_item_id, _ in pairs(new_items) do
				local inv_item = inv_items[new_item_id]
				if inv_item then
					if inv_item.trait_category == a.trait_category then
						a_extra.type_new = true
					end
					if inv_item.trait_category == b.trait_category then
						b_extra.type_new = true
					end
				end
			end
		end
	end

	local fav_list = {}
	local MyFavorites = get_mod("MyFavorites")
	if MyFavorites and MyFavorites:is_enabled() then
		fav_list = MyFavorites:get("favorite_item_list") or {}
		a_extra.myfav = fav_list[a.gear_id]
		b_extra.myfav = fav_list[b.gear_id]
	end

	if with_equipped then
		local a_slot_item_ids = {}
		local b_slot_item_ids = {}
		if #presets > 0 then
			for _, preset in ipairs(presets) do
				local current = preset.id and current_preset_id and preset.id == current_preset_id or false
				if item_equipped_in_loadout(preset.loadout, a) then
					a_extra.equipped = true
					if current then
						a_extra.current = true
					end
				end
				if item_equipped_in_loadout(preset.loadout, b) then
					b_extra.equipped = true
					if current then
						b_extra.current = true
					end
				end

				if with_type_equipped then
					if a.slots then
						for _, slot in ipairs(a.slots) do
							if preset.loadout[slot] then
								a_slot_item_ids[preset.loadout[slot]] = a_slot_item_ids[preset.loadout[slot]] or false
								a_slot_item_ids[preset.loadout[slot]] = a_slot_item_ids[preset.loadout[slot]] or current
							end
						end
					end
					if b.slots then
						for _, slot in ipairs(b.slots) do
							if preset.loadout[slot] then
								b_slot_item_ids[preset.loadout[slot]] = b_slot_item_ids[preset.loadout[slot]] or false
								b_slot_item_ids[preset.loadout[slot]] = b_slot_item_ids[preset.loadout[slot]] or current
							end
						end
					end
				end
			end
		else
			local player = Managers.player:local_player(1)
			local profile = player:profile()
			local loadout = profile.loadout
			if loadout then
				if item_equipped_in_loadout(loadout, a) then
					a_extra.equipped = true
					a_extra.current = true
				end
				if item_equipped_in_loadout(loadout, b) then
					b_extra.equipped = true
					b_extra.current = true
				end

				if with_type_equipped then
					if a.slots then
						for _, slot in ipairs(a.slots) do
							if loadout[slot] then
								a_slot_item_ids[loadout[slot].gear_id] = true
							end
						end
					end
					if b.slots then
						for _, slot in ipairs(b.slots) do
							if loadout[slot] then
								b_slot_item_ids[loadout[slot].gear_id] = true
							end
						end
					end
				end
			end
		end

		if inv_items and with_type_equipped then
			for slot_item_id, current in pairs(a_slot_item_ids) do
				local inv_item = inv_items[slot_item_id]
				if inv_item then
					if inv_item.trait_category == a.trait_category then
						a_extra.type_equipped = true
						if current then
							a_extra.type_current = true
						end
					end
				end
			end
			for slot_item_id, current in pairs(b_slot_item_ids) do
				local inv_item = inv_items[slot_item_id]
				if inv_item then
					if inv_item.trait_category == b.trait_category then
						b_extra.type_equipped = true
						if current then
							b_extra.type_current = true
						end
					end
				end
			end
		end
	end

	if inv_items and with_type_myfav then
		for fav_id, fav_group in pairs(fav_list) do
			local inv_item = inv_items[fav_id]
			if inv_item then
				if inv_item.trait_category == a.trait_category then
					if a_extra.type_myfav and fav_group < a_extra.type_myfav or not a_extra.type_myfav then
						a_extra.type_myfav = fav_group
					end
				end
				if inv_item.trait_category == b.trait_category then
					if b_extra.type_myfav and fav_group < b_extra.type_myfav or not b_extra.type_myfav then
						b_extra.type_myfav = fav_group
					end
				end
			end
		end
	end
	return a_extra, b_extra
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
		local a_extra, b_extra = get_items_extra(a, b, view, false, false, false, false)
		if a_extra.new and not b_extra.new then
			return true
		elseif b_extra.new and not a_extra.new then
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
		local a_extra, b_extra = get_items_extra(a, b, view, true, false, false, false)
		if not mod:get("entire_category_on_top") then
			if a_extra.new and not b_extra.new then
				return true
			elseif b_extra.new and not a_extra.new then
				return false
			end
			return nil
		end

		if a_extra.type_new and not b_extra.type_new then
			return true
		elseif b_extra.type_new and not a_extra.type_new then
			return false
		end
		return nil
	end
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
		local a_extra, b_extra = get_items_extra(a, b, view, false, true, false, false)
		if a_extra.equipped and not b_extra.equipped then
			return true
		elseif b_extra.equipped and not a_extra.equipped then
			return false
		elseif a_extra.equipped and b_extra.equipped then
			if a_extra.current and not b_extra.current then
				return true
			elseif b_extra.current and not a_extra.current then
				return false
			end
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
		local a_extra, b_extra = get_items_extra(a, b, view, false, true, true, false)
		if not mod:get("entire_category_on_top") then
			if a_extra.equipped and not b_extra.equipped then
				return true
			elseif b_extra.equipped and not a_extra.equipped then
				return false
			elseif a_extra.equipped and b_extra.equipped then
				if a_extra.current and not b_extra.current then
					return true
				elseif b_extra.current and not a_extra.current then
					return false
				end
			end
			return nil
		end
		if a_extra.type_equipped and not b_extra.type_equipped then
			return true
		elseif b_extra.type_equipped and not a_extra.type_equipped then
			return false
		end
		return nil
	end
end

local function compare_item_myfav(view)
	local class = view.__class_name
	if not class or (class ~= "InventoryWeaponsView" and class ~= "CraftingModifyView") then
		return function(a, b)
			return nil
		end
	end
	return function(a, b)
		if not mod:get("always_on_top_myfav") then
			return nil
		end
		local a_extra, b_extra = get_items_extra(a, b, view, false, false, false, false)
		if a_extra.myfav and not b_extra.myfav then
			return true
		elseif b_extra.myfav and not a_extra.myfav then
			return false
		elseif a_extra.myfav and b_extra.myfav then
			if a_extra.myfav < b_extra.myfav then
				return true
			elseif b_extra.myfav < a_extra.myfav then
				return false
			end
		end
		return nil
	end
end

local function compare_item_type_myfav(view)
	local class = view.__class_name
	if not class or (class ~= "InventoryWeaponsView" and class ~= "CraftingModifyView") then
		return function(a, b)
			return nil
		end
	end
	return function(a, b)
		if not mod:get("always_on_top_myfav") then
			return nil
		end
		local a_extra, b_extra = get_items_extra(a, b, view, false, false, false, true)
		if not mod:get("entire_category_on_top") then
			if a_extra.myfav and not b_extra.myfav then
				return true
			elseif b_extra.myfav and not a_extra.myfav then
				return false
			elseif a_extra.myfav and b_extra.myfav then
				if a_extra.myfav < b_extra.myfav then
					return true
				elseif b_extra.myfav < a_extra.myfav then
					return false
				end
			end
			return nil
		end
		if a_extra.type_myfav and not b_extra.type_myfav then
			return true
		elseif b_extra.type_myfav and not a_extra.type_myfav then
			return false
		end
		return nil
	end
end

local function compare_item_category_top_items(view)
	return function(a, b)
		local a_extra, b_extra = get_items_extra(a, b, view, true, true, true, false)
		local a_category = a.trait_category or ""
		local b_category = b.trait_category or ""

		if a_category == b_category then
			if mod:get("always_on_top_new") and mod:get("on_top_of_category") then
				if a_extra.new and not b_extra.new then
					return true
				elseif b_extra.new and not a_extra.new then
					return false
				end
			end
			if mod:get("always_on_top_equipped") and mod:get("on_top_of_category") then
				if a_extra.equipped and not b_extra.equipped then
					return true
				elseif b_extra.equipped and not a_extra.equipped then
					return false
				end
				if a_extra.current and not b_extra.current then
					return true
				elseif b_extra.current and not a_extra.current then
					return false
				end
			end
			if mod:get("always_on_top_myfav") and mod:get("on_top_of_category") then
				if a_extra.myfav and not b_extra.myfav then
					return true
				elseif b_extra.myfav and not a_extra.myfav then
					return false
				elseif a_extra.myfav and b_extra.myfav then
					if a_extra.myfav < b_extra.myfav then
						return true
					elseif b_extra.myfav < a_extra.myfav then
						return false
					end
				end
			end
		elseif a_extra.type_equipped and b_extra.type_equipped then
			if a_extra.type_current and not b_extra.type_current then
				return true
			elseif b_extra.type_current and not a_extra.type_current then
				return false
			end
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
			{"<", compare_item_myfav},
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
			{"<", compare_item_myfav},
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
			{"<", compare_item_type_myfav},
			{"<", compare_item_category_top_items},
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
			{"<", compare_item_type_myfav},
			{"<", compare_item_category_top_items},
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
			{"<", compare_item_myfav},
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
			{"<", compare_item_myfav},
			{">", wrap(ItemUtils.compare_item_level)},
			{"<", wrap(ItemUtils.compare_item_rarity)},
			{">", wrap(ItemUtils.compare_item_type)},
			{"<", wrap(ItemUtils.compare_item_name)},
		},
	},
}

mod.on_enabled = function(initial_call)
	local old_rem_value = mod:get("rem_sort_index")
	if old_rem_value then
		mod:set("rem_sort_index_view_inventory_weapons_view", old_rem_value)
		mod:set("rem_sort_index_view_crafting_modify_view", old_rem_value)
		mod:set("rem_sort_index", nil)
	end
end

local function is_cosmetics_or_store(object)
	if object._optional_store_service ~= nil then
		return true
	end
	if object.view_name then
		if object.view_name == "inventory_cosmetics_view" then
			return true
		end
		if object.view_name == "inventory_weapon_cosmetics_view" then
			return true
		end
	end
	return false
end

local function is_blacklist_view(object)
	if object.view_name then
		if object.view_name == "inventory_weapon_cosmetics_view" then
			return true
		end
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

local function setup_rem_sorting(self)
	if not is_cosmetics_or_store(self) then
		set_extra_sort(self)
	end
	if is_blacklist_view(self) then
		return
	end

	if mod:get("remember_sort_index") then
		local view_rem_key = get_view_rem_key(self)
		if not view_rem_key then
			return
		end

		local options = self._sort_options
		if not options then
			return
		end
		local length = #options
		local index = mod:get(view_rem_key) or 1
		if length < 1 then
			return
		end
		if index > length then
			index = 1
		end
		local option = options[index]
		self._selected_sort_option_index = index
		self._selected_sort_option = option
		self:trigger_sort_index(index)
	end
end

mod:hook_safe(ItemGridViewBase, "on_enter", function(self)
	if self._item_grid._widgets_by_name.grid_loading.content.is_loading then
		return
	end
	setup_rem_sorting(self)
end)

mod:hook_safe(InventoryCosmeticsView, "_setup_sort_options", function(self)
	setup_rem_sorting(self)
end)

mod:hook_safe(ItemGridViewBase, "on_exit", function(self)
	local view_rem_key = get_view_rem_key(self)
	if not view_rem_key then
		return
	end

	if not mod:get("remember_sort_index") then
		mod:set(view_rem_key, nil)
		return
	end

	if self._selected_sort_option_index == nil then
		return
	end
	mod:set(view_rem_key, self._selected_sort_option_index)
end)
