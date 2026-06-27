return {
	mod_name = {
		en = "Simple Audio",
		["zh-cn"] = "简易音频",
	},
	mod_description = {
		en = "Provides simple local audio playback for other mods.",
		["zh-cn"] = "为其他模组提供简单的本地音频播放功能。",
	},
	initialize_failed = {
		en = "Failed to initialize SimpleAudio: %s",
		["zh-cn"] = "初始化 SimpleAudio 失败：%s",
	},
	play_failed = {
		en = "Failed to play %s: %s",
		["zh-cn"] = "播放 %s 失败：%s",
	},
	log_wwise = {
		en = "Log Wwise events and sounds",
		["zh-cn"] = "记录 Wwise 事件和音频日志",
	},
	log_wwise_description = {
		en = "Print triggered Wwise sound names and their type to the developer console",
		["zh-cn"] = "在开发者控制台输出触发的 Wwise 音频名称和类型",
	},
	log_wwise_ui = {
		en = "Include UI sounds in Wwise logging",
		["zh-cn"] = "在 Wwise 日志中包括 UI 音频",
	},
	log_wwise_ui_description = {
		en = "Sounds matching the pattern \"events/ui\"",
		["zh-cn"] = "匹配“events/ui”模式的音频",
	},
	log_wwise_common = {
		en = "Include common sounds in Wwise logging",
		["zh-cn"] = "在 Wwise 日志中包括常规音频",
	},
	log_wwise_common_description = {
		en = "Sounds matching the pattern \"husk\", \"foley\", \"footstep\", \"locomotion\", \"material\", \"upper_body\" or \"vce\"",
		["zh-cn"] = "匹配“husk”、“foley”、“footstep”、“locomotion”、“material”、“upper_body”和“vce”模式的音频",
	},
	log_silenced = {
		en = "Include silenced sounds in Wwise logging",
		["zh-cn"] = "在 Wwise 日志中包括已静音音频",
	},
	log_silenced_description = {
		en = "Log dialogue lines and sound events even if they have been silenced by SimpleAudio",
		["zh-cn"] = "即使对白和音频事件已被 SimpleAudio 静音，也将其写入日志",
	},
	log_wwise_verbose = {
		en = "Verbose event logging",
		["zh-cn"] = "详细事件日志",
	},
	log_wwise_verbose_description = {
		en = "Log a table of all arguments for each event. This takes priority over logging to chat.",
		["zh-cn"] = "对每个事件，记录包含所有参数的表（table）。此选项优先于记录到聊天窗口。",
	},
	log_to_chat = {
		en = "Log to chat window instead of developer console",
		["zh-cn"] = "记录到聊天窗口而不是开发者控制台",
	},
	log_to_chat_description = {
		en = "Only affects non-verbose logging.",
		["zh-cn"] = "仅影响非详细日志。",
	},
}
