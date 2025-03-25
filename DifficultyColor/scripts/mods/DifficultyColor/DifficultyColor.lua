local mod = get_mod("DifficultyColor")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")

local function update_color(settings)
	for i, danger in ipairs(settings) do
		local r = mod:get("opt_color_" .. tostring(i) .. "_r")
		local g = mod:get("opt_color_" .. tostring(i) .. "_g")
		local b = mod:get("opt_color_" .. tostring(i) .. "_b")
		if r and g and b then
			danger.color = { 255, r, g, b }
		end
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
