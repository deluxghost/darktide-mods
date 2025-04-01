return {
	mod_name = {
		en = "Quick Look Card",
		["zh-cn"] = "快速信息卡",
		ru = "Карточка быстрого просмотра",
		["zh-tw"] = "快速資訊卡",
	},
	mod_description = {
		en = "Check weapon stats in item list quickly.",
		["zh-cn"] = "在物品列表快速查看武器数据。",
		ja = "アイテム一覧で素早く武器のステータスを確認できるようになります。",
		ru = "Quick Look Card - Позволяет быстро узнать характеристики оружия в списке предметов.",
		["zh-tw"] = "可在物品列表中快速檢視武器屬性。",
	},

	opt_modifier_mode = {
		en = "Modifier Stats display mode",
		["zh-cn"] = "五维数据显示模式",
		ru = "Режим отображения характеристик модификаторов",
		["zh-tw"] = "五維數據顯示模式",
	},
	opt_modifier_mode_current = {
		en = "Current value",
		["zh-cn"] = "当前值",
		ja = "現在の値",
		ru = "Текущее значение",
		["zh-tw"] = "目前數值",
	},
	opt_modifier_mode_potential = {
		en = "Potential value",
		["zh-cn"] = "潜力值",
		ja = "最大値",
		ru = "Возможное значение",
		["zh-tw"] = "潛力值",
	},
	opt_highlight_dump_stat = {
		en = "Highlight lowest modifier stat",
		["zh-cn"] = "高亮显示五维短板",
		ja = "最も値の低い補正値をハイライトする",
		ru = "Подсвечивать самое низкое значение модификаторов",
		["zh-tw"] = "高亮顯示最低的五維屬性數值",
	},
	opt_group_toggles = {
		en = "Toggles",
		["zh-cn"] = "开关",
		ja = "切り替え",
		ru = "Включение/Выключение",
		["zh-tw"] = "切換",
	},
	opt_base_level = {
		en = Localize("loc_weapon_stats_display_base_rating"),
	},
	opt_modifier = {
		en = "Modifier Stats",
		["zh-cn"] = "五维数据",
		ja = "ステータス補正",
		ru = "Модификаторы",
		["zh-tw"] = "五維數據",
	},
	opt_modifier_description = {
		en = "Weapons only",
		["zh-cn"] = "仅限武器",
		ja = "武器のみ",
		ru = "Только для оружия",
		["zh-tw"] = "僅限武器",
	},
	opt_blessing = {
		en = Localize("loc_weapon_inventory_traits_title_text"),
	},
	opt_blessing_description = {
		en = "Weapons only",
		["zh-cn"] = "仅限武器",
		ja = "武器のみ",
		ru = "Только для оружия",
		["zh-tw"] = "僅適用於武器",
	},
	opt_perk = {
		en = Localize("loc_item_type_perk"),
	},
	opt_perk_description = {
		en = "Weapons only",
		["zh-cn"] = "仅限武器",
		ja = "武器のみ",
		ru = "Только для оружия",
		["zh-tw"] = "僅適用於武器",
	},
	opt_curio_blessing = {
		en = "Curio Blessings",
		["zh-cn"] = "附件祝福",
		ja = "収集品の祝福",
		ru = "Благословения устройств",
		["zh-tw"] = "飾品祝福",
	},
	opt_curio_blessing_description = {
		en = "Curios only",
		["zh-cn"] = "仅限附件",
		ja = "収集品のみ",
		ru = "Только для устройств",
		["zh-tw"] = "僅適用於飾品",
	},
	opt_curio_perk = {
		en = "Curio Perk",
		["zh-cn"] = "附件专长",
		ja = "収集品のパーク",
		ru = "Улучшения устройств",
		["zh-tw"] = "飾品專長",
	},
	opt_curio_perk_description = {
		en = "Curios only",
		["zh-cn"] = "仅限附件",
		ja = "収集品のみ",
		ru = "Только для диковинок",
		["zh-tw"] = "僅適用於飾品",
	},

	-- To translators: due to the limited screen space,
	-- these following stat, perk and blessing translations should be abbreviations form
	-- and should not be longer than 4 Latin characters (or 2 CJK characters).
	-- The original localization was added for reference, which might be outdated.

	-- Weapon modifiers
	stat_loc_glossary_term_melee_damage = {
		en = "MELE", -- Melee Damage
		["zh-cn"] = "近战", -- 近战伤害
		ja = "近接", -- 近接ダメージ
		ru = "ББОЙ", -- Ближний бой
		["zh-tw"] = "近戰", -- 近戰傷害
	},
	stat_loc_stats_display_ammo_stat = {
		en = "AMMO", -- Ammo
		["zh-cn"] = "弹药", -- 弹药
		ja = "弾薬", -- 弾薬
		ru = "БОЕП", -- Боеприпасы
		["zh-tw"] = "彈藥", -- 彈藥
	},
	stat_loc_stats_display_ap_stat = {
		en = "PNT", -- Penetration
		["zh-cn"] = "穿透", -- 穿透
		ja = "貫通", -- 貫通力
		ru = "ПРОБ", -- Пробивная сила
		["zh-tw"] = "穿透", -- 穿透
	},
	stat_loc_stats_display_burn_stat = {
		en = "BURN", -- Burn
		["zh-cn"] = "燃烧", -- 燃烧
		ja = "燃焼", -- 燃焼
		ru = "ГОРЕ", -- Горение
		["zh-tw"] = "燃燒", -- 燃燒
	},
	stat_loc_stats_display_charge_speed = {
		en = "CHRG", -- Charge Rate
		["zh-cn"] = "充能", -- 充能速度
		ja = "溜率", -- チャージ率
		ru = "СЗАР", -- Скорость заряжания
		["zh-tw"] = "充能", -- 充能速度
	},
	stat_loc_stats_display_cleave_damage_stat = {
		en = "CDMG", -- Cleave Damage
		["zh-cn"] = "劈伤", -- 劈裂伤害
		ja = "斬威", -- 斬撃ダメージ
		ru = "РАСУ", -- Урон рассечением
		["zh-tw"] = "劈傷", -- 順劈傷害
	},
	stat_loc_stats_display_cleave_targets_stat = {
		en = "CTGT", -- Cleave Targets
		["zh-cn"] = "劈数", -- 劈裂目标数
		ja = "斬数", -- 斬撃ターゲット数
		ru = "РАСЦ", -- Рассечение целей
		["zh-tw"] = "劈數", -- 順劈目標數
	},
	stat_loc_stats_display_control_stat_melee = {
		en = "CC", -- Crowd Control
		["zh-cn"] = "控场", -- 控场
		ja = "群管", -- 群衆管理
		ru = "СДРЖ", -- Сдерживание толпы
		["zh-tw"] = "控場", -- 控場
	},
	stat_loc_stats_display_control_stat_ranged = {
		en = "CLTR", -- Collateral
		["zh-cn"] = "远控", -- 远程控制力
		ja = "副次", -- コラテラル
		ru = "СОПУ", -- Сопутствующий
		["zh-tw"] = "遠控", -- 遠程控制力
	},
	stat_loc_stats_display_crit_stat = {
		en = "CRIT", -- Critical Bonus
		["zh-cn"] = "暴击", -- 暴击加成
		ja = "致命", -- クリティカルボーナス
		ru = "КРИТ", -- Критический бонус
		["zh-tw"] = "暴擊", -- 暴擊加成
	},
	stat_loc_stats_display_damage_stat = {
		en = "DMG", -- Damage
		["zh-cn"] = "伤害", -- 伤害
		ja = "威力", -- ダメージ
		ru = "УРОН", -- Урон
		["zh-tw"] = "傷害", -- 傷害
	},
	stat_loc_stats_display_defense_stat = {
		en = "DEF", -- Defences
		["zh-cn"] = "防御", -- 防御
		ja = "守備", -- 守備力
		ru = "ОБОР", -- Оборона
		["zh-tw"] = "防禦", -- 防禦
	},
	stat_loc_stats_display_explosion_ap_stat = {
		en = "PNTB", -- Penetration (Blast)
		["zh-cn"] = "爆穿", -- 穿透（爆炸）
		ja = "爆貫", -- 貫通力 (爆発)
		ru = "ПВЗР", -- Пробивная сила (Взрыв)
		["zh-tw"] = "爆穿", -- 穿透（爆炸）
	},
	stat_loc_stats_display_explosion_damage_stat = {
		en = "BLST", -- Blast Damage
		["zh-cn"] = "爆伤", -- 爆炸伤害
		ja = "爆威", -- 爆発ダメージ
		ru = "УВЗР", -- Взрывной урон
		["zh-tw"] = "爆傷", -- 爆炸傷害
	},
	stat_loc_stats_display_explosion_stat = {
		en = "BLSR", -- Blast Radius
		["zh-cn"] = "爆距", -- 爆炸范围
		ja = "爆径", -- 爆破半径
		ru = "РВЗР", -- Радиус взрыва
		["zh-tw"] = "爆距", -- 爆炸範圍
	},
	stat_loc_stats_display_finesse_stat = {
		en = "FNS", -- Finesse
		["zh-cn"] = "娴熟", -- 武器娴熟
		ja = "策謀", -- 策謀
		ru = "ТОЧН", -- Точность
		["zh-tw"] = "技巧", -- 武器技巧
	},
	stat_loc_stats_display_first_saw_damage = {
		en = "SRD", -- Shredder
		["zh-cn"] = "撕裂", -- 撕裂
		ja = "断裂", -- シュレッダー
		ru = "КРОШ", -- Крошитель
		["zh-tw"] = "撕裂", -- 撕裂
	},
	stat_loc_stats_display_first_target_stat = {
		en = "FTGT", -- First Target
		["zh-cn"] = "首个", -- 首个目标
		ja = "第一", -- 第一ターゲット
		ru = "ПЕРВ", -- Первоочередная цель
		["zh-tw"] = "首個", -- 首個目標
	},
	stat_loc_stats_display_flame_size_stat = {
		en = "CLDR", -- Cloud Radius
		["zh-cn"] = "火距", -- 火云范围
		ja = "散布", -- 散布半径
		ru = "РАДР", -- Радиус распространения
		["zh-tw"] = "火距", -- 火焰範圍
	},
	stat_loc_stats_display_heat_management = {
		en = "TRES", -- Thermal Resistance
		["zh-cn"] = "热阻", -- 热阻
		ja = "熱耐", -- 熱耐性
		ru = "ТЕПС", -- Тепловая стойкость
		["zh-tw"] = "熱阻", -- 熱阻
	},
	stat_loc_stats_display_mobility_stat = {
		en = "MOB", -- Mobility
		["zh-cn"] = "机动", -- 机动性
		ja = "機動", -- モビリティ
		ru = "МОБИ", -- Мобильность
		["zh-tw"] = "移動", -- 移動性
	},
	stat_loc_stats_display_power_output = {
		en = "PWR", -- Power Output
		["zh-cn"] = "能量", -- 能量输出
		ja = "電力", -- (電力) 出力
		ru = "ВЫБС", -- Выброс силы
		["zh-tw"] = "能量", -- 能量輸出
	},
	stat_loc_stats_display_power_stat = {
		en = "STPW", -- Stopping Power
		["zh-cn"] = "制动", -- 制动能力
		ja = "抑止", -- 抑止力
		ru = "ОСТС", -- Останавливающая сила
		["zh-tw"] = "制動", -- 制動能力
	},
	stat_loc_stats_display_range_stat = {
		en = "RNGE", -- Range
		["zh-cn"] = "范围", -- 攻击范围
		ja = "範囲", -- 範囲
		ru = "ДАЛЬ", -- Дальность
		["zh-tw"] = "範圍", -- 攻擊範圍
	},
	stat_loc_stats_display_reload_speed_stat = {
		en = "RLD", -- Reload Speed
		["zh-cn"] = "装弹", -- 装弹速度
		ja = "装弾", -- リロード速度
		ru = "СПЕР", -- Скорость перезарядки
		["zh-tw"] = "裝彈", -- 裝填速度
	},
	stat_loc_stats_display_stability_stat = {
		en = "STB", -- Stability
		["zh-cn"] = "稳定", -- 稳定性
		ja = "安定", -- 安定性
		ru = "СТАБ", -- Стабильность
		["zh-tw"] = "穩定", -- 穩定性
	},
	stat_loc_stats_display_vent_speed = {
		en = "QUEL", -- Quell Speed
		["zh-cn"] = "冷却", -- 平息与冷却速度
		ja = "抑制", -- 速度抑制
		ru = "СПОД", -- Скорость подавления
		["zh-tw"] = "平息", -- 平息與冷卻速度
	},
	stat_loc_stats_display_warp_resist_stat = {
		en = "WRES", -- Warp Resistance
		["zh-cn"] = "亚抗", -- 亚空间抗性
		ja = "歪耐", -- ワープ耐性
		ru = "СВАР", -- Сопротивление варпу
		["zh-tw"] = "亞抗", -- 亞空間抗性
	},
	stat_loc_stats_display_heat_management_powersword_2h = {
		en = "HTMG", -- Heat Management
		["zh-cn"] = "热管", -- 热量管理
		ja = "熱制", -- 熱制御
		["zh-tw"] = "熱量", -- 熱量管理
	},

	-- Perks or blessings
	-- Some of them may not available in game yet
	trait_weapon_trait_increase_power = {
		en = "PWR", -- Power
		["zh-cn"] = "能量", -- 伤害与踉跄效果
		ja = "性能", -- パワー
		ru = "СИЛА", -- Сила
		["zh-tw"] = "能量", -- 造成額外傷害與硬直
	},
	trait_gadget_damage_reduction_vs_flamers = {
		en = "FLAM", -- Damage Resistance (Tox Flamers)
		["zh-cn"] = "火兵", -- 伤害抗性（剧毒火焰兵）
		ja = "火兵", -- ダメージ耐性 (トックス・フレイマー)
		ru = "СУТО", -- Сопротивление урону (Токсичные огневики)
		["zh-tw"] = "火兵", -- 對劇毒火焰兵的傷害抗性
	},
	trait_gadget_damage_reduction_vs_mutants = {
		en = "MUTN", -- Damage Resistance (Mutants)
		["zh-cn"] = "变种", -- 伤害抗性（变种人）
		ja = "変異", -- ダメージ耐性 (変異体)
		ru = "СУМУ", -- Сопротивление урону (Мутанты)
		["zh-tw"] = "突變", -- 對突變者的傷害抗性
	},
	trait_gadget_damage_reduction_vs_gunners = {
		en = "GUNR", -- Damage Resistance (Gunners)
		["zh-cn"] = "炮手", -- 伤害抗性（炮手）
		ja = "射手", -- ダメージ耐性 (ガンナー)
		ru = "СУПУ", -- Сопротивление урону (Пулемётчики)
		["zh-tw"] = "炮手", -- 對炮手的傷害抗性
	},
	trait_gadget_damage_reduction_vs_snipers = {
		en = "SNPR", -- Damage Resistance (Snipers)
		["zh-cn"] = "狙击", -- 伤害抗性（狙击手）
		ja = "狙撃", -- ダメージ耐性 (スナイパー)
		ru = "СУСН", -- Сопротивление урону (Снайперы)
		["zh-tw"] = "狙擊", -- 對狙擊手的傷害抗性
	},
	trait_gadget_damage_reduction_vs_bombers = {
		en = "BRST", -- Damage Resistance (Poxbursters).
		["zh-cn"] = "自爆", -- 伤害抗性（瘟疫爆者）。
		ja = "自爆", -- ダメージ耐性 (ポックスバースター)
		ru = "СУЧВ", -- Сопротивление урону (Чумные взрывуны)
		["zh-tw"] = "自爆", -- 對瘟疫爆者的傷害抗性
	},
	trait_gadget_damage_reduction_vs_hounds = {
		en = "HOND", -- Damage Resistance (Pox Hounds)
		["zh-cn"] = "猎犬", -- 伤害抗性（瘟疫猎犬）
		ja = "疫犬", -- ダメージ耐性 (ポックスハウンド)
		ru = "СУЧГ", -- Сопротивление урону (Чумные гончие)
		["zh-tw"] = "獵犬", -- 對瘟疫獵犬的傷害抗性
	},
	trait_gadget_damage_reduction_vs_grenadiers = {
		en = "BMBR", -- Damage Resistance (Bombers)
		["zh-cn"] = "雷兵", -- 伤害抗性（轰炸者）
		ja = "手榴", -- ダメージ耐性 (ボマー)
		ru = "СУВЗ", -- Сопротивление урону (Взрывуны)
		["zh-tw"] = "轟炸", -- 對轟炸者的傷害抗性
	},
	trait_weapon_trait_melee_common_wield_increased_resistant_damage = {
		en = "UYLD", -- Damage (Unyielding Enemies)
		["zh-cn"] = "不屈", -- 伤害（不屈敌人）
		ja = "不屈", -- ダメージ (不屈の敵)
		ru = "УНВР", -- Урон (Несгибаемые враги)
		["zh-tw"] = "不屈", -- 對不屈敵人的傷害
	},
	trait_weapon_trait_melee_common_wield_increased_disgustingly_resilient_damage = {
		en = "IFST", -- Damage (Infested Enemies)
		["zh-cn"] = "感染", -- 伤害（感染敌人）
		ja = "感染", -- ダメージ (感染した敵)
		ru = "УЗВР", -- Урон (Заражённые враги)
		["zh-tw"] = "感染", -- 對感染敵人的傷害
	},
	trait_weapon_trait_melee_common_wield_increased_unarmored_damage = {
		en = "UAMR", -- Damage (Unarmoured Enemies)
		["zh-cn"] = "无甲", -- 伤害（无甲敌人）
		ja = "未装", -- ダメージ (アーマー未装着の敵)
		ru = "УВББ", -- Урон (Враги без брони)
		["zh-tw"] = "無甲", -- 對無甲敵人的傷害
	},
	trait_weapon_trait_melee_common_wield_increased_berserker_damage = {
		en = "MNAC", -- Damage (Maniacs)
		["zh-cn"] = "狂人", -- 伤害（狂人）
		ja = "狂信", -- ダメージ (マニアック)
		ru = "УМАН", -- Урон (маньяки)
		["zh-tw"] = "狂人", -- 對狂人敵人的傷害
	},
	trait_weapon_trait_melee_common_wield_increased_super_armor_damage = {
		en = "CRPC", -- Damage (Carapace Armoured Enemies)
		["zh-cn"] = "硬壳", -- 伤害（硬壳装甲敌人）
		ja = "重装", -- ダメージ (カラペース・アーマー装着の敵)
		ru = "УВПБ", -- Урон (Враги с панцирной бронёй)
		["zh-tw"] = "硬甲", -- 對硬甲裝甲敵人的傷害
	},
	trait_weapon_trait_melee_common_wield_increased_armored_damage = {
		en = "FLAK", -- Damage (Flak Armoured Enemies)
		["zh-cn"] = "防弹", -- 伤害（防弹装甲敌人）
		ja = "軽装", -- ダメージ (フラック・アーマー装着の敵)
		ru = "УПОБ", -- Урон (Враги с противоосколочной бронёй)
		["zh-tw"] = "防彈", -- 對防彈裝甲敵人的傷害
	},
	trait_weapon_trait_ranged_common_wield_increased_resistant_damage = {
		en = "UYLD", -- Damage (Unyielding Enemies)
		["zh-cn"] = "不屈", -- 伤害（不屈敌人）
		ja = "不屈", -- ダメージ (不屈の敵)
		ru = "УНВР", -- Урон (Несгибаемые враги)
		["zh-tw"] = "不屈", -- (遠程) 對不屈敵人的傷害
	},
	trait_weapon_trait_ranged_common_wield_increased_disgustingly_resilient_damage = {
		en = "IFST", -- Damage (Infested Enemies)
		["zh-cn"] = "感染", -- 伤害（感染敌人）
		ja = "感染", -- ダメージ (感染した敵)
		ru = "УЗВР", -- Урон (Заражённые враги)
		["zh-tw"] = "感染", -- (遠程) 對感染敵人的傷害
	},
	trait_weapon_trait_ranged_common_wield_increased_unarmored_damage = {
		en = "UAMR", -- Damage (Unarmoured Enemies)
		["zh-cn"] = "无甲", -- 伤害（无甲敌人）
		ja = "未装", -- ダメージ (アーマー未装着の敵)
		ru = "УВББ", -- Урон (Враги без брони)
		["zh-tw"] = "無甲", -- (遠程) 對無甲敵人的傷害
	},
	trait_weapon_trait_ranged_common_wield_increased_berserker_damage = {
		en = "MNAC", -- Damage (Maniacs)
		["zh-cn"] = "狂人", -- 伤害（狂人）
		ja = "狂信", -- ダメージ (マニアック)
		ru = "УМАН", -- Урон (маньяки)
		["zh-tw"] = "狂人", -- (遠程) 對狂人敵人的傷害
	},
	trait_weapon_trait_ranged_common_wield_increased_super_armor_damage = {
		en = "CRPC", -- Damage (Carapace Armoured Enemies)
		["zh-cn"] = "硬壳", -- 伤害（硬壳装甲敌人）
		ja = "重装", -- ダメージ (カラペース・アーマー装着の敵)
		ru = "УВПБ", -- Урон (Враги с панцирной бронёй)
		["zh-tw"] = "硬甲", -- (遠程) 對硬甲裝甲敵人的傷害
	},
	trait_weapon_trait_ranged_common_wield_increased_armored_damage = {
		en = "FLAK", -- Damage (Flak Armoured Enemies)
		["zh-cn"] = "防弹", -- 伤害（防弹装甲敌人）
		ja = "軽装", -- ダメージ (フラック・アーマー装着の敵)
		ru = "УПОБ", -- Урон (Враги с противоосколочной бронёй)
		["zh-tw"] = "防彈", -- (遠程) 對防彈裝甲敵人的傷害
	},
	trait_weapon_trait_increase_stamina = {
		en = "STAM", -- Stamina
		["zh-cn"] = "体力", -- 体力
		ja = "活力", -- スタミナ
		ru = "ВНСЛ", -- Выносливость
		["zh-tw"] = "耐力", -- 耐力
	},
	trait_gadget_stamina_regeneration = {
		en = "STRG", -- Stamina Regeneration
		["zh-cn"] = "体回", -- 体力恢复
		ja = "活回", -- スタミナ回復
		ru = "ВВЫН", -- Восстановление выносливости
		["zh-tw"] = "體回", -- 體力恢復
	},
	trait_gadget_cooldown_reduction = {
		en = "ABRG", -- Combat Ability Regeneration
		["zh-cn"] = "技回", -- 作战技能恢复
		ja = "能回", -- 戦闘アビリティ回復
		ru = "ВОБС", -- Восстановление боевых способностей
		["zh-tw"] = "技回", -- 作戰技能恢復速度
	},
	trait_weapon_trait_increase_impact = {
		en = "IMPC", -- Impact (Melee)
		["zh-cn"] = "冲击", -- 冲击（近战）
		ja = "衝撃", -- 衝撃 (近接)
		ru = "МОЩЬ", -- Мощь (Ближний бой)
		["zh-tw"] = "衝擊", -- 近戰
	},
	trait_gadget_revive_speed_increase = {
		en = "RVIV", -- Revive Speed (Ally)
		["zh-cn"] = "友活", -- 复活速度（盟友）
		ja = "蘇生", -- 蘇生速度 (味方)
		ru = "СВСО", -- Скорость воскрешения (союзник)
		["zh-tw"] = "救援", -- 復活隊友速度
	},
	trait_gadget_mission_credits_increase = {
		en = "ODKT", -- Ordo Dockets (Mission Rewards)
		["zh-cn"] = "金币", -- 审判庭双子币（任务奖励）
		ja = "貨幣", -- オルドドケット (ミッション報酬)
		ru = "ЯОНЗ", -- Ярлыки Ордо (награды за задание)
		["zh-tw"] = "金幣", -- 任務結算時獲得的審判庭代幣
	},
	trait_gadget_mission_reward_gear_instead_of_weapon_increase = {
		en = "CURO", -- Chance of Curio as Mission Reward (instead of Weapon)
		["zh-cn"] = "珍品", -- 以珍品作为任务奖励（而非武器）的几率
		ja = "収集", -- 収集品がミッション報酬となる確率 (武器の代わり)
		ru = "ВПУС", -- Вероятность получить устройство в качестве награды (вместо оружия)
		["zh-tw"] = "珍品", -- 有機會獲得飾品替代武器作為任務獎勵
	},
	trait_gadget_stamina_increase = {
		en = "STAM", -- Max Stamina
		["zh-cn"] = "体力", -- 最大体力
		ja = "活力", -- 最大スタミナ
		ru = "ВНСЛ", -- Выносливость
		["zh-tw"] = "耐力", -- 最大體力
	},
	trait_gadget_innate_health_increase = {
		en = "HP", -- Max Health
		["zh-cn"] = "生命", -- 最大生命值
		ja = "体力", -- 最大ヘルス
		ru = "ЗДОР", -- Здоровье
		["zh-tw"] = "生命", -- 最大生命值
	},
	trait_gadget_health_increase = {
		en = "HP", -- Max Health
		["zh-cn"] = "生命", -- 最大生命值
		ja = "体力", -- 最大ヘルス
		ru = "ЗДОР", -- Здоровье
		["zh-tw"] = "生命", -- 最大生命值
	},
	trait_gadget_block_cost_reduction = {
		en = "BLK", -- Block Efficiency
		["zh-cn"] = "格挡", -- 格挡效益
		ja = "防御", -- ブロック効率
		ru = "ЭБЛК", -- Эффективность блока
		["zh-tw"] = "格擋", -- 格擋效益
	},
	trait_weapon_trait_reduced_block_cost = {
		en = "BLK", -- Block Efficiency
		["zh-cn"] = "格挡", -- 格挡效益
		ja = "防御", -- ブロック効率
		ru = "ЭБЛК", -- Эффективность блока
		["zh-tw"] = "格擋", -- 格擋效益
	},
	trait_weapon_trait_increase_finesse = {
		en = "FNS", -- Finesse
		["zh-cn"] = "娴熟", -- 武器娴熟
		ja = "策謀", -- 策謀
		ru = "ТОЧН", -- Точность
		["zh-tw"] = "熟練", -- 武器娴熟
	},
	trait_gadget_innate_max_wounds_increase = {
		en = "WND", -- Wound(s)
		["zh-cn"] = "伤口", -- 生命格
		ja = "傷口", -- 傷口
		ru = "РАНЫ", -- Дополнительные раны
		["zh-tw"] = "傷痕", -- 傷痕
	},
	trait_weapon_trait_reduce_sprint_cost = {
		en = "SPRT", -- Sprint Efficiency
		["zh-cn"] = "疾跑", -- 疾跑效益
		ja = "疾走", -- ダッシュ効率
		ru = "ЭБЕГ", -- Эффективность бега
		["zh-tw"] = "衝刺", -- 疾跑效益
	},
	trait_gadget_sprint_cost_reduction = {
		en = "SPRT", -- Sprint Efficiency
		["zh-cn"] = "疾跑", -- 疾跑效益
		ja = "疾走", -- ダッシュ効率
		ru = "ЭБЕГ", -- Эффективность бега
		["zh-tw"] = "衝刺", -- 疾跑效益
	},
	trait_gadget_mission_xp_increase = {
		en = "EXP", -- Experience
		["zh-cn"] = "经验", -- 经验
		ja = "経験", -- 経験値
		ru = "ОПЫТ", -- Опыт
		["zh-tw"] = "經驗", -- 經驗
	},
	trait_gadget_corruption_resistance = {
		en = "CRPT", -- Corruption Resistance
		["zh-cn"] = "腐抗", -- 腐化抗性
		ja = "腐敗", -- 腐敗耐性
		ru = "ССКВ", -- Сопротивление скверне
		["zh-tw"] = "腐抗", -- 腐化抗性
	},
	trait_gadget_permanent_damage_resistance = {
		en = "GRIM", -- Corruption Resistance (Grimoires)
		["zh-cn"] = "书抗", -- 腐化抗性（魔法书）
		ja = "魔術", -- 腐敗耐性 (魔術書)
		ru = "ССГР", -- Сопротивление скверне (Гримуары)
		["zh-tw"] = "書抗", -- 腐化抗性（魔法書）
	},
	trait_weapon_trait_ranged_increased_reload_speed = {
		en = "RLD", -- Reload Speed
		["zh-cn"] = "装弹", -- 装弹速度
		ja = "装弾", -- リロード速度
		ru = "СПЕР", -- Скорость перезарядки
		["zh-tw"] = "裝彈", -- 裝填速度
	},
	trait_weapon_trait_increase_damage = {
		en = "DMG", -- Melee Damage
		["zh-cn"] = "伤害", -- 近战伤害
		ja = "威力", -- 近接ダメージ
		ru = "УРББ", -- Урон в ближнем бою
		["zh-tw"] = "傷害", -- 近戰傷害
	},
	trait_weapon_trait_increase_damage_specials = {
		en = "SPEC", -- Increased Melee Damage (Specialists)
		["zh-cn"] = "专家", -- 近战伤害加成（专家）
		ja = "特殊", -- 近接ダメージ (スペシャリスト)
		ru = "УББС", -- Урон от атак ближнего боя (специалисты)
		["zh-tw"] = "專家", -- 近戰對專家敵人的傷害
	},
	trait_weapon_trait_increase_damage_hordes = {
		en = "HORD", -- Melee Damage (Groaners, Poxwalkers)
		["zh-cn"] = "群怪", -- 近战伤害（呻吟者、瘟疫行者）
		ja = "大群", -- 近接ダメージ (グローナー、ポクスウォーカー)
		ru = "УББО", -- Урон от атак ближнего боя (Ворчуны и ходоки)
		["zh-tw"] = "群怪", -- 近戰對群怪（呻吟者、瘟疫行者）的傷害
	},
	trait_weapon_trait_increase_damage_elites = {
		en = "ELTE", -- Melee Damage (Elites)
		["zh-cn"] = "精英", -- 近战伤害（精英）
		ja = "上位", -- 近接ダメージ (上位者)
		ru = "УББЭ", -- Урон от атак ближнего боя (элитные)
		["zh-tw"] = "精英", -- 近戰對精英的傷害
	},
	trait_weapon_trait_increase_weakspot_damage = {
		en = "WEAK", -- Melee Weak Spot Damage
		["zh-cn"] = "弱点", -- 近战弱点伤害
		ja = "弱点", -- 近接弱点ダメージ
		ru = "УСББ", -- Урон по слабым местам от атак ближнего боя
		["zh-tw"] = "弱點", -- 近戰弱點傷害
	},
	trait_weapon_trait_increase_attack_speed = {
		en = "ATSP", -- Melee Attack Speed
		["zh-cn"] = "攻速", -- 近战攻击速度
		ja = "攻速", -- 近接攻撃速度
		ru = "САББ", -- Скорость атаки в ближнем бою
		["zh-tw"] = "攻速", -- 近戰攻擊速度
	},
	trait_weapon_trait_increase_crit_damage = {
		en = "CRDM", -- Melee Critical Hit Damage
		["zh-cn"] = "暴伤", -- 近战暴击伤害
		ja = "致威", -- 近接クリティカルダメージ
		ru = "КУББ", -- Критический урон атак ближнего боя
		["zh-tw"] = "爆傷", -- 近戰爆擊傷害
	},
	trait_weapon_trait_increase_crit_chance = {
		en = "CRCH", -- Melee Critical Hit Chance
		["zh-cn"] = "暴率", -- 近战暴击几率
		ja = "致率", -- 近接クリティカルヒット率
		ru = "ВКББ", -- Вероятность критического удара от атак ближнего боя
		["zh-tw"] = "爆率", -- 近戰爆擊機率
	},
	trait_weapon_trait_ranged_increase_damage = {
		en = "DMG", -- Ranged Damage
		["zh-cn"] = "伤害", -- 远程伤害
		ja = "威力", -- 遠隔ダメージ
		ru = "УРДБ", -- Урон в дальнем бою
		["zh-tw"] = "傷害", -- 遠程傷害
	},
	trait_weapon_trait_ranged_increase_damage_specials = {
		en = "SPEC", -- Ranged Damage (Specialists)
		["zh-cn"] = "专家", -- 远程伤害（专家）
		ja = "特殊", -- 遠隔ダメージ (スペシャリスト)
		ru = "УДБС", -- Урон атак дальнего боя (специалисты)
		["zh-tw"] = "專家", -- 遠程對專家敵人的傷害
	},
	trait_weapon_trait_ranged_increase_damage_hordes = {
		en = "HORD", -- Ranged Damage (Groaners, Poxwalkers)
		["zh-cn"] = "群怪", -- 远程伤害（呻吟者、瘟疫行者）
		ja = "大群", -- 遠隔ダメージ (グローナー、ポクスウォーカー)
		ru = "УДБО", -- Урон от атак дальнего боя (Ворчуны и ходоки)
		["zh-tw"] = "群怪", -- 遠程對群怪的傷害
	},
	trait_weapon_trait_ranged_increase_damage_elites = {
		en = "ELTE", -- Ranged Damage (Elites)
		["zh-cn"] = "精英", -- 远程伤害（精英）
		ja = "上位", -- 遠隔ダメージ (上位者)
		ru = "УДБЭ", -- Урон от атак дальнего боя (элитные)
		["zh-tw"] = "精英", -- 遠程對精英的傷害
	},
	trait_weapon_trait_ranged_increase_weakspot_damage = {
		en = "WEAK", -- Ranged Weak Spot Damage
		["zh-cn"] = "弱点", -- 远程弱点伤害
		ja = "弱点", -- 遠隔弱点ダメージ
		ru = "УСДБ", -- Урон по слабым местам от атак дальнего боя
		["zh-tw"] = "弱點", -- 遠程弱點傷害
	},
	trait_weapon_trait_ranged_increase_crit_damage = {
		en = "CRDM", -- Ranged Critical Hit Damage
		["zh-cn"] = "暴伤", -- 远程暴击伤害
		ja = "致威", -- 遠隔クリティカルダメージ
		ru = "КУДБ", -- Критический урон атак дальнего боя
		["zh-tw"] = "爆傷", -- 遠程爆擊傷害
	},
	trait_weapon_trait_ranged_increase_crit_chance = {
		en = "CRCH", -- Increase Ranged Critical Strike Chance
		["zh-cn"] = "暴率", -- 远程暴击几率增加
		ja = "致率", -- 遠隔攻撃のクリティカル率が増加する
		ru = "ВКДБ", -- Вероятность критического удара от атак дальнего боя
		["zh-tw"] = "爆率", -- 遠程爆擊率增加
	},
	trait_gadget_innate_toughness_increase = {
		en = "TN", -- Toughness
		["zh-cn"] = "韧性", -- 韧性
		ja = "靭性", -- 最大タフネス
		ru = "СТЙК", -- Стойкость
		["zh-tw"] = "韌性", -- 最大韌性
	},
	trait_gadget_toughness_increase = {
		en = "TN", -- Toughness
		["zh-cn"] = "韧性", -- 韧性
		ja = "靭性", -- タフネス
		ru = "СТЙК", -- Стойкость
		["zh-tw"] = "韌性", -- 韌性
	},
	trait_gadget_toughness_regen_delay = {
		en = "TNRG", -- Toughness Regeneration Speed
		["zh-cn"] = "韧回", -- 韧性回复速度
		ja = "靭回", -- タフネス回復遅延
		ru = "СВСТ", -- Скорость восстановления стойкости
		["zh-tw"] = "韌回", -- 韌性恢復速度
	},
	trait_weapon_trait_ranged_increase_stamina = {
		en = "STAM", -- Stamina (Weapon is Active)
		["zh-cn"] = "体力", -- （使用武器时）体力
		ja = "活力", -- スタミナ (武器使用時)
		ru = "ВСАО", -- Выносливость (с активным оружием)
		["zh-tw"] = "體力", -- 使用武器時增加體力
	},
}
