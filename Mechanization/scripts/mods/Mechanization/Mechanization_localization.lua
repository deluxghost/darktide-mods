return {
	mod_name = {
		en = "Mechanization",
		["zh-cn"] = "机械化",
	},
	mod_description = {
		en = "Drive vehicles in local missions with the /mech command.",
		["zh-cn"] = "在本地任务中用 /mech 命令驾驶载具。",
	},
	mission_required = {
		en = "Vehicles can only be used in local missions.",
		["zh-cn"] = "载具只能在本地任务中使用。",
	},
	command_description = {
		en = "Mechanization vehicle menu",
		["zh-cn"] = "机械化载具菜单",
	},
	vehicle_list = {
		en = "Vehicles:",
		["zh-cn"] = "载具列表：",
	},
	vehicle_create_hint = {
		en = "Enter {#color(239,193,82)}/mech <number>{#reset()} to create a vehicle",
		["zh-cn"] = "输入 {#color(239,193,82)}/mech 数字{#reset()} 创建",
	},
	already_boarded = {
		en = "You are already in a vehicle.",
		["zh-cn"] = "当前已经在载具中。",
	},
	enabled = {
		en = "Enabled",
		["zh-cn"] = "启用",
	},
	enabled_description = {
		en = "Enable vehicle functionality.\n\nOnly the host setting takes effect.",
		["zh-cn"] = "是否启用载具功能。\n\n仅主机设置生效。",
	},
	spawn_cooldown = {
		en = "Vehicle spawn cooldown (seconds)",
		["zh-cn"] = "召唤冷却秒数",
	},
	spawn_cooldown_description = {
		en = "Cooldown before spawning another vehicle after leaving your own.\n\nOnly the host setting takes effect.",
		["zh-cn"] = "离开自己召唤的载具后再次召唤的冷却时间。\n\n仅主机设置生效。",
	},
	spawn_wait = {
		en = "You can spawn another vehicle in %d seconds.",
		["zh-cn"] = "还需等待 %d 秒才能再次召唤载具。",
	},
	custom_vehicle_properties = {
		en = "Custom vehicle properties",
		["zh-cn"] = "自定义载具属性",
	},
	custom_vehicle_properties_description = {
		en = "Customize vehicle health and weapon base damage.\n\nOnly the host settings take effect.\n\nOnly applies to newly spawned vehicles.",
		["zh-cn"] = "自定义载具血量和武器基础伤害。\n\n仅主机设置生效。\n\n仅对新生成的载具生效。",
	},
	vehicle_health = {
		en = "Health",
		["zh-cn"] = "血量",
	},
	vehicle_health_description = {
		en = "Maximum vehicle health.",
		["zh-cn"] = "载具最大血量。",
	},
	weapon_damage_description = {
		en = "Base damage before armor modifiers.",
		["zh-cn"] = "应用护甲倍率前的基础伤害。",
	},
	main_damage = {
		en = "Main cannon base damage",
		["zh-cn"] = "主炮基础伤害",
	},
	front_damage = {
		en = "Hull cannon base damage",
		["zh-cn"] = "前炮基础伤害",
	},
	laser_damage = {
		en = "Lascannon base damage",
		["zh-cn"] = "激光炮基础伤害",
	},
	rocket_damage = {
		en = "Rocket base damage",
		["zh-cn"] = "火箭弹基础伤害",
	},
	creation_disabled = {
		en = "Vehicles are not enabled on this server.",
		["zh-cn"] = "当前服务器未启用载具。",
	},
	vehicle_lionheart = {
		en = "Lionheart · Leman Russ Demolisher",
		["zh-cn"] = "狮心号 · 黎曼鲁斯破坏者",
	},
	vehicle_valkyrie = {
		en = "Valkyrie · Airborne Assault Carrier",
		["zh-cn"] = "女武神 · 空中突击运输机",
	},
	vehicle_wolfquad = {
		en = "Atalan Wolfquad",
		["zh-cn"] = "阿塔兰狼式四轮车",
	},
	vehicle_goliath = {
		en = "Goliath Truck",
		["zh-cn"] = "歌利亚卡车",
	},
	hud_laser = {
		en = "LASER",
		["zh-cn"] = "激光炮",
	},
	hud_rocket = {
		en = "ROCKETS",
		["zh-cn"] = "火箭巢",
	},
	invalid_vehicle = {
		en = "Invalid vehicle number. Use /mech to list available vehicles.",
		["zh-cn"] = "载具编号无效。使用 /mech 查看可用型号。",
	},
	no_ground = {
		en = "No driveable ground at the player's position.",
		["zh-cn"] = "当前位置没有可供载具行驶的地面。",
	},
	ogryn_cannot_drive = {
		en = "Ogryns cannot drive vehicles.",
		["zh-cn"] = "欧格林无法驾驶载具。",
	},
	not_walking = {
		en = "You must be walking to create a vehicle.",
		["zh-cn"] = "只有步行状态才能创建载具。",
	},
	no_exit = {
		en = "No reachable dismount position nearby.",
		["zh-cn"] = "附近没有可达的下车位置。",
	},
	hud_board = {
		en = "Hold %s to board vehicle",
		["zh-cn"] = "长按 %s 进入载具",
	},
	no_space = {
		en = "Not enough space to create a vehicle.",
		["zh-cn"] = "空间不足，无法创建载具。",
	},
	hud_no_ogryn_space = {
		en = "No room for an Ogryn",
		["zh-cn"] = "没有欧格林乘坐的空间",
	},
	hud_full = {
		en = "Vehicle is full",
		["zh-cn"] = "载具已满",
	},
	hud_main = {
		en = "MAIN",
		["zh-cn"] = "主炮",
	},
	hud_front = {
		en = "FRONT",
		["zh-cn"] = "前炮",
	},
	hud_ready = {
		en = "READY",
		["zh-cn"] = "就绪",
	},
	hud_exit = {
		en = "Hold %s to leave vehicle",
		["zh-cn"] = "长按 %s 离开载具",
	},
	hud_switch_exit = {
		en = "Press %s to change seat | Hold to leave vehicle",
		["zh-cn"] = "按 %s 换座 | 长按离开载具",
	},
	hud_health = {
		en = "HULL %.0f / %.0f",
		["zh-cn"] = "车体 %.0f / %.0f",
	},
	hud_reload = {
		en = "RELOAD %.1fs",
		["zh-cn"] = "装填 %.1f 秒",
	},
	hud_cooldown = {
		en = "READY IN %.1fs",
		["zh-cn"] = "待发 %.1f 秒",
	},
}
