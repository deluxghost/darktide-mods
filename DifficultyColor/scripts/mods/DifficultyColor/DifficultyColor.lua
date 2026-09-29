local mod = get_mod("DifficultyColor")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")

local function migrate_colors()
	for i = 1, 5 do
		local setting_id = "opt_color_" .. tostring(i)
		local r_id = setting_id .. "_r"
		local g_id = setting_id .. "_g"
		local b_id = setting_id .. "_b"
		local r = mod:get(r_id)
		local g = mod:get(g_id)
		local b = mod:get(b_id)

		if r ~= nil and g ~= nil and b ~= nil then
			mod:set(setting_id, { 255, r, g, b })
			mod:set(r_id, nil)
			mod:set(g_id, nil)
			mod:set(b_id, nil)
		end
	end
end

local function update_color(settings)
	for i, danger in ipairs(settings.danger_levels) do
		local color = mod:get("opt_color_" .. tostring(i))
		if color then
			danger.color = color
		end
	end
end

mod.on_all_mods_loaded = function ()
	migrate_colors()
	if mod:is_enabled() then
		update_color(DangerSettings)
	end
end

mod.on_enabled = function ()
	update_color(DangerSettings)
end

mod.on_setting_changed = function (setting_id)
	update_color(DangerSettings)
end

mod:hook_require("scripts/settings/difficulty/danger_settings", function (settings)
	update_color(settings)
end)
