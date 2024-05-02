local mod = get_mod("ManyMoreTry")

mod:add_global_localize_strings({
	loc_mod_mmt_save = {
		en = "Save Mission",
		["zh-cn"] = "保存任务",
		ru = "Сохранить миссию",
	},
})

return {
	mod_name = {
		en = "Many More Try",
		["zh-cn"] = "再来很多局",
		ru = "Ещё больше попыток",
	},
	mod_description = {
		en = "Mission ID saving/sharing mod. Check commands with '/mmt' prefix for details.\nNote: Fatshark claims they will nerf the mission expire time eventually.",
		["zh-cn"] = "任务 ID 保存/分享模组。用法详见带有“/mmt”前缀的命令。\n注意：肥鲨声称会在将来缩短任务过期时间。",
		ru = "Many More Try - Мод позволяет сохранять и передавать идентификатор миссии. Для получения подробной информации проверьте команды с префиксом «/mmt».\nПримечание: Fatshark утверждает, что со временем они уменьшат время завершения миссии.",
	},
	text_expired = {
		en = "Expired",
		["zh-cn"] = "已过期",
		ru = "Срок действия истёк",
	},
	text_started = {
		en = "Started #hrs ago",
		["zh-cn"] = "开始于 # 小时前",
		ru = "С начала миссии прошло часов: #",
	},
	msg_already_saved = {
		en = "Already saved: ",
		["zh-cn"] = "已保存过：",
		ru = "Уже сохранена!",
	},
	msg_saved = {
		en = "Saved mission: ",
		["zh-cn"] = "保存了任务：",
		ru = "Сохранена миссия: ",
	},
	msg_command_busy = {
		en = "Error: command is busy",
		["zh-cn"] = "错误：命令正忙",
		ru = "Ошибка: команда в работе",
	},
	msg_not_in_party = {
		en = "Error: private game is enabled in the Mission Board, but you are not in a Strike Team",
		["zh-cn"] = "错误：任务面板中已启用私人游戏，但你不在打击小队中",
		ru = "Ошибка: закрытая игра включена в меню миссий, но вы не состоите в Ударной группе",
	},
	msg_on_your_way_to = {
		en = "On your way to: ",
		["zh-cn"] = "正在前往：",
		ru = "Вы направляетесь в: ",
	},
	msg_no_saved_mission = {
		en = "No saved mission",
		["zh-cn"] = "未保存任务",
		ru = "Нет сохранённых миссий",
	},
	msg_saved_mission = {
		en = "Saved missions:",
		["zh-cn"] = "保存的任务：",
		ru = "Сохранённые миссии:",
	},
	msg_no_valid_last_mission = {
		en = "Error: no valid last mission",
		["zh-cn"] = "错误：未找到有效的上次任务",
		ru = "Ошибка: нет действительной последней миссии",
	},
	msg_invalid_number = {
		en = "Error: invalid number",
		["zh-cn"] = "错误：编号无效",
		ru = "Ошибка: неверный номер",
	},
	msg_expired = {
		en = "Error: mission is expired",
		["zh-cn"] = "错误：任务已过期",
		ru = "Ошибка: срок действия миссии истёк",
	},
	msg_expired_safe_to_delete = {
		en = "Error: mission is expired, please remove manually",
		["zh-cn"] = "错误：任务已过期，请手动删除",
		ru = "Ошибка: срок действия миссии истёк, удалите её вручную",
	},
	msg_level_required = {
		en = "Error: character hasn't reached the required level of this mission",
		["zh-cn"] = "错误：角色未达到任务所需等级",
		ru = "Ошибка: персонаж не достиг необходимого уровня для этой миссии",
	},
	msg_team_not_available = {
		en = "Error: team is not available for matchmaking",
		["zh-cn"] = "错误：队伍还无法进行匹配",
		ru = "Ошибка: команда недоступна для подбора миссии",
	},
	msg_unknown_err = {
		en = "Error: unknown reason",
		["zh-cn"] = "错误：未知原因",
		ru = "Ошибка: неизвестная причина",
	},
	msg_removed = {
		en = "Removed mission: ",
		["zh-cn"] = "删除了任务：",
		ru = "Удалена миссия: ",
	},
	msg_cleared = {
		en = "Cleared # mission(s)",
		["zh-cn"] = "清理了 # 个任务",
		ru = "Очищено миссий: #",
	},
	msg_help_queue = {
		en = "Type {#color(0,192,255)}/mmt mission_number_or_id{#reset()} to queue (e.g. {#color(0,192,255)}/mmt 1{#reset()})",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmt 任务编号或ID{#reset()} 开始匹配（例：{#color(0,192,255)}/mmt 1{#reset()}）",
		ru = "Напишите {#color(0,192,255)}/mmt номер_миссии_или_идентификатор{#reset()}, чтобы запустить её (например {#color(0,192,255)}/mmt 1{#reset()})",
	},
	msg_help_del = {
		en = "Type {#color(0,192,255)}/mmtdel mission_number{#reset()} to remove",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmtdel 任务编号{#reset()} 删除",
		ru = "Напишите {#color(0,192,255)}/mmtdel номер_миссии{#reset()}, чтобы удалить её",
	},
	msg_help_clear = {
		en = "Type {#color(0,192,255)}/mmtclear hours_ago{#reset()} to clear missions started longer than 'hours_ago' hrs ago",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmtclear 小时数{#reset()} 清理开始时间超过相应小时的任务",
		ru = "Напишите {#color(0,192,255)}/mmtclear часов_назад{#reset()}, чтобы очистить миссии старше «часов_назад»",
	},
	msg_nothing_to_export = {
		en = "Error: no mission to export",
		["zh-cn"] = "错误：没有能导出的任务",
		ru = "Ошибка: нет миссий для экспорта",
	},
	msg_copy_err = {
		en = "Error: failed to copy to clipboard",
		["zh-cn"] = "错误：复制到剪贴板失败",
		ru = "Ошибка: не удалось скопировать в буфер обмена",
	},
	msg_data_copied = {
		en = "Data copied to clipboard",
		["zh-cn"] = "数据已复制到剪贴板",
		ru = "Данные скопированы в буфер обмена",
	},
	msg_help_export = {
		en = "Type {#color(0,192,255)}/mmtexport{#reset()} to export all missions",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmtexport{#reset()} 导出所有任务",
		ru = "Напишите {#color(0,192,255)}/mmtexport{#reset()}, чтобы экспортировать все миссии",
	},
	msg_help_import = {
		en = "Type {#color(0,192,255)}/mmtimport mission_id{#reset()} to import",
		["zh-cn"] = "输入 {#color(0,192,255)}/mmtimport 任务ID{#reset()} 导入任务",
		ru = "Напишите {#color(0,192,255)}/mmtimport идентификатор_миссии{#reset()}, чтобы импортировать миссию",
	},
	msg_import_invalid_mission = {
		en = "Error: invalid mission ID",
		["zh-cn"] = "错误：任务 ID 无效",
		ru = "Ошибка: неправильный идентификатор миссии",
	},
	cmd_main = {
		en = "View and queue saved missions",
		["zh-cn"] = "查看和匹配已保存的任务",
		ru = "Просмотр и постановка в очередь сохранённых миссий",
	},
	cmd_lm = {
		en = "Replay the last mission",
		["zh-cn"] = "重玩上次进行的任务",
		ru = "Переиграть последнюю миссию",
	},
	cmd_del = {
		en = "Remove saved mission",
		["zh-cn"] = "删除已保存的任务",
		ru = "Удалить сохранённую миссию",
	},
	cmd_export = {
		en = "Export all saved missions",
		["zh-cn"] = "导出所有已保存的任务",
		ru = "Экспортировать все сохранённые миссии",
	},
	cmd_import = {
		en = "Import a mission ID",
		["zh-cn"] = "导入一个任务 ID",
		ru = "Импортировать идентификатор миссии",
	},
	cmd_clear = {
		en = "Clear missions started X hours ago",
		["zh-cn"] = "清理已开始了 X 小时的任务",
		ru = "Убрать миссии, начатые X часов назад",
	},
	cmd_get = {
		en = "Open mission history online website",
		["zh-cn"] = "打开任务历史记录在线网站",
		ru = "Открыть онлайн-сайт с историей миссий",
	},
}
