local fix_templates = {
	{
		id = "thunder_hammer_name_remove_newline",
		loc_keys = {
			"loc_thunderhammer_2h_p1_m1",
			"loc_thunderhammer_2h_p1_m2",
		},
		handle_func = function(value)
			return string.trim(value)
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
		handle_func = function(value)
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
		handle_func = function(value)
			return "武器特殊攻击命中时，目标受到{stacks:%s}层{rending:%s}的脆弱。持续{time:%s}秒。"
		end,
	},
}

return fix_templates
