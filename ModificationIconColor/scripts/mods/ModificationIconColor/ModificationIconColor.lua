local mod = get_mod("ModificationIconColor")
require("scripts/ui/view_content_blueprints/item_stats_blueprints")

local function get_color_value(opt_prefix)
	return {
		255,
		mod:get(opt_prefix .. "_r"),
		mod:get(opt_prefix .. "_g"),
		mod:get(opt_prefix .. "_b"),
	}
end

mod:hook(package.loaded, "scripts/ui/view_content_blueprints/item_stats_blueprints", function(generate_blueprints_function, grid_size, optional_item)
	local blueprints = generate_blueprints_function(grid_size, optional_item)
	if not blueprints.weapon_perk or not blueprints.weapon_perk.pass_template then
		return blueprints
	end

	for _, pass in ipairs(blueprints.weapon_perk.pass_template) do
		if pass.style_id == "modified" then
			pass.style = pass.style or {}
			pass.style.text_color = get_color_value("opt_modified")
		elseif pass.style_id == "locked" then
			pass.style = pass.style or {}
			pass.style.text_color = get_color_value("opt_locked")
		end
	end
	return blueprints
end)
