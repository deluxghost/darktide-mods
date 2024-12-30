local mod = get_mod("OpenPlayerProfile")
local dmf = get_mod("DMF")
local SocialConstants = require("scripts/managers/data_service/services/social/social_constants")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local bigint = mod:io_dofile("OpenPlayerProfile/scripts/mods/OpenPlayerProfile/bigint")

local button_templates = {
	steam = {
		label = "open_steam_profile_button",
		callback_name = "__oppmod_cb_show_steam_profile",
	},
	xbox = {
		label = "open_xbox_profile_button",
		callback_name = "__oppmod_cb_show_xbox_profile",
	}
}

local function hex_to_dec(hex)
	local hex_rev = string.reverse(hex)
	local big = bigint.new(0)
	for i = 1, #hex_rev do
		local char = hex_rev:sub(i, i)
		local digit = tonumber(char, 16)
		if i == 1 then
			big = bigint.add_raw(big, bigint.new(digit))
		else
			big = bigint.add_raw(big,
				bigint.multiply(bigint.new(digit), bigint.exponentiate(bigint.new(16), bigint.new(i - 1))))
		end
	end
	return bigint.unserialize(big, "string")
end

mod.on_all_mods_loaded = function ()
	if mod:get("__open_steam_profile_retired") then
		return
	end
	local OpenSteamProfile = get_mod("OpenSteamProfile")
	if OpenSteamProfile and mod:is_enabled() then
		dmf.set_mod_state(OpenSteamProfile, false, false)
		mod:set("__open_steam_profile_retired", true, false)
	end
end

mod:hook_safe("SocialMenuRosterView", "init", function (self, settings, context)
	self.__oppmod_cb_show_steam_profile = function (self, player_info)
		self:_close_popup_menu()

		local steam_id = hex_to_dec(player_info:platform_user_id())
		if steam_id then
			local profile = "https://steamcommunity.com/profiles/" .. steam_id
			if HAS_STEAM and mod:get("use_steam_overlay") then
				Steam.open_url(profile)
			else
				Application.open_url_in_browser(profile)
			end
		end
	end
	self.__oppmod_cb_show_xbox_profile = function (self, player_info)
		self:_close_popup_menu()

		local xuid = hex_to_dec(player_info:platform_user_id())
		if not xuid then
			return
		end
		Managers.backend:url_request(
			"https://xbox-profile-api.deluxghost.me/profiles/" .. xuid
		):next(function (data)
			if data and data.body and data.body.gamertag then
				local profile = "https://www.xbox.com/play/user/" .. data.body.gamertag
				if HAS_STEAM and mod:get("use_steam_overlay") then
					Steam.open_url(profile)
				else
					Application.open_url_in_browser(profile)
				end
			end
		end):catch(function (e)
			mod:dump(e, "opp_fetch_profile_err", 3)
			mod:notify(mod:localize("msg_get_profile_err"))
		end)
	end
end)

mod:hook_require("scripts/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup_content_list", function (instance)
	mod:hook(instance, "from_player_info", function (func, parent, player_info)
		local menu_items, num_menu_items = func(parent, player_info)
		local social_service = Managers.data_service.social
		local is_xbox = social_service:platform() == SocialConstants.Platforms.xbox
		if player_info:is_own_player() then
			return menu_items, num_menu_items
		end
		local player_platform = player_info:platform()
		if not button_templates[player_platform] then
			return menu_items, num_menu_items
		end
		if is_xbox and player_platform == "xbox" then
			return menu_items, num_menu_items
		end

		local template = table.clone(button_templates[player_platform])
		local entry = {
			label = mod:localize(template.label),
			on_pressed_sound = UISoundEvents.social_menu_see_player_profile,
			callback = callback(parent, template.callback_name, player_info),
			blueprint = "button",
		}
		if (not num_menu_items) or menu_items[1].blueprint ~= "group_divider" then
			table.insert(menu_items, 1, {
				label = "divider_open_player_profile",
				blueprint = "group_divider",
			})
			num_menu_items = num_menu_items + 1
		end
		table.insert(menu_items, 1, entry)
		num_menu_items = num_menu_items + 1
		return menu_items, num_menu_items
	end)
end)
