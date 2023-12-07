local mod = get_mod("ItemSorting")
local ItemSortingUtils = {}

function ItemSortingUtils.get_trait_category(item)
	if item.item_type == "GADGET" then
		if item.traits and #item.traits > 0 then
			return item.traits[1].id
		end
	end
	return item.trait_category or ""
end

function ItemSortingUtils.has_unearned_trait(item)
	if item.item_type ~= "WEAPON_MELEE" and item.item_type ~= "WEAPON_RANGED" then
		return false
	end
	if not item.traits then
		return false
	end
	local cache = Managers.data_service.crafting._trait_sticker_book_cache
	if not cache then
		return false
	end
	local category = cache:cached_data_by_key(item.trait_category)
	if not category then
		return false
	end

	for _, trait in ipairs(item.traits) do
		if trait.rarity then
			local book = category[trait.id]
			if book then
				if book[trait.rarity] ~= "seen" then
					local i = trait.rarity + 1
					local low = false
					while book[i] and book[i] ~= "invalid" do
						if book[i] == "seen" then
							low = true
							break
						end
						i = i + 1
					end
					if not low then
						return true
					end
				end
			end
		end
	end
	return false
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

function ItemSortingUtils.compare_item_top_unearned_blessings(a, b)
	if not mod:get("always_on_top_store_unearned_blessing") then
		return nil
	end
	local a_unearned = ItemSortingUtils.has_unearned_trait(a)
	local b_unearned = ItemSortingUtils.has_unearned_trait(b)
	if a_unearned and not b_unearned then
		return true
	elseif b_unearned and not a_unearned then
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
		if a.__isort_type_current and not b.__isort_type_current then
			return true
		elseif b.__isort_type_current and not a.__isort_type_current then
			return false
		end
	end
	return nil
end

function ItemSortingUtils.compare_item_category(a, b)
	local a_category = ItemSortingUtils.get_trait_category(a)
	local b_category = ItemSortingUtils.get_trait_category(b)

	if a_category < b_category then
		return true
	elseif b_category < a_category then
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
