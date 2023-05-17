local mod = get_mod("WhatTheLocalization")

local fix_templates = {
	{
		id = "thunder_hammer_name_remove_newline",
		loc_keys = {
			"loc_thunderhammer_2h_p1_m1",
			"loc_thunderhammer_2h_p1_m2",
		},
		handle_func = function(locale, value)
			return string.trim(value)
		end,
	},
	{
		id = "vraks_mk3_headhunter_name_fix_zh_cn",
		loc_keys = {
			"loc_autogun_p3_m1",
		},
		locales = {
			"zh-cn",
		},
		handle_func = function(locale, value)
			-- compatible with Mark9
			return string.gsub(string.gsub(value, "VIII", "III"), "8", "3")
		end,
	},
	{
		id = "pinning_fire_desc_fix_zh_cn",
		loc_keys = {
			"loc_trait_bespoke_stacking_power_bonus_on_staggering_enemies_desc",
		},
		locales = {
			"zh-cn",
		},
		handle_func = function(locale, value)
			return string.gsub(value, ": ", ":")
		end,
	},
	{
		id = "can_opener_desc_fix_zh_cn",
		loc_keys = {
			"loc_trait_bespoke_armor_rending_bayonette_desc",
		},
		locales = {
			"zh-cn",
		},
		handle_func = function(locale, value)
			return "武器特殊攻击命中时，目标受到{stacks:%s}层{rending:%s}的脆弱。持续{time:%s}秒。"
		end,
	},
}

return fix_templates
