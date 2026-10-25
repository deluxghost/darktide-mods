local mod = get_mod("EquippedIconPlus")
local ProfileUtils = require("scripts/utilities/profile_utils")

local function migrate_color(setting_id, old_prefix)
	local r_id = old_prefix .. "_r"
	local g_id = old_prefix .. "_g"
	local b_id = old_prefix .. "_b"
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

mod.on_all_mods_loaded = function ()
	migrate_color("opt_active_color", "opt_active")
	migrate_color("opt_inactive_color", "opt_inactive")
end

local function item_equipped_in_loadout(loadout, item)
	if not loadout or not item.slots then
		return false
	end
	for _, slot_name in ipairs(item.slots) do
		local slot_item = loadout[slot_name]
		if slot_item then
			if type(slot_item) == "string" then
				if slot_item == item.gear_id then
					return true
				end
			else
				if slot_item.gear_id == item.gear_id then
					return true
				end
			end
		end
	end
	return false
end

mod:hook_require("scripts/ui/pass_templates/item_pass_templates", function (instance)
	for _, v in ipairs(instance.item) do
		if v.style_id == "equipped_icon" then
			v.visibility_function = function (content, style)
				if not content then
					return false
				end
				if content.equipped then
					style.color = mod:get("opt_active_color")
					return true
				end
				local item = content.element and content.element.item or nil
				if not item then
					return false
				end

				local presets = ProfileUtils.get_profile_presets()
				local current_preset_id = ProfileUtils.get_active_profile_preset_id()
				if #presets > 0 then
					for _, preset in ipairs(presets) do
						local current = preset.id and current_preset_id and preset.id == current_preset_id or false
						if not current and item_equipped_in_loadout(preset.loadout, item) then
							style.color = mod:get("opt_inactive_color")
							return true
						end
					end
				end
			end
			return
		end
	end
end)
