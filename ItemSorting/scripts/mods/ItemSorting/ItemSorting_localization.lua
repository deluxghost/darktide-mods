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
	always_on_top_store_unearned_blessing = {
		en = "Items with unearned blessings (Store)",
		["zh-cn"] = "含有未获取祝福的物品（商店）",
		ru = "Предметы с неизученными Благословениями (Магазин)",
	},
	always_on_top_store_unearned_blessing_description = {
		en = "Items with unearned (higher tier) blessings, i.e. the \"green\" blessings in some mods, are always at the top of the store item list.",
		["zh-cn"] = "含有未获取（更高等级）祝福，也就是在一些模组中标记为“绿色”祝福的物品，总会显示在商店物品列表的顶部。",
		ru = "Предметы с неизученными благословениями (высокого уровня), то есть с «зелёными» благословениями в некоторых модах, всегда находятся вверху списка предметов в магазине.",
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
		en = "Favorite items (\"My Favorites\" mod)",
		["zh-cn"] = "收藏的物品（“我的收藏”模组）",
		ru = "Избранные предметы (мод «Моё избранное»)",
	},
	always_on_top_myfav_description = {
		en = "With \"My Favorites\" mod, favorite items are always at the top of the item list.",
		["zh-cn"] = "如果有“我的收藏（My Favorites）”模组，收藏的物品总会显示在物品列表的顶部。",
		ru = "С модом «Моё избранное» избранные предметы всегда находятся вверху списка предметов.",
	},
	group_always_on_top_options = {
		en = "Always on top options",
		["zh-cn"] = "总在最上选项",
		ru = "Опции «Всегда сверху»",
	},
	entire_category_on_top = {
		en = "Top entire blessing category",
		["zh-cn"] = "祝福分类整体置顶",
		ru = "Наверх всю категорию «Благословения»",
	},
	entire_category_on_top_description = {
		en = "When sorting by Blessing Category, if an item in the category is topped, the entire category is topped.",
		["zh-cn"] = "按祝福分类排序时，如果分类内有物品被置顶，则整个分类置顶。",
		ru = "При сортировке по категории «Благословения», если какой-либо предмет в категории занимает верхнее место, то оказывается наверху вся категория.",
	},
	on_top_of_category = {
		en = "Top inside blessing category",
		["zh-cn"] = "在祝福分类内置顶",
		ru = "Наверх внутри категории «Благословения»",
	},
	on_top_of_category_description = {
		en = "When sorting by Blessing Category, topped items are also topped in their category.",
		["zh-cn"] = "按祝福分类排序时，置顶的物品也在所属分类内置顶。",
		ru = "При сортировке по категории «Благословения», лучшие предметы также занимают первое место в своей категории.",
	},
	group_custom_sort = {
		en = "Extra item sorting methods",
		["zh-cn"] = "额外的物品排序方式",
		ru = "Дополнительные методы сортировки предметов",
	},
	custom_sort_category = {
		en = "Blessing Category",
		["zh-cn"] = "祝福分类",
		ru = "Благословения",
	},
	custom_sort_category_description = {
		en = "Weapons fall into same category share same blessing pool.",
		["zh-cn"] = "相同祝福分类下的武器共享同一个祝福池。",
		ru = "Оружие попадает в одну категорию, если имеет одинаковые Благословения.",
	},
	custom_sort_category_group_by_name = {
		en = "Blessing Category (Group by Name)",
		["zh-cn"] = "祝福分类（按名称分组）",
		ru = "Благословения (группировка по Имени)",
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
