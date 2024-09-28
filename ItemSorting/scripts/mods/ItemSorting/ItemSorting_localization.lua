return {
	mod_name = {
		en = "Item Sorting",
		["zh-cn"] = "物品排序",
		ru = "Сортировка предметов",
	},
	mod_description = {
		en = "Add extra item sorting options and allow toggling vanilla sorting methods.",
		["zh-cn"] = "添加额外的物品排序选项，并且允许开关原版的排序方式。",
		ru = "Item Sorting - Добавляет дополнительные параметры сортировки предметов и позволяет переключать стандартные методы сортировки.",
	},
	group_always_on_top = {
		en = "Always on top",
		["zh-cn"] = "总在最上",
		ru = "Всегда сверху",
	},
	always_on_top_curio = {
		en = "Curios (Store)",
		["zh-cn"] = "附件（商店）",
		ru = "Устройства (Магазин)",
	},
	always_on_top_curio_description = {
		en = "Curios are always at the top of the store item list.",
		["zh-cn"] = "附件总会显示在商店物品列表的顶部。",
		ru = "Устройства всегда находятся вверху списка товаров в магазине.",
	},
	always_on_top_new = {
		en = "New items",
		["zh-cn"] = "新物品",
		ru = "Новые предметы",
	},
	always_on_top_new_description = {
		en = "Items with the \"New Item\" dot are always at the top of the item list.",
		["zh-cn"] = "有“新物品”圆点的物品总会显示在物品列表的顶部。",
		ru = "Предметы с точкой «Новый предмет» всегда находятся вверху списка предметов.",
	},
	always_on_top_equipped = {
		en = "Equipped items",
		["zh-cn"] = "已装备的物品",
		ru = "Экипированнные предметы",
	},
	always_on_top_equipped_description = {
		en = "Items equipped in any Wargear Set are always at the top of the item list.",
		["zh-cn"] = "在任何战具套组中已装备的物品总会显示在物品列表的顶部。",
		ru = "Предметы, экипированные в любом Наборе снаряжения, всегда находятся вверху списка предметов.",
	},
	always_on_top_myfav = {
		en = "Favorite items",
		["zh-cn"] = "收藏的物品",
		ru = "Избранные предметы",
	},
	always_on_top_myfav_description = {
		en = "Favorite items are always at the top of the item list. ",
		["zh-cn"] = "收藏的物品总会显示在物品列表的顶部。",
	},
	group_always_on_top_options = {
		en = "Always on top options",
		["zh-cn"] = "总在最上选项",
		ru = "Опции «Всегда сверху»",
	},
	entire_category_on_top = {
		en = "Top entire group of same \"Family\"",
		["zh-cn"] = "相同“类别”整体置顶",
	},
	entire_category_on_top_description = {
		en = "When sorting by \"Family\", if an item in the family is topped, the entire family is topped.",
		["zh-cn"] = "按“类别”排序时，如果类别内有物品被置顶，则整个类别置顶。",
	},
	on_top_of_category = {
		en = "Top inside group of same \"Family\"",
		["zh-cn"] = "在相同“类别”内置顶",
	},
	on_top_of_category_description = {
		en = "When sorting by \"Family\", topped items are also topped in their family.",
		["zh-cn"] = "按“类别”排序时，置顶的物品也在所属类别内置顶。",
	},
	group_custom_sort = {
		en = "Extra item sorting methods",
		["zh-cn"] = "额外的物品排序方式",
		ru = "Дополнительные методы сортировки предметов",
	},
	custom_sort_category = {
		en = "Family",
		["zh-cn"] = "类别",
	},
	custom_sort_category_description = {
		en = "Former \"Blessing Category\" method",
		["zh-cn"] = "原“祝福分类”方式",
	},
	custom_sort_category_mark = {
		en = "Family + Mark",
		["zh-cn"] = "类别 + 型号",
	},
	custom_sort_category_mark_description = {
		en = "Former \"Blessing Category (Group by Mark)\" method",
		["zh-cn"] = "原“祝福分类（按型号分组）”方式",
	},
	custom_sort_base_level_desc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
			sort_name = Localize("loc_weapon_stats_display_base_rating")
		}),
	},
	custom_sort_base_level_asc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
			sort_name = Localize("loc_weapon_stats_display_base_rating")
		}),
	},
	group_enable_vanilla_sort = {
		en = "Enable vanilla sorting methods for gears",
		["zh-cn"] = "为装备启用原版排序方式",
		ru = "Включить стандартные методы сортировки для снаряжения.",
	},
	enable_vanilla_level_desc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
			sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
		}),
	},
	enable_vanilla_level_asc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
			sort_name = Localize("loc_inventory_item_grid_sort_title_item_power")
		}),
	},
	enable_vanilla_rarity_desc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
			sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
		}),
	},
	enable_vanilla_rarity_asc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
			sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
		}),
	},
	enable_vanilla_name_asc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_increasing_letters", true, {
			sort_name = Localize("loc_inventory_item_grid_sort_title_name")
		}),
	},
	enable_vanilla_name_desc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_decreasing_letters", true, {
			sort_name = Localize("loc_inventory_item_grid_sort_title_name")
		}),
	},
	enable_vanilla_price_asc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_low_high", true, {
			sort_name = Localize("loc_inventory_item_grid_sort_title_item_price")
		}),
	},
	enable_vanilla_price_desc = {
		en = Localize("loc_inventory_item_grid_sort_title_format_high_low", true, {
			sort_name = Localize("loc_inventory_item_grid_sort_title_item_price")
		}),
	},
}
