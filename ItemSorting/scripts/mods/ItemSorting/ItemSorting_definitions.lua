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
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "level_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
					"<", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "rarity_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "rarity_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
					"<", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "name_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_increasing_letters", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_name")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "name_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_decreasing_letters", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_name")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_new,
					"<", "item", ItemSortingUtils.compare_item_equipped,
					"<", "item", ItemSortingUtils.compare_item_myfav,
					">", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			}
		},
		store = {
			{
				id = "level_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "level_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
					"<", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "rarity_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "rarity_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
					"<", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "price_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_price")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "offer", ItemUtils.compare_offer_price,
					"<", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
					"<", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "price_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_item_price")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					">", "offer", ItemUtils.compare_offer_price,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "name_asc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_increasing_letters", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_name")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "name_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_decreasing_letters", true, {
					sort_name = Localize("loc_inventory_item_grid_sort_title_name")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					">", "item", ItemUtils.compare_item_name,
					">", "item", ItemUtils.compare_item_level,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			}
		},
	},
	modded_methods = {
		inventory = {
			{
				id = "category",
				display_name = mod:localize("custom_sort_category"),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_type_new,
					"<", "item", ItemSortingUtils.compare_item_type_equipped,
					"<", "item", ItemSortingUtils.compare_item_type_myfav,
					"<", "item", ItemSortingUtils.compare_item_category_top_items,
					"<", "item", ItemSortingUtils.compare_item_category,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "category_mark",
				display_name = mod:localize("custom_sort_category_mark"),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					"<", "item", ItemSortingUtils.compare_item_type_new,
					"<", "item", ItemSortingUtils.compare_item_type_equipped,
					"<", "item", ItemSortingUtils.compare_item_type_myfav,
					"<", "item", ItemSortingUtils.compare_item_category_top_items,
					"<", "item", ItemSortingUtils.compare_item_category,
					">", "item", ItemSortingUtils.compare_item_mark,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "base_level_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_weapon_stats_display_base_rating")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
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
				sort_function = ItemSortingUtils.sort_element_key_comparator({
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
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_category,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "category_mark",
				display_name = mod:localize("custom_sort_category_mark"),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
					"<", "item", ItemSortingUtils.compare_item_category,
					">", "item", ItemSortingUtils.compare_item_mark,
					">", "item", ItemUtils.compare_item_rarity,
					">", "item", ItemUtils.compare_item_level,
					"<", "item", ItemUtils.compare_item_name,
					">", "item", ItemSortingUtils.compare_item_base_level,
				})
			},
			{
				id = "base_level_desc",
				display_name = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
					sort_name = Localize("loc_weapon_stats_display_base_rating")
				}),
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
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
				sort_function = ItemSortingUtils.sort_element_key_comparator({
					">", "offer", ItemSortingUtils.compare_offer_owned,
					"<", "item", ItemSortingUtils.compare_item_top_curios,
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
