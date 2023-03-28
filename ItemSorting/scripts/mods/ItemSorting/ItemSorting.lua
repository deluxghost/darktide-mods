local mod = get_mod("ItemSorting")
local ItemUtils = require("scripts/utilities/items")
local ItemGridViewBase = require("scripts/ui/views/item_grid_view_base/item_grid_view_base")

local function compare_item_category(a, b)
	local a_category = a.trait_category or ""
	local b_category = b.trait_category or ""

	if a_category < b_category then
		return true
	elseif b_category < a_category then
		return false
	end
	return nil
end

local function compare_item_base_level(a, b)
	local a_level = a.baseItemLevel or 0
	local b_level = b.baseItemLevel or 0

	if a_level < b_level then
		return true
	elseif b_level < a_level then
		return false
	end
	return nil
end

local custom_sorts = {
	custom_sort_category = {
		display_name = mod:localize("custom_sort_category"),
		sort_function = ItemUtils.sort_comparator({
			">",
			compare_item_category,
			">",
			ItemUtils.compare_item_rarity,
			">",
			ItemUtils.compare_item_level,
			">",
			ItemUtils.compare_item_type,
			"<",
			ItemUtils.compare_item_name,
		})
	},
	custom_sort_rarity = {
		display_name = mod:localize("custom_sort_rarity"),
		sort_function = ItemUtils.sort_comparator({
			">",
			ItemUtils.compare_item_rarity,
			">",
			ItemUtils.compare_item_level,
			">",
			ItemUtils.compare_item_type,
			"<",
			ItemUtils.compare_item_name,
		})
	},
	custom_sort_base_level = {
		display_name = mod:localize("custom_sort_base_level"),
		sort_function = ItemUtils.sort_comparator({
			">",
			compare_item_base_level,
			">",
			ItemUtils.compare_item_level,
			"<",
			ItemUtils.compare_item_rarity,
			">",
			ItemUtils.compare_item_type,
			"<",
			ItemUtils.compare_item_name,
		})
	},
}

local rem_sort_index_key = "rem_sort_index"
local memory = mod:persistent_table("memory")

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
		for name, sort_def in pairs(custom_sorts) do
			if mod:get(name) then
				table.insert(self._sort_options, sort_def)
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
