local mod = get_mod("ItemBorderColor")

local DEFAULT_SELECTED_COLOR = { 255, 250, 189, 73 }

local cache = mod:persistent_table("cache")

local function migrate_color()
	local r_id = "opt_selected_r"
	local g_id = "opt_selected_g"
	local b_id = "opt_selected_b"
	local r = mod:get(r_id)
	local g = mod:get(g_id)
	local b = mod:get(b_id)

	if r ~= nil and g ~= nil and b ~= nil then
		mod:set("opt_selected_color", { 255, r, g, b })
		mod:set(r_id, nil)
		mod:set(g_id, nil)
		mod:set(b_id, nil)
	end
end

function mod.on_all_mods_loaded()
	migrate_color()
	cache.opt_selected_color = mod:get("opt_selected_color")
end

function mod.on_enabled()
	cache.opt_selected_color = mod:get("opt_selected_color")
end

mod.on_setting_changed = function (setting_id)
	if setting_id == "opt_selected_color" then
		cache.opt_selected_color = mod:get(setting_id)
	end
end

local function darken_color(color, percentage)
	color = table.clone(color)
	for i = 2, 4 do
		color[i] = color[i] * (1 - percentage)
	end
	return color
end

local function get_selected_color()
	return cache.opt_selected_color or DEFAULT_SELECTED_COLOR
end

local function hook_pass(pass, key, darken)
	pass.visibility_function = function (content, style)
		local color = DEFAULT_SELECTED_COLOR
		if mod:is_enabled() then
			color = get_selected_color()
		end
		style = style or {}
		style[key] = darken_color(color, darken)
		return true
	end
end

mod:hook_require("scripts/ui/pass_templates/item_pass_templates", function (templates)
	for _, template in pairs(templates) do
		if template and type(template) == "table" then
			for _, pass in ipairs(template) do
				if pass and type(pass) == "table" then
					if pass.style_id == "inner_highlight" then
						hook_pass(pass, "color", 0.33)
					elseif pass.style_id == "background" then
						hook_pass(pass, "selected_color", 0.33)
					elseif pass.style_id == "button_gradient" then
						hook_pass(pass, "selected_color", 0.33)
					elseif pass.style_id == "frame" then
						hook_pass(pass, "selected_color", 0.33)
					elseif pass.style_id == "corner" then
						hook_pass(pass, "selected_color", 0)
					end
				end
			end
		end
	end
end)
