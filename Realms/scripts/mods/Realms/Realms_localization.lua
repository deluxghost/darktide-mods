local mod = get_mod("Realms")

local localization = {
	mod_name = {
		en = "Realms Server",
		["zh-cn"] = "领域服务器",
	},
	mod_description = {
		en = "Adds LAN multiplayer support to Darktide. Every local single-player game also starts a LAN listen server.",
		["zh-cn"] = "为暗潮提供局域网联机功能。所有本地单人游戏都会同时启动局域网监听服务器。",
	},
	join_server = {
		en = "Join server",
		["zh-cn"] = "加入服务器",
	},
	join_server_description = {
		en = "Open the Realms server connection view.",
		["zh-cn"] = "打开领域服务器连接界面。",
	},
	join_server_button = {
		en = "Open",
		["zh-cn"] = "打开",
	},
	mission_preparation = {
		en = "Mission preparation",
		["zh-cn"] = "任务准备",
	},
	mission_preparation_description = {
		en = "Require all players to ready up before the host loads a mission. The Mourningstar and the Psykhanium always load immediately.",
		["zh-cn"] = "主机加载任务前要求所有玩家完成准备。哀星号和灵能室始终直接加载。",
	},
	join_server_address = {
		en = "Server address",
		["zh-cn"] = "服务器地址",
	},
	join_server_address_placeholder = {
		en = "address:port or [IPv6]:port",
		["zh-cn"] = "地址:端口 或 [IPv6]:端口",
	},
	join_server_password = {
		en = "Password",
		["zh-cn"] = "密码",
	},
	join_server_connect = {
		en = "Connect",
		["zh-cn"] = "连接",
	},
	error_join_target_format = {
		en = "Enter the server as address:port or [IPv6]:port.",
		["zh-cn"] = "服务器地址格式应为 地址:端口 或 [IPv6]:端口。",
	},
	private_mode = {
		en = "Private mode",
		["zh-cn"] = "私人模式",
	},
	private_mode_description = {
		en = "Reject new connections while enabled. Players already connected are not affected.",
		["zh-cn"] = "启用后拒绝新的连接。已经连接的玩家不受影响。",
	},
	max_players = {
		en = "Maximum players",
		["zh-cn"] = "最大玩家数",
	},
	max_players_description = {
		en = "Reject new connections after reaching this limit. Lowering it does not disconnect existing players.",
		["zh-cn"] = "达到此人数上限后拒绝新的连接。降低上限不会断开现有玩家。",
	},
	bot_fill_target = {
		en = "Bot fill target",
		["zh-cn"] = "机器人补位目标人数",
	},
	bot_fill_target_description = {
		en = "Fill empty places with bots until the total number of players and bots reaches this value. Bots are not added while the number of players is at or above the target.",
		["zh-cn"] = "使用机器人补位，直到玩家和机器人的总数达到此值。玩家数达到或超过目标时不会添加机器人。",
	},
	server_password = {
		en = "Server password",
		["zh-cn"] = "服务器密码",
	},
	server_password_description = {
		en = "Require this password for new connections. Leave empty to disable password protection. Changing it does not affect connected players.",
		["zh-cn"] = "新的连接必须提供此密码。留空表示不启用密码保护。修改密码不会影响已经连接的玩家。",
	},
	command_status_description = {
		en = "Show the current Realms session status.",
		["zh-cn"] = "显示当前领域会话状态。",
	},
	settings_apply_failed = {
		en = "Failed to apply server settings.",
		["zh-cn"] = "应用服务器设置失败。",
	},
	host_listening = {
		en = "Realms server is listening on UDP port %d.",
		["zh-cn"] = "领域服务器正在监听 UDP 端口 %d。",
	},
	client_boot_failed = {
		en = "Failed to join the server.",
		["zh-cn"] = "加入服务器失败。",
	},
	error_server_address_required = {
		en = "Enter a server address.",
		["zh-cn"] = "请输入服务器地址。",
	},
	error_server_address_unresolved = {
		en = "The server address could not be resolved.",
		["zh-cn"] = "无法解析服务器地址。",
	},
	error_server_port_invalid = {
		en = "The server port must be an integer between 1 and 65535.",
		["zh-cn"] = "服务器端口必须是 1 到 65535 之间的整数。",
	},
	error_password_type = {
		en = "The server password must be text.",
		["zh-cn"] = "服务器密码必须是文本。",
	},
	error_password_too_long = {
		en = "The server password must not exceed 1024 bytes.",
		["zh-cn"] = "服务器密码不得超过 1024 字节。",
	},
	error_password_whitespace = {
		en = "The server password must not contain whitespace.",
		["zh-cn"] = "服务器密码不能包含空白字符。",
	},
	error_multiplayer_unavailable = {
		en = "Multiplayer services are unavailable.",
		["zh-cn"] = "多人游戏服务不可用。",
	},
	error_join_already_pending = {
		en = "A server join is already in progress.",
		["zh-cn"] = "已经在加入服务器。",
	},
	error_connection_client_unavailable = {
		en = "The network client is unavailable.",
		["zh-cn"] = "网络客户端不可用。",
	},
	official_session_transition_failed = {
		en = "Failed to join the official game session. The current Realms session is still active.",
		["zh-cn"] = "加入官方游戏会话失败，当前领域会话仍然有效。",
	},
	preparation_skills_header = {
		en = "Skills",
		["zh-cn"] = "技能",
	},
	preparation_weapons_header = {
		en = "Weapon",
		["zh-cn"] = "武器",
	},
	preparation_status_header = {
		en = "Ready",
		["zh-cn"] = "准备",
	},
	preparation_ready = {
		en = "Ready",
		["zh-cn"] = "准备",
	},
	preparation_cancel_ready = {
		en = "Cancel Ready",
		["zh-cn"] = "取消准备",
	},
	preparation_control_failed = {
		en = "The preparation session received invalid network data.",
		["zh-cn"] = "准备会话收到了无效的网络数据。",
	},
}

local native_localization = {
	loc_realms_connection_error_title = {
		en = "Realms connection error",
		["zh-cn"] = "领域连接错误",
	},
	loc_realms_connection_failed = {
		en = "Failed to connect to the Realms server.",
		["zh-cn"] = "无法连接到领域服务器。",
	},
	loc_realms_connection_lost = {
		en = "The connection to the Realms server was lost.",
		["zh-cn"] = "与领域服务器的连接已中断。",
	},
	loc_realms_server_closed = {
		en = "The Realms server was closed by the host.",
		["zh-cn"] = "主机已关闭领域服务器。",
	},
	loc_realms_server_private = {
		en = "The Realms server is private and is not accepting new connections.",
		["zh-cn"] = "领域服务器已设为私人，当前不接受新的连接。",
	},
	loc_realms_server_full = {
		en = "The Realms server is full.",
		["zh-cn"] = "领域服务器人数已满。",
	},
	loc_realms_password_incorrect = {
		en = "The server password is incorrect.",
		["zh-cn"] = "服务器密码错误。",
	},
	loc_realms_protocol_mismatch = {
		en = "The Realms protocol versions do not match.",
		["zh-cn"] = "双方的领域协议版本不一致。",
	},
	loc_realms_game_version_mismatch = {
		en = "The game versions do not match.",
		["zh-cn"] = "双方的游戏版本不一致。",
	},
	loc_realms_server_context_invalid = {
		en = "The server returned invalid Realms session information.",
		["zh-cn"] = "服务器返回的领域会话信息无效。",
	},
	loc_realms_client_data_rejected = {
		en = "The server rejected the client session data.",
		["zh-cn"] = "服务器拒绝了客户端会话数据。",
	},
	loc_realms_server_error = {
		en = "The Realms server could not complete the connection.",
		["zh-cn"] = "领域服务器无法完成本次连接。",
	},
	loc_realms_host_boot_failed = {
		en = "Failed to start the Realms listen server.",
		["zh-cn"] = "无法启动领域监听服务器。",
	},
}

mod:add_global_localize_strings(native_localization)

return localization
