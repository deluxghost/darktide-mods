local mod = get_mod("WhatTheLocalization")
local LocalizationManager = require("scripts/managers/localization/localization_manager")

local registered_fixes = mod:persistent_table("registered_fixes")

mod.on_enabled = function(initial_call)
	table.clear(Managers.localization._string_cache)
	table.clear(registered_fixes)
	local lang = Managers.localization._language
	local fix_templates = mod:io_dofile("WhatTheLocalization/scripts/mods/WhatTheLocalization/WTL_fix_templates")
	for _, fix in ipairs(fix_templates) do
		local lang_match = false
		if fix.locales then
			for _, locale in ipairs(fix.locales) do
				if locale == lang then
					lang_match = true
					break
				end
			end
		else
			lang_match = true
		end
		if lang_match then
			if fix.loc_keys then
				for _, loc_key in ipairs(fix.loc_keys) do
					registered_fixes[loc_key] = registered_fixes[loc_key] or {}
					table.insert(registered_fixes[loc_key], fix.handle_func)
				end
			end
		end
	end
end

mod.on_disabled = function(initial_call)
	table.clear(Managers.localization._string_cache)
end

mod:hook(LocalizationManager, "_lookup", function(func, self, key)
	local ret = func(self, key)
	local fixes = registered_fixes[key]
	if not fixes then
		return ret
	end
	for _, handle_func in ipairs(fixes) do
		ret = handle_func(Managers.localization._language, ret)
	end
	return ret
end)

mod.in_debug_mode = false

mod.toggle_debug_mode = function()
	mod.in_debug_mode = not mod.in_debug_mode
end

mod:hook(LocalizationManager, "localize", function(func, self, key, no_cache, context)
	local ret = func(self, key, no_cache, context)
	return mod.in_debug_mode and key or ret
end)
