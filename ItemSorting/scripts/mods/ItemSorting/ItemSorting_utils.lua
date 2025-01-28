local mod = get_mod("ItemSorting")
local ItemUtils = require("scripts/utilities/items")
local ItemSortingUtils = {}

function ItemSortingUtils.sort_element_key_comparator(definitions)
	return function (a, b)
		for i = 1, #definitions, 3 do
			local order, key, func = definitions[i], definitions[i + 1], definitions[i + 2]

			local a_value, b_value = key and a[key], key and b[key]
			if not a_value or not b_value then
				return nil
			end

			local is_lt = func(a_value, b_value)
			if is_lt ~= nil then
				if order == "<" or order == "true" then
					return is_lt
				else
					return not is_lt
				end
			end
		end

		return nil
	end
end


function ItemSortingUtils.get_trait_category(item)
	if item.item_type == "GADGET" then
		if item.traits and #item.traits > 0 then
			return item.traits[1].id
		end
	end
	return item.trait_category or ""
end

function ItemSortingUtils.compare_item_new(a, b)
	if not mod:get("always_on_top_new") then
		return nil
	end
	if a.__isort_new and not b.__isort_new then
		return true
	elseif b.__isort_new and not a.__isort_new then
		return false
	end
	return nil
end

function ItemSortingUtils.compare_item_type_new(a, b)
	if not mod:get("always_on_top_new") then
		return nil
	end
	if not mod:get("entire_category_on_top") then
		if a.__isort_new and not b.__isort_new then
			return true
		elseif b.__isort_new and not a.__isort_new then
			return false
		end
		return nil
	end

	if a.__isort_type_new and not b.__isort_type_new then
		return true
	elseif b.__isort_type_new and not a.__isort_type_new then
		return false
	end
		return nil
end

function ItemSortingUtils.compare_item_equipped(a, b)
	if not mod:get("always_on_top_equipped") then
		return nil
	end
	if a.__isort_equipped and not b.__isort_equipped then
		return true
	elseif b.__isort_equipped and not a.__isort_equipped then
		return false
	elseif a.__isort_equipped and b.__isort_equipped then
		if a.__isort_current and not b.__isort_current then
			return true
		elseif b.__isort_current and not a.__isort_current then
			return false
		end
	end
	return nil
end

function ItemSortingUtils.compare_item_type_equipped(a, b)
	if not mod:get("always_on_top_equipped") then
		return nil
	end
	if not mod:get("entire_category_on_top") then
		if a.__isort_equipped and not b.__isort_equipped then
			return true
		elseif b.__isort_equipped and not a.__isort_equipped then
			return false
		elseif a.__isort_equipped and b.__isort_equipped then
			if a.__isort_current and not b.__isort_current then
				return true
			elseif b.__isort_current and not a.__isort_current then
				return false
			end
		end
		return nil
	end
	if a.__isort_type_equipped and not b.__isort_type_equipped then
		return true
	elseif b.__isort_type_equipped and not a.__isort_type_equipped then
		return false
	end
	return nil
end

function ItemSortingUtils.compare_item_myfav(a, b)
	if not mod:get("always_on_top_myfav") then
		return nil
	end
	if a.__isort_myfav and not b.__isort_myfav then
		return true
	elseif b.__isort_myfav and not a.__isort_myfav then
		return false
	elseif a.__isort_myfav and b.__isort_myfav then
		if a.__isort_myfav < b.__isort_myfav then
			return true
		elseif b.__isort_myfav < a.__isort_myfav then
			return false
		end
	end
	return nil
end

function ItemSortingUtils.compare_item_type_myfav(a, b)
	if not mod:get("always_on_top_myfav") then
		return nil
	end
	if not mod:get("entire_category_on_top") then
		if a.__isort_myfav and not b.__isort_myfav then
			return true
		elseif b.__isort_myfav and not a.__isort_myfav then
			return false
		elseif a.__isort_myfav and b.__isort_myfav then
			if a.__isort_myfav < b.__isort_myfav then
				return true
			elseif b.__isort_myfav < a.__isort_myfav then
				return false
			end
		end
		return nil
	end
	if a.__isort_type_myfav and not b.__isort_type_myfav then
		return true
	elseif b.__isort_type_myfav and not a.__isort_type_myfav then
		return false
	end
	return nil
end

function ItemSortingUtils.compare_item_top_curios(a, b)
	if not mod:get("always_on_top_curio") then
		return nil
	end
	if a.item_type == "GADGET" and b.item_type ~= "GADGET" then
		return true
	elseif b.item_type == "GADGET" and a.item_type ~= "GADGET" then
		return false
	end
	return nil
end

function ItemSortingUtils.compare_item_category_top_items(a, b)
	local a_category = ItemSortingUtils.get_trait_category(a)
	local b_category = ItemSortingUtils.get_trait_category(b)

	if a_category == b_category then
		if mod:get("always_on_top_new") and mod:get("on_top_of_category") then
			if a.__isort_new and not b.__isort_new then
				return true
			elseif b.__isort_new and not a.__isort_new then
				return false
			end
		end
		if mod:get("always_on_top_equipped") and mod:get("on_top_of_category") then
			if a.__isort_equipped and not b.__isort_equipped then
				return true
			elseif b.__isort_equipped and not a.__isort_equipped then
				return false
			end
			if a.__isort_current and not b.__isort_current then
				return true
			elseif b.__isort_current and not a.__isort_current then
				return false
			end
		end
		if mod:get("always_on_top_myfav") and mod:get("on_top_of_category") then
			if a.__isort_myfav and not b.__isort_myfav then
				return true
			elseif b.__isort_myfav and not a.__isort_myfav then
				return false
			elseif a.__isort_myfav and b.__isort_myfav then
				if a.__isort_myfav < b.__isort_myfav then
					return true
				elseif b.__isort_myfav < a.__isort_myfav then
					return false
				end
			end
		end
	elseif a.__isort_type_equipped and b.__isort_type_equipped then
		if mod:get("always_on_top_equipped") and mod:get("entire_category_on_top") then
			if a.__isort_type_current and not b.__isort_type_current then
				return true
			elseif b.__isort_type_current and not a.__isort_type_current then
				return false
			end
		end
	end
	return nil
end

function ItemSortingUtils.compare_item_category(a, b)
	local a_category = ItemSortingUtils.get_trait_category(a)
	local b_category = ItemSortingUtils.get_trait_category(b)
	local a_name, b_name = "", ""
	if ItemUtils.is_weapon(a.item_type) then
		a_name = ItemUtils.weapon_lore_family_name(a)
	end
	if ItemUtils.is_weapon(b.item_type) then
		b_name = ItemUtils.weapon_lore_family_name(b)
	end

	if a_category == b_category then
		return nil
	end
	if a_name == "" and b_name == "" then
		if a_category < b_category then
			return true
		elseif b_category < a_category then
			return false
		end
		return nil
	end
	if a_name == "" then
		return true
	elseif b_name == "" then
		return false
	end
	if a_name < b_name then
		return true
	elseif b_name < a_name then
		return false
	end
	return nil
end

function ItemSortingUtils.compare_item_mark(a, b)
	if a.item_type == "GADGET" or b.item_type == "GADGET" then
		return nil
	end

	local a_mark = ""
	local b_mark = ""
	if a.weapon_mark_display_name and a.weapon_mark_display_name.loc_id then
		a_mark = a.weapon_mark_display_name.loc_id
	end
	if b.weapon_mark_display_name and b.weapon_mark_display_name.loc_id then
		b_mark = b.weapon_mark_display_name.loc_id
	end

	if a_mark < b_mark then
		return true
	elseif b_mark < a_mark then
		return false
	end
	return nil
end

function ItemSortingUtils.compare_item_base_level(a, b)
	local a_level = a.baseItemLevel or 0
	local b_level = b.baseItemLevel or 0

	if a_level < b_level then
		return true
	elseif b_level < a_level then
		return false
	end
	return nil
end

function ItemSortingUtils.compare_offer_owned(a_offer, b_offer)
	if a_offer and b_offer then
		local a_owned = a_offer.state and (a_offer.state == "owned" or a_offer.state == "completed")
		local b_owned = b_offer.state and (b_offer.state == "owned" or b_offer.state == "completed")

		if a_owned and not b_owned then
			return true
		elseif b_owned and not a_owned then
			return false
		end
	end

	return nil
end

return ItemSortingUtils
