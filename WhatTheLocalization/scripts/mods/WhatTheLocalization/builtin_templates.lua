local mod = get_mod("WhatTheLocalization")

local templates = {
	{
		id = "vraks_mk3_headhunter_name_fix_zh_cn",
		loc_keys = {
			"loc_autogun_p3_m1",
		},
		locales = {
			"zh-cn",
		},
		handle_func = function (locale, value)
			-- compatible with Mark9
			return string.gsub(string.gsub(value, "VIII", "III"), "8", "3")
		end,
	},
}

return templates
