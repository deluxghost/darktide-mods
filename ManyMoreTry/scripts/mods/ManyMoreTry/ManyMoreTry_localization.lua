local mod = get_mod("ManyMoreTry")

mod:add_global_localize_strings({
	loc_mod_mmt_save = {
		en = "Save Mission",
		["zh-cn"] = "保存任务",
	},
})

return {
	mod_name = {
		en = "Many More Try",
		["zh-cn"] = "再来很多局",
	},
	mod_description = {
		en = "Mission ID saving/sharing mod. Check commands with '/mmt' prefix for details.\nNote: Fatshark will nerf the mission expire time eventually.",
		["zh-cn"] = "任务 ID 保存/分享模组。用法详见带有“/mmt”前缀的命令。\n注意：肥鲨确认会在将来缩短任务过期时间。",
	},
	text_expired = {
		en = "Expired",
		["zh-cn"] = "已过期",
	},
	text_started = {
		en = "Started #hrs ago",
		["zh-cn"] = "开始于 # 小时前",
	},
	msg_already_saved = {
		en = "Already saved: ",
		["zh-cn"] = "已保存过：",
	},
	msg_saved = {
		en = "Saved mission: ",
		["zh-cn"] = "保存了任务：",
	},
	msg_command_busy = {
		en = "Error: command is busy",
		["zh-cn"] = "错误：命令正忙",
	},
	msg_not_in_hub = {
		en = "Error: not in Mourningstar",
		["zh-cn"] = "错误：不在哀星号上",
	},
	msg_not_in_party = {
		en = "Error: not in a Strike Team",
		["zh-cn"] = "错误：不在打击小队中",
	},
	msg_on_your_way_to = {
		en = "On your way to: ",
		["zh-cn"] = "正在前往：",
	},
	msg_no_saved_mission = {
		en = "No saved mission",
		["zh-cn"] = "未保存任务",
	},
	msg_saved_mission = {
		en = "Saved missions:",
		["zh-cn"] = "保存的任务：",
	},
	msg_invalid_number = {
		en = "Error: invalid number",
		["zh-cn"] = "错误：编号无效",
	},
	msg_expired_safe_to_delete = {
		en = "Error: mission is expired, please remove manually",
		["zh-cn"] = "错误：任务已过期，请手动删除",
	},
	msg_unknown_err = {
		en = "Error: unknown reason",
		["zh-cn"] = "错误：未知原因",
	},
	msg_removed = {
		en = "Removed mission: ",
		["zh-cn"] = "删除了任务：",
	},
	msg_cleared = {
		en = "Cleared # mission(s)",
		["zh-cn"] = "清理了 # 个任务",
	},
	msg_help_queue = {
		en = "Type {#color(0,192,255)}/mmt mission_number{#reset()} to queue (e.g. {#color(0,192,255)}/mmt 1{#reset()})",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmt 任务编号{#reset()} 开始匹配（例：{#color(0,192,255)}/mmt 1{#reset()}）",
	},
	msg_help_del = {
		en = "Type {#color(0,192,255)}/mmtdel mission_number{#reset()} to remove",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmtdel 任务编号{#reset()} 删除",
	},
	msg_help_clear = {
		en = "Type {#color(0,192,255)}/mmtclear hours_ago{#reset()} to clear missions started longer than 'hours_ago' hrs ago",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmtclear 小时数{#reset()} 清理开始时间超过相应小时的任务",
	},
	msg_nothing_to_export = {
		en = "Error: no mission to export",
		["zh-cn"] = "错误：没有能导出的任务",
	},
	msg_copy_err = {
		en = "Error: failed to copy to clipboard",
		["zh-cn"] = "错误：复制到剪贴板失败",
	},
	msg_data_copied = {
		en = "Data copied to clipboard",
		["zh-cn"] = "数据已复制到剪贴板",
	},
	msg_help_export = {
		en = "Type {#color(0,192,255)}/mmtexport{#reset()} to export all missions",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmtexport{#reset()} 导出所有任务",
	},
	msg_help_import = {
		en = "Type {#color(0,192,255)}/mmtimport mission_id{#reset()} to import",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmtimport 任务ID{#reset()} 导入任务",
	},
	msg_import_invalid_mission = {
		en = "Error: invalid mission id",
		["zh-cn"] = "错误：任务 ID 无效",
	},
	cmd_main = {
		en = "View and queue saved missions",
		["zh-cn"] = "查看和匹配已保存的任务",
	},
	cmd_del = {
		en = "Remove saved mission",
		["zh-cn"] = "删除已保存的任务",
	},
	cmd_export = {
		en = "Export all saved missions",
		["zh-cn"] = "导出所有已保存的任务",
	},
	cmd_import = {
		en = "Import a mission ID",
		["zh-cn"] = "导入一个任务 ID",
	},
	cmd_clear = {
		en = "Clear missions started X hours ago",
		["zh-cn"] = "清理已开始了 X 小时的任务",
	},
	private_game = {
		en = "Private game",
		["zh-cn"] = "私人游戏",
	},
	private_game_description = {
		en = "WARNING: Think twice before turn off this option, not all quickplay players are happy with your 'hidden' mission.",
		["zh-cn"] = "警告：关闭此选项前请认真考虑，不是所有快速游戏玩家都愿意加入你的“隐藏”任务。",
	},
}
