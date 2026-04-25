local mod = get_mod("SoloPlayStratagems")
local Pickups = require("scripts/settings/pickup/pickups")

mod.templates = mod:io_dofile("SoloPlayStratagems/scripts/mods/SoloPlayStratagems/templates")

local localization = {
	mod_name = {
		en = "Solo Play - Stratagems DLC",
		["zh-cn"] = "单人游戏 - 战略配备 DLC",
	},
	mod_description = {
		en = "Gives you a super way to acquire stratagems in Solo Play missions",
		["zh-cn"] = "在「单人游戏」任务中，使用一种超级方法获取战略配备",
	},
	group_stratagem_controls = {
		en = "Controls",
		["zh-cn"] = "控制",
	},
	stratagem_menu_keybind = {
		en = "Keybind: stratagem menu",
		["zh-cn"] = "快捷键：战略配备菜单",
	},
	stratagem_menu_hold_mode = {
		en = "Hold to show menu",
		["zh-cn"] = "按住显示菜单",
	},
	stratagem_menu_title = {
		en = "Stratagems",
		["zh-cn"] = "战略配备",
	},
	stratagem_none = {
		en = "None",
		["zh-cn"] = "无",
	},
	stratagem_slot = {
		en = "Stratagem Slot",
		["zh-cn"] = "战略配备槽位",
	},
}

for idx = 1, mod.templates.MAX_ACTIVE_STRATAGEMS do
	local idx_str = tostring(idx)
	local slot_loc = {}
	for locale, val in pairs(localization.stratagem_slot) do
		slot_loc[locale] = val .. " " .. idx_str
	end
	localization["stratagem_slot_" .. idx_str] = slot_loc
end

for _, template in ipairs(mod.templates.stratagems) do
	local pocketable = template.pocketable
	if pocketable ~= "" then
		local pickup = Pickups.by_name[template.pocketable]
		local name = pickup and pickup.description and Localize(pickup.description) or template.pocketable
		localization["loc_stratagem_" .. pocketable] = {
			en = name,
		}
	end
end

return localization
