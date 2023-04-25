return {
	mod_name = {
		en = "Quick Look Card",
		["zh-cn"] = "快速信息卡",
		ru = "Карточка быстрого просмотра",
	},
	mod_description = {
		en = "Check weapon stats in item list quickly.",
		["zh-cn"] = "在物品列表快速查看武器数据。",
		ja = "アイテム一覧で素早く武器のステータスを確認できるようになります。",
		ru = "Quick Look Card - Позволяет быстро узнать характеристики оружия в списке предметов.",
	},

	opt_group_toggles = {
		en = "Toggles",
		["zh-cn"] = "开关",
		ja = "切り替え",
		ru = "Включение/Выключение",
	},
	opt_base_level = {
		en = Localize("loc_weapon_stats_display_base_rating"),
	},
	opt_base_level_description = {
		en = "{#color(85,235,50)}Redeemed+{#reset()} weapons only",
		["zh-cn"] = "仅限{#color(85,235,50)}救赎{#reset()}及以上武器",
		ja = "{#color(85,235,50)}救罪{#reset()}以上の武器のみ",
		ru = "Только {#color(85,235,50)}Зелёное{#reset()} оружие и выше",
	},
	opt_modifier = {
		en = "Modifier Stats",
		["zh-cn"] = "五维数据",
		ja = "ステータス補正",
		ru = "Модификаторы",
	},
	opt_modifier_description = {
		en = "Weapons only",
		["zh-cn"] = "仅限武器",
		ja = "武器のみ",
		ru = "Только для оружия",
	},
	opt_blessing = {
		en = Localize("loc_weapon_inventory_traits_title_text"),
	},
	opt_blessing_description = {
		en = "Weapons only\nIncludes: lock indicator, rarity indicator with ownership color",
		["zh-cn"] = "仅限武器\n包括：锁定指示、带拥有状态颜色的稀有度指示",
		ja = "武器のみ\n内容：ロック表示、色による未獲得通知付きのレア度表示",
		ru = "Только для оружия\nВключает для Благословений: индикатор блокировки, цифру редкости, с выделением неполученного благословения зелёным цветом",
	},
	opt_perk = {
		en = Localize("loc_item_type_perk"),
	},
	opt_perk_description = {
		en = "Includes: rarity indicator with lock color",
		["zh-cn"] = "包括：带锁定状态颜色的稀有度指示",
		ja = "内容：色によるロック表示付きのレア度表示",
		ru = "Включает для Улучшений: индикатор редкости, с выделением заблокированных улучшений красным цветом",
	},
	opt_curio_blessing = {
		en = "Curio Blessings",
		["zh-cn"] = "珍品祝福",
		ja = "収集品の祝福",
		ru = "Благословения устройств",
	},
	opt_curio_blessing_description = {
		en = "Curios only",
		["zh-cn"] = "仅限珍品",
		ja = "収集品のみ",
		ru = "Только для устройств",
	},

	-- To translators: due to the limited screen space,
	-- these following stat translations should be abbreviations form
	-- and should not be longer than 4 Latin characters (or 2 CJK characters).
	-- The original localization was added for reference, which might be outdated.

	-- Weapon modifiers
	stat_loc_glossary_term_melee_damage = {
		en = "MELE", -- Melee Damage
		["zh-cn"] = "近战", -- 近战伤害
		ja = "近接", -- 近接ダメージ
		ru = "ББОЙ", -- Ближний бой
	},
	stat_loc_stats_display_ammo_stat = {
		en = "AMMO", -- Ammo
		["zh-cn"] = "弹药", -- 弹药
		ja = "弾薬", -- 弾薬
		ru = "БОЕП", -- Боеприпасы
	},
	stat_loc_stats_display_ap_stat = {
		en = "PNT", -- Penetration
		["zh-cn"] = "穿透", -- 穿透
		ja = "貫通", -- 貫通力
		ru = "ПРОБ", -- Пробивная сила
	},
	stat_loc_stats_display_burn_stat = {
		en = "BURN", -- Burn
		["zh-cn"] = "燃烧", -- 燃烧
		ja = "燃焼", -- 燃焼
		ru = "ГОРЕ", -- Горение
	},
	stat_loc_stats_display_charge_speed = {
		en = "CHRG", -- Charge Rate
		["zh-cn"] = "充能", -- 充能速度
		ja = "溜率", -- チャージ率
		ru = "СЗАР", -- Скорость заряжания
	},
	stat_loc_stats_display_cleave_damage_stat = {
		en = "CDMG", -- Cleave Damage
		["zh-cn"] = "劈伤", -- 劈裂伤害
		ja = "斬威", -- 斬撃ダメージ
		ru = "УРАС", -- Урон рассечением
	},
	stat_loc_stats_display_cleave_targets_stat = {
		en = "CTGT", -- Cleave Targets
		["zh-cn"] = "劈数", -- 劈裂目标数
		ja = "斬数", -- 斬撃ターゲット数
		ru = "РАСЦ", -- Рассечение целей
	},
	stat_loc_stats_display_control_stat_melee = {
		en = "CC", -- Crowd Control
		["zh-cn"] = "控场", -- 控场
		ja = "群管", -- 群衆管理
		ru = "СДРЖ", -- Сдерживание толпы
	},
	stat_loc_stats_display_control_stat_ranged = {
		en = "CLTR", -- Collateral
		["zh-cn"] = "远控", -- 远程控制力
		ja = "副次", -- コラテラル
		ru = "СОПУ", -- Сопутствующий
	},
	stat_loc_stats_display_crit_stat = {
		en = "CRIT", -- Critical Bonus
		["zh-cn"] = "暴击", -- 暴击加成
		ja = "致命", -- クリティカルボーナス
		ru = "КРИТ", -- Критический бонус
	},
	stat_loc_stats_display_damage_stat = {
		en = "DMG", -- Damage
		["zh-cn"] = "伤害", -- 伤害
		ja = "威力", -- ダメージ
		ru = "УРОН", -- Урон
	},
	stat_loc_stats_display_defense_stat = {
		en = "DEF", -- Defences
		["zh-cn"] = "防御", -- 防御
		ja = "守備", -- 守備力
		ru = "ОБОР", -- Оборона
	},
	stat_loc_stats_display_explosion_ap_stat = {
		en = "PNTB", -- Penetration (Blast)
		["zh-cn"] = "爆穿", -- 穿透（爆炸）
		ja = "爆貫", -- 貫通力 (爆発)
		ru = "ПСВЗ", -- Пробивная сила (Взрыв)
	},
	stat_loc_stats_display_explosion_damage_stat = {
		en = "BLST", -- Blast Damage
		["zh-cn"] = "爆伤", -- 爆炸伤害
		ja = "爆威", -- 爆発ダメージ
		ru = "ВЗУР", -- Взрывной урон
	},
	stat_loc_stats_display_explosion_stat = {
		en = "BLSR", -- Blast Radius
		["zh-cn"] = "爆距", -- 爆炸范围
		ja = "爆径", -- 爆破半径
		ru = "РАДВ", -- Радиус взрыва
	},
	stat_loc_stats_display_finesse_stat = {
		en = "FNS", -- Finesse
		["zh-cn"] = "娴熟", -- 武器娴熟
		ja = "策謀", -- 策謀
		ru = "ТОЧН", -- Точность
	},
	stat_loc_stats_display_first_saw_damage = {
		en = "SRD", -- Shredder
		["zh-cn"] = "撕裂", -- 撕裂
		ja = "断裂", -- シュレッダー
		ru = "КРОШ", -- Крошитель
	},
	stat_loc_stats_display_first_target_stat = {
		en = "FTGT", -- First Target
		["zh-cn"] = "首个", -- 首个目标
		ja = "第一", -- 第一ターゲット
		ru = "ПЕРВ", -- Первоочередная цель
	},
	stat_loc_stats_display_flame_size_stat = {
		en = "CLDR", -- Cloud Radius
		["zh-cn"] = "火距", -- 火云范围
		ja = "散布", -- 散布半径
		ru = "РАДР", -- Радиус распространения
	},
	stat_loc_stats_display_heat_management = {
		en = "TRES", -- Thermal Resistance
		["zh-cn"] = "热阻", -- 热阻
		ja = "熱耐", -- 熱耐性
		ru = "ТЕПЛ", -- Тепловая стойкость
	},
	stat_loc_stats_display_mobility_stat = {
		en = "MOB", -- Mobility
		["zh-cn"] = "机动", -- 机动性
		ja = "機動", -- モビリティ
		ru = "МОБИ", -- Мобильность
	},
	stat_loc_stats_display_power_output = {
		en = "PWR", -- Power Output
		["zh-cn"] = "能量", -- 能量输出
		ja = "電力", -- (電力) 出力
		ru = "ВЫБР", -- Выброс силы
	},
	stat_loc_stats_display_power_stat = {
		en = "STPW", -- Stopping Power
		["zh-cn"] = "制动", -- 制动能力
		ja = "抑止", -- 抑止力
		ru = "ОСТС", -- Останавливающая сила
	},
	stat_loc_stats_display_range_stat = {
		en = "RNGE", -- Range
		["zh-cn"] = "范围", -- 攻击范围
		ja = "範囲", -- 範囲
		ru = "ДАЛЬ", -- Дальность
	},
	stat_loc_stats_display_reload_speed_stat = {
		en = "RLD", -- Reload Speed
		["zh-cn"] = "装弹", -- 装弹速度
		ja = "装弾", -- リロード速度
		ru = "СПЕР", -- Скорость перезарядки
	},
	stat_loc_stats_display_stability_stat = {
		en = "STB", -- Stability
		["zh-cn"] = "稳定", -- 稳定性
		ja = "安定", -- 安定性
		ru = "СТАБ", -- Стабильность
	},
	stat_loc_stats_display_vent_speed = {
		en = "QUEL", -- Quell Speed
		["zh-cn"] = "冷却", -- 平息与冷却速度
		ja = "抑制", -- 速度抑制
		ru = "СПОД", -- Скорость подавления
	},
	stat_loc_stats_display_warp_resist_stat = {
		en = "WRES", -- Warp Resistance
		["zh-cn"] = "亚抗", -- 亚空间抗性
		ja = "歪耐", -- ワープ耐性
		ru = "ВАРП", -- Сопротивление варпу
	},

	-- Curio blessings
	gadget_trait_max_health = {
		en = "HP", -- Max Health
		["zh-cn"] = "生命", -- 最大生命值
		ja = "体力", -- 最大ヘルス
		ru = "ЗДОР", -- Здоровье
	},
	gadget_trait_toughness = {
		en = "TN", -- Toughness
		["zh-cn"] = "韧性", -- 韧性
		ja = "靭性", -- 最大タフネス
		ru = "СТЙК", -- Стойкость
	},
	gadget_trait_max_stamina = {
		en = "STAM", -- Max Stamina
		["zh-cn"] = "体力", -- 最大体力
		ja = "活力", -- 最大スタミナ
		ru = "ВНСЛ", -- Выносливость
	},
	gadget_trait_wounds = {
		en = "WND", -- Wound(s)
		["zh-cn"] = "伤口", -- 生命格
		ja = "傷口", -- 傷口
		ru = "РАНЫ", -- Дополнительные раны
	},
}
