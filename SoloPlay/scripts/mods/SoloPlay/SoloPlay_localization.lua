return {
	mod_name = {
		en = "Solo Play",
		["zh-cn"] = "单人游戏",
		ru = "Игра в соло",
	},
	mod_description = {
		en = "Play offline solo mission by /solo command. You can't get any rewards or progression in offline game.",
		["zh-cn"] = "输入 /solo 命令玩离线单人任务。你无法从离线游戏中获得任何奖励或进度。",
		ru = "Solo Play - Играйте в офлайн-соло-миссию командой /solo. В офлайн-игре вы не получаете никаких наград или прогресса.",
	},
	default_text = {
		en = "Default",
		["zh-cn"] = "默认",
		ru = "По умолчанию",
	},
	default_text_none = {
		en = "None",
		["zh-cn"] = "无",
		ru = "Нет",
	},
	format_auric = {
		en = Localize("loc_mission_board_type_auric") .. " %s",
		["zh-cn"] = Localize("loc_mission_board_type_auric") .. "%s",
	},

	solo_keybind = {
		en = "Open Solo Play view",
		["zh-cn"] = "打开单人游戏界面",
		ru = "Открыть меню Игры в соло",
	},
	solo_keybind_description = {
		en = "Solo Play view can also be opened by \"/solo\" command.",
		["zh-cn"] = "单人游戏界面也可以通过“/solo”命令打开。",
		ru = "Режим соло-игры также можно открыть с помощью команды \"/solo\".",
	},
	group_modifiers = {
		en = "Modifiers",
		["zh-cn"] = "修改项",
		ru = "Модификаторы",
	},
	friendly_fire_enabled = {
		en = "Friendly fire",
		["zh-cn"] = "友军伤害",
		ru = "Огонь по своим",
	},
	random_side_mission_seed = {
		en = "Random side mission location",
		["zh-cn"] = "随机次要目标位置",
		ru = "Случайные места побочной миссии",
	},
	random_side_mission_seed_description = {
		en = "Currently, side mission pickup spawn locations are locked and only changed on a weekly cadence.\n" ..
			"This option enables the old random location generator in Solo Play.",
		["zh-cn"] = "目前，次要目标的生成位置是固定的，仅会每周刷新一次。\n" ..
			"此选项会在单人游戏中启用旧版的随机位置生成器。",
		ru = "В настоящее время места появления побочных миссий заблокированы и меняются еженедельно.\n" ..
			"Эта опция включает старый генератор случайных мест в соло-игре.",
	},
	solo_command_desc = {
		en = "Play offline solo mission",
		["zh-cn"] = "玩离线单人任务",
		ru = "Пройдите миссию в одиночку в офлайн режиме",
	},

	solo_view_title = {
		en = "Solo Play",
		["zh-cn"] = "单人游戏",
		ru = "Игра в соло",
	},
	button_start_normal = {
		en = "Play Normal Game",
		["zh-cn"] = "开始常规游戏",
		ru = "Запуск обычной игры",
	},
	button_start_havoc = {
		en = "Play Havoc Game",
		["zh-cn"] = "开始浩劫游戏",
		ru = "Запуск Верной смерти",
	},
	button_randomize = {
		en = "Regenerate",
		["zh-cn"] = "重新生成",
		ru = "Перегенерировать",
	},
	button_modifier_customizable = {
		en = "Customizable",
		["zh-cn"] = "手动调整",
		ru = "Настроить",
	},
	title_normal_mode = {
		en = "Normal Mode",
		["zh-cn"] = "常规模式",
		ru = "Обычный режим",
	},
	title_havoc_mode = {
		en = "Havoc Mode",
		["zh-cn"] = "浩劫模式",
		ru = "Режим «Верной смерти»",
	},
	label_mission = {
		en = "Mission",
		["zh-cn"] = "任务",
		ru = "Миссия",
	},
	label_side_mission = {
		en = "Side Mission",
		["zh-cn"] = "次要目标",
		ru = "Дополнительная миссия",
	},
	label_circumstance = {
		en = "Special Condition",
		["zh-cn"] = "特殊状况",
		ru = "Особое условие",
	},
	label_circumstance1 = {
		en = "Havoc Condition 1",
		["zh-cn"] = "浩劫状况 1",
		ru = "Условие Верной смерти 1",
	},
	label_circumstance2 = {
		en = "Havoc Condition 2",
		["zh-cn"] = "浩劫状况 2",
		ru = "Условие Верной смерти 2",
	},
	label_mission_giver = {
		en = "Mission Giver",
		["zh-cn"] = "任务发布者",
		ru = "Миссию дал:",
	},
	label_theme_modifier = {
		en = "Environment Condition",
		["zh-cn"] = "环境状况",
		ru = "Условие окружения",
	},
	label_difficulty_modifier = {
		en = "Difficulty Condition",
		["zh-cn"] = "难度状况",
		ru = "Условие сложности",
	},
	label_mutator = {
		en = "Mutators",
		["zh-cn"] = "变异因子",
		ru = "Мутаторы",
	},
	label_faction = {
		en = "Enemy Faction",
		["zh-cn"] = "敌人阵营",
		ru = "Фракция врагов",
	},

	tip_solo_offline = {
		en = "Offline game is mainly for testing, the experience may differ from online gameplay.\n"
			.. "You can't get any rewards or progression in offline game.",
		["zh-cn"] = "离线游戏主要用于测试，其体验可能与在线游戏不同。\n"
			.. "你无法从离线游戏中获得任何奖励或进度。",
		ru = "Офлайн-игра предназначена в основном для тестирования, впечатления от неё могут отличаться от онлайн-игры.\n"
			.. "В офлайн-игре вы не сможете получить никаких наград или прогресса.",
	},
	tip_invalid_combination = {
		en = "Note: some options may not be supported, have no effect, or cause crashes.",
		["zh-cn"] = "注意：某些选项可能不受支持、不生效或导致崩溃。",
		ru = "Примечание: некоторые параметры могут не поддерживаться, не иметь эффекта или вызывать вылеты!",
	},
	msg_not_available = {
		en = "Solo Play is currently unavailable",
		["zh-cn"] = "单人游戏目前不可用",
		ru = "В настоящее время режим соло-игры недоступен",
	},

	havoc_faction_mixed = {
		en = "Mixed",
		["zh-cn"] = "混合",
		ru = "Смешанный",
	},
	havoc_faction_renegade = {
		en = "Scab",
		["zh-cn"] = "血痂",
		ru = "Скабы",
	},
	havoc_faction_cultist = {
		en = "Dreg",
		["zh-cn"] = "渣滓",
		ru = "Дреги",
	},

	havoc_modifier_buff_elites = {
		en = "Elite Health +%d%%",
		["zh-cn"] = "精英生命值 +%d%%",
		ru = "Здоровье элиты: +%d%%",
	},
	havoc_modifier_more_alive_specials = {
		en = "Max Specialist Amount +%d",
		["zh-cn"] = "专家数量上限 +%d",
		ru = "Максимальное количество специалистов: +%d",
	},
	havoc_modifier_buff_specials = {
		en = "Specialist Health +%d%%",
		["zh-cn"] = "专家生命值 +%d%%",
		ru = "Здоровье специалистов: +%d%%",
	},
	havoc_modifier_buff_monsters = {
		en = "Monstrosity Amount +%d\nMonstrosity Health +%d%%",
		["zh-cn"] = "怪物数量 +%d\n怪物生命值 +%d%%",
		ru = "Количество монстров: +%d\nЗдоровье монстров: +%d%%",
	},
	havoc_modifier_buff_horde = {
		en = "Horde Hit Mass +%d%%\nHorde Health +%d%%",
		["zh-cn"] = "群怪打击质量 +%d%%\n群怪生命值 +%d%%",
		ru = "Ударная масса орды: +%d%%\nЗдоровье орды: +%d%%",
	},
	havoc_modifier_more_elites = {
		en = "Elite Amount +%d%%",
		["zh-cn"] = "精英数量 +%d%%",
		ru = "Количество элиты: +%d%%",
	},
	havoc_modifier_more_ogryns = {
		en = "Ogryn Amount +%d%%",
		["zh-cn"] = "欧格林数量 +%d%%",
		ru = "Количество огринов: +%d%%",
	},
	havoc_modifier_melee_minion_attack_speed = {
		en = "Enemy Melee Attack Speed +%d%%",
		["zh-cn"] = "敌人近战攻速 +%d%%",
		ru = "Скорость вражеских атак ближнего боя: +%d%%",
	},
	havoc_modifier_ranged_minion_attack_speed = {
		en = "Enemy Ranged Attack Speed +%d%%\nEnemy Shots Per Barrage +%d%%",
		["zh-cn"] = "敌人远程射速 +%d%%\n敌人每轮射击数 +%d%%",
		ru = "Скорострельность врагов: +%d%%\nКоличество выстрелов за залп: +%d%%",
	},
	havoc_modifier_melee_minion_permanent_damage = {
		en = "Enemy Melee Corruption Damage %d%%",
		["zh-cn"] = "敌人近战腐化伤害 %d%%",
		ru = "Урон порчей от вражеских атак ближнего боя: %d%%",
	},
	havoc_modifier_ammo_pickup_modifier = {
		en = "Player Ammo Gained -%d%%",
		["zh-cn"] = "玩家弹药获取量 -%d%%",
		ru = "Получаемые игроком патроны: -%d%%",
	},
	havoc_modifier_horde_spawn_rate_increase = {
		en = "Horde Spawn Rate +%d%%",
		["zh-cn"] = "群怪生成速率 +%d%%",
		ru = "Частота появления орд: +%d%%",
	},
	havoc_modifier_terror_event_point_increase = {
		en = "Event Enemies Spawned +%d%%",
		["zh-cn"] = "任务事件敌人生成 +%d%%",
		ru = "Появление врагов с событий: +%d%%",
	},
	havoc_modifier_melee_minion_power_level_buff = {
		en = "Enemy Melee Damage +%d%%",
		["zh-cn"] = "敌人近战伤害 +%d%%",
		ru = "Урон от вражеских атак ближнего боя: +%d%%",
	},
	havoc_modifier_reduce_toughness_regen = {
		en = "Player Toughness Regen Rate -%d%%",
		["zh-cn"] = "玩家韧性恢复速率 -%d%%",
		ru = "Скорость восстановления стойкости игрока: -%d%%",
	},
	havoc_modifier_reduce_toughness = {
		en = "Player Toughness -%d",
		["zh-cn"] = "玩家韧性 -%d",
		ru = "Стойкость игрока: -%d",
	},
	havoc_modifier_reduce_health_and_wounds = {
		en = "Player Health -%d%%",
		["zh-cn"] = "玩家生命值 -%d%%",
		ru = "Здоровье игрока: -%d%%",
	},
	havoc_modifier_havoc_vent_speed_reduction = {
		en = "Player Vent Duration and Interval +%d%%",
		["zh-cn"] = "玩家散热时长与间隔 +%d%%",
		ru = "Интервал и длительность сброса перегрева игроком: +%d%%",
	},
	havoc_modifier_positive_grenade_buff = {
		en = "Player Grenade Amount +%d\nBrain Burst Peril -%d%%",
		["zh-cn"] = "玩家手雷 +%d\n大脑爆裂危机值 -%d%%",
		ru = "Количество гранат у игрока: +%d\nОпасность от Разрыва мозга: -%d%%",
	},
	havoc_modifier_positive_stamina_modifier = {
		en = "Player Stamina +%d",
		["zh-cn"] = "玩家体力 +%d",
		ru = "Выносливость игрока: +%d",
	},
	havoc_modifier_positive_weakspot_damage_bonus = {
		en = "Player Weakspot Damage +%d%%",
		["zh-cn"] = "玩家弱点伤害 +%d%%",
		ru = "Урон игрока по уязвимым местам: +%d%%",
	},
	havoc_modifier_positive_knocked_down_health_modifier = {
		en = "Player Knocked Down Health +%d%%",
		["zh-cn"] = "玩家倒地生命值 +%d%%",
		ru = "Здоровье игрока, выведенного из строя: +%d%%",
	},
	havoc_modifier_positive_reload_speed = {
		en = "Player Reload Speed +%d%%",
		["zh-cn"] = "玩家装弹速度 +%d%%",
		ru = "Скорость перезарядки игрока: +%d%%",
	},
	havoc_modifier_positive_crit_chance = {
		en = "Player Crit Chance +%d%%",
		["zh-cn"] = "玩家暴击率 +%d%%",
		ru = "Шанс критического удара игрока: +%d%%",
	},
	havoc_modifier_positive_movement_speed = {
		en = "Player Movement Speed +%d%%",
		["zh-cn"] = "玩家移动速度 +%d%%",
		ru = "Скорость движения игрока: +%d%%",
	},
	havoc_modifier_positive_attack_speed = {
		en = "Player Melee Attack Speed +%d%%\nPlayer Ranged Attack Speed +%d%%",
		["zh-cn"] = "玩家近战攻速 +%d%%\n玩家远程射速 +%d%%",
		ru = "Скорость атак ближнего боя: +%d%%\nСкорострельность игрока: +%d%%",
	},
}
