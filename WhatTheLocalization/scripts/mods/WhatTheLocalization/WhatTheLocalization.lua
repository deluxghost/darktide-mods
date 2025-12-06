local mod = get_mod("WhatTheLocalization")
local DMF = get_mod("DMF")
local LocalizationManager = require("scripts/managers/localization/localization_manager")

local registered_fixes = mod:persistent_table("registered_fixes")

local function load_templates(templates, lang)
	if templates == nil then
		return
	end
	for _, fix in ipairs(templates) do
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
					if loc_key and fix.handle_func then
						registered_fixes[loc_key] = registered_fixes[loc_key] or {}
						table.insert(registered_fixes[loc_key], fix.handle_func)
					end
				end
			end
		end
	end
end

mod.reload_templates = function ()
	if not mod:is_enabled() then
		return
	end
	table.clear(Managers.localization._string_cache)
	table.clear(registered_fixes)
	local lang = Managers.localization._language
	local builtin_templates = mod:io_dofile("WhatTheLocalization/scripts/mods/WhatTheLocalization/builtin_templates")
	load_templates(builtin_templates, lang)
	for _, other_mod in pairs(DMF.mods) do
		if type(other_mod) == "table" and other_mod:is_enabled() and other_mod.localization_templates then
			load_templates(other_mod.localization_templates, lang)
		end
	end
end

mod.on_enabled = function ()
	mod.reload_templates()
end

mod.on_all_mods_loaded = function ()
	mod.reload_templates()
end

mod.on_disabled = function ()
	table.clear(Managers.localization._string_cache)
	table.clear(registered_fixes)
end

mod:hook(LocalizationManager, "_process_string", function (func, self, key, raw_str, context)
	local fixes = registered_fixes[key]
	if fixes then
		for _, handle_func in ipairs(fixes) do
			raw_str = handle_func(Managers.localization._language, raw_str, context)
		end
	end
	context = context or {}
	return func(self, key, raw_str, context)
end)

mod.toggle_debug_mode = function ()
	if not Managers.ui:chat_using_input() then
		local debug_mode = not mod:get("enable_debug_mode")
		mod:set("enable_debug_mode", debug_mode, false)
		if debug_mode then
			mod:notify(mod:localize("message_debug_mode_on"))
		else
			mod:notify(mod:localize("message_debug_mode_off"))
		end
	end
end

mod:hook(LocalizationManager, "localize", function (func, self, key, no_cache, context)
	local ret = func(self, key, no_cache, context)
	return mod:get("enable_debug_mode") and key or ret
end)

local visualize_mapping = {
	[" "] = "",
	["\t"] = "",
	["\n"] = "\n",
	["\r"] = "",
}

mod:command("loc", mod:localize("loc_command_description"), function (key)
	if not key then
		mod:echo(mod:localize("loc_command_missing_key"))
		return
	end
	local message = Managers.localization:_lookup(key)
	if message then
		message = message:gsub("%%", "%%%%")
		if mod:get("loc_command_output_visualize") then
			for pat, repl in pairs(visualize_mapping) do
				message = message:gsub(pat, repl)
			end
		end
		mod:echo(message)
		return
	end
	mod:echo(mod:localize("loc_command_not_found"))
end)
