return {
	mod_name = {
		en = "Reconnect",
		["zh-cn"] = "重新连接",
		["zh-tw"] = "重新連線",
		ru = "Переподключение",
	},
	mod_description = {
		en = "Use /retry command to return to main menu so you can reconnect quickly.",
		["zh-cn"] = "使用 /retry 命令返回主菜单以便快速重新连接。",
		["zh-tw"] = "使用 /retry 命令返回主選單以便快速重新連線。",
		ru = "Reconnect - Используйте команду /retry для возвращения в главное меню, чтобы вы могли быстро переподключиться к предыдущей сессии.",
	},
	retry_description = {
		en = "Disconnect and return to main menu (reconnectable)",
		["zh-cn"] = "断开连接并返回主菜单（可重新连接）",
		["zh-tw"] = "斷開連線並返回主選單（可重新連線）",
		ru = "Отключение и возврат в главное меню (с возможностью повторного подключения)",
	},
	err_not_in_game = {
		en = "Error: you are not in a game",
		["zh-cn"] = "错误：你不在一局游戏中",
		["zh-tw"] = "錯誤：你不在一局遊戲中",
		ru = "Ошибка: вы не в игре",
	},
	err_only_one_human = {
		en = "Error: you are the only human player",
		["zh-cn"] = "错误：你是唯一的真人玩家",
		["zh-tw"] = "錯誤：你是唯一的真人玩家",
		ru = "Ошибка: вы единственный игрок-человек",
	},
	retry_keybind = {
		en = "Keybind for /retry command",
		["zh-cn"] = "命令 /retry 的快捷键",
		["zh-tw"] = "命令 /retry 的快捷鍵",
		ru = "Клавиша для команды /retry",
	},
	handle_rejoin_popup = {
		en = "Rejoin popup auto action",
		["zh-cn"] = "重连弹框自动操作",
		["zh-tw"] = "重連彈框自動操作",
		ru = "Автоматическое действие при Переподключении",
	},
	handle_rejoin_popup_description = {
		en = "If you have kept auto joining an invalid session, try to open Mod Options and disable this option temporarily.",
		["zh-cn"] = "如果你遇到连续重连已失效的会话，请尝试打开模组选项再临时禁用此选项。",
		["zh-tw"] = "如果你遇到連續重連已失效的會話，請嘗試打開模组选項再臨時禁用此選項。",
		ru = "Если вы продолжаете автоматически присоединяться к недействительному сеансу, попробуйте открыть параметры мода и временно отключить эту опцию.",
	},
	opt_do_nothing = {
		en = "Do Nothing",
		["zh-cn"] = "什么都不做",
		["zh-tw"] = "什麼都不做",
		ru = "Ничего не делать",
	},
	opt_auto_rejoin = {
		en = Localize("loc_popup_reconnect_to_session_reconnect_button"),
	},
	opt_auto_leave = {
		en = Localize("loc_popup_reconnect_to_session_leave_button"),
	},
}
