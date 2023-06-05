local mod = get_mod("OpenSteamProfile")
local SocialConstants = require("scripts/managers/data_service/services/social/social_constants")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

mod:hook_safe("SocialMenuRosterView", "init", function(self, settings, context)
	self.cb_show_steam_profile = function (self, player_info)
		self:_close_popup_menu()

		local dec_id = Steam.id_hex_to_dec(player_info:platform_user_id())
		if dec_id then
			if mod:get("use_steam_overlay") then
				Steam.open_url("http://steamcommunity.com/profiles/" .. dec_id)
			else
				Application.open_url_in_browser("http://steamcommunity.com/profiles/" .. dec_id)
			end
		end
	end
end)

mod:hook_require("scripts/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup_content_list", function(instance)
	mod:hook(instance, "from_player_info", function(func, parent, player_info)
		local menu_items, num_menu_items = func(parent, player_info)
		local social_service = Managers.data_service.social
		if social_service:platform() ~= SocialConstants.Platforms.steam then
			return menu_items, num_menu_items
		end
		if player_info:is_own_player() then
			return menu_items, num_menu_items
		end
		local entry = {
			label = mod:localize("open_steam_profile_button"),
			on_pressed_sound = UISoundEvents.social_menu_see_player_profile,
			callback = callback(parent, "cb_show_steam_profile", player_info),
			blueprint = "button",
		}
		if (not num_menu_items) or menu_items[1].blueprint ~= "group_divider" then
			table.insert(menu_items, 1, {
				label = "divider_open_steam_profile",
				blueprint = "group_divider",
			})
			num_menu_items = num_menu_items + 1
		end
		table.insert(menu_items, 1, entry)
		num_menu_items = num_menu_items + 1
		return menu_items, num_menu_items
	end)
end)
