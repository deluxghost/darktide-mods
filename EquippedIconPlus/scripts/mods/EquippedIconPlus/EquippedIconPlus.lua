local mod = get_mod("EquippedIconPlus")
local ProfileUtils = require("scripts/utilities/profile_utils")

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

mod:hook_require("scripts/ui/pass_templates/item_pass_templates", function(instance)
	for _, v in ipairs(instance.item) do
		if v.style_id == "equipped_icon" then
			v.visibility_function = function(content, style)
				if not content then
					return false
				end
				if content.equipped then
					style.color = { 255, mod:get("opt_active_r"), mod:get("opt_active_g"), mod:get("opt_active_b") }
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
							style.color = { 255, mod:get("opt_inactive_r"), mod:get("opt_inactive_g"), mod:get("opt_inactive_b") }
							return true
						end
					end
				end
			end
			return
		end
	end
end)
