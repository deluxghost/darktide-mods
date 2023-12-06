local mod = get_mod("ItemSorting")
local ItemUtils = require("scripts/utilities/items")
local ItemSortingUtils = mod:io_dofile("ItemSorting/scripts/mods/ItemSorting/ItemSorting_utils")

local definitions = {
	customized_vanilla_methods = {
		inventory = {
			{
				id = "level_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "level_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "rarity_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "rarity_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "name_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_increasing_letters", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_name")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
				})
			},
			{
				id = "name_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_decreasing_letters", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_name")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					">", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
				})
			}
		},
		store = {
			{
				id = "level_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "level_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "rarity_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "rarity_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "price_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_price")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					"<", "offer", ItemUtils.compare_offer_price,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "price_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_price")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					">", "offer", ItemUtils.compare_offer_price,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "name_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_increasing_letters", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_name")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
				})
			},
			{
				id = "name_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_decreasing_letters", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_name")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					">", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
				})
			}
		},
	},
	modded_methods = {
		inventory = {
			{
				id = "category",
				display_name = mod:localize("custom_sort_category"),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemSortingUtils.compare_item_category_top_items,
					">", "item", ItemSortingUtils.compare_item_category,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "category_group_by_name",
				display_name = mod:localize("custom_sort_category_group_by_name"),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemSortingUtils.compare_item_category_top_items,
					">", "item", ItemSortingUtils.compare_item_category,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
				})
			},
			{
				id = "base_level_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_weapon_stats_display_base_rating")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					">", "item", ItemSortingUtils.compare_item_base_level,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "base_level_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_weapon_stats_display_base_rating")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemSortingUtils.compare_item_base_level,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
		},
		store = {
			{
				id = "category",
				display_name = mod:localize("custom_sort_category"),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					">", "item", ItemSortingUtils.compare_item_category,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "category_group_by_name",
				display_name = mod:localize("custom_sort_category_group_by_name"),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					">", "item", ItemSortingUtils.compare_item_category,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
				})
			},
			{
				id = "base_level_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_weapon_stats_display_base_rating")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					">", "item", ItemSortingUtils.compare_item_base_level,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
			{
				id = "base_level_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_weapon_stats_display_base_rating")
				}),
				sort_function = ItemUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_top_unearned_blessings,
					"<", "item", ItemSortingUtils.compare_item_base_level,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
				})
			},
		},
	},
}

return definitions
