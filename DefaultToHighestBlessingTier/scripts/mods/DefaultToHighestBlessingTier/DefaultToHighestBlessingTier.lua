local mod = get_mod("DefaultToHighestBlessingTier")
local ViewElementTraitInventory = require("scripts/ui/view_elements/view_element_trait_inventory/view_element_trait_inventory")

mod:hook(ViewElementTraitInventory, "present_inventory", function (func, self, sticker_book, ingredients, external_left_click_callback, do_animation)
    self._sticker_book = sticker_book
	self._ingredients = ingredients
	self._external_left_click_callback = external_left_click_callback

    local highest = 1
    for _, book in pairs(sticker_book) do
        for i, state in ipairs(book) do
            if state == "seen" and i > highest then
                highest = i
            end
        end
    end

	self:_switch_to_rank_tab(highest, true)
	self:_update_tab_counts()

	if self._do_animations then
		self:start_animation()
	end

	self._active = true
	self._disabled = false
end)
