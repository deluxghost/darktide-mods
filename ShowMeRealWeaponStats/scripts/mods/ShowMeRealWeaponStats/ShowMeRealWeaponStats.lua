local mod = get_mod("ShowMeRealWeaponStats")
require("scripts/ui/view_content_blueprints/item_stats_blueprints")
local WeaponStats = require("scripts/utilities/weapon_stats")
local ViewElementWeaponInfo = require("scripts/ui/view_elements/view_element_weapon_info/view_element_weapon_info")

local bar_size = 100

local function fake_item(item)
	local clone = table.clone(item)
	setmetatable(clone, {
		__index = function(t, field_name)
			if field_name == "gear_id" then
				return rawget(clone, "__gear_id")
			end
			if field_name == "gear" then
				return rawget(clone, "__gear")
			end

			local master_item = rawget(clone, "__master_item")
			if not master_item then
				return nil
			end

			local field_value = master_item[field_name]
			if field_name == "rarity" and field_value == -1 then
				return nil
			end
			return field_value
		end,
	})
	return clone
end

local function get_breakdown_compare_string(breakdown)
	local type_data = breakdown.type_data
	local group_type_data = breakdown.group_type_data
	local override_data = breakdown.override_data or {}

	local name = ""
	if type_data.display_name then
		name = name .. type_data.display_name
	end
	if override_data.display_name then
		name = name .. override_data.display_name
	end
	local group_prefix = group_type_data and group_type_data.prefix and group_type_data.prefix or ""
	local prefix = override_data.prefix or type_data.prefix
	prefix = prefix and prefix .. " " or ""
	local postfix = group_type_data and group_type_data.postfix and group_type_data.postfix .. " " or ""
	local suffix = (override_data.suffix or type_data.suffix) and (override_data.suffix or type_data.suffix) or ""
	return string.format("%s %s%s%s%s", group_prefix, prefix, name, suffix, postfix)
end

local function same_breakdown(a, b)
	return get_breakdown_compare_string(a) == get_breakdown_compare_string(b)
end

local function get_item_stats(item)
	local weapon_stats = WeaponStats:new(item)
	local comparing_stats = weapon_stats:get_comparing_stats()
	local num_stats = table.size(comparing_stats)
	local comparing_stats_array = {}
	for key, stat in pairs(comparing_stats) do
		comparing_stats_array[#comparing_stats_array + 1] = stat
	end

	local bar_breakdown = table.clone(weapon_stats._weapon_statistics.bar_breakdown)
	return comparing_stats_array, bar_breakdown
end

mod:hook(package.loaded, "scripts/ui/view_content_blueprints/item_stats_blueprints", function(generate_blueprints_function, grid_size, optional_item)
	local blueprints = generate_blueprints_function(grid_size, optional_item)
	if not blueprints.weapon_stats or not blueprints.weapon_stats.init or not blueprints.weapon_stats.update then
		return blueprints
	end

	local old_init = blueprints.weapon_stats.init
	blueprints.weapon_stats.init = function(parent, widget, element, callback_name)
		local ret = old_init(parent, widget, element, callback_name)

		local content = widget.content
		local style = widget.style
		local item = element.item
		local item_clone = fake_item(item)
		for _, stat in pairs(item_clone.base_stats) do
			stat.value = mod:get("max_modifier_score") / 100
		end

		local stats_array, bar_breakdown = get_item_stats(item)
		local stats_array_fake, bar_breakdown_fake = get_item_stats(item_clone)

		for i = 1, #stats_array do
			for _, breakdown in ipairs(content["bar_breakdown_" .. i]) do
				for _, breakdown_fake in ipairs(bar_breakdown_fake[i]) do
					if same_breakdown(breakdown, breakdown_fake) then
						breakdown.max_real = breakdown_fake.value
					end
				end
			end
			local bar_value = content["bar_breakdown_" .. i].value
			local bar_style = style["bar_" .. i]
			if mod:get("show_full_bar") then
				local multiplier = mod:get("max_modifier_score") > 0 and 100 / mod:get("max_modifier_score") or 100
				bar_style.size[1] = bar_size * bar_value * multiplier
				if bar_style.size[1] > bar_size then
					bar_style.size[1] = bar_size
				end
			end
		end
		return ret
	end
	return blueprints
end)

mod:hook(ViewElementWeaponInfo, "_get_stats_text", function(func, self, stat)
	local stat_clone = table.clone(stat)
	if mod:get("show_real_max_breakdown") then
		stat_clone.max = stat_clone.max_real or stat_clone.max
	end
	return func(self, stat_clone)
end)
