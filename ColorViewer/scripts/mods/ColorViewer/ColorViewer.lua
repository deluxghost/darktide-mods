local mod = get_mod("ColorViewer")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")

mod.argb_to_hex = function (color)
	local a, r, g, b = color[1], color[2], color[3], color[4]
	return string.format("#%02X%02X%02X%02X", a, r, g, b)
end

mod.argb_to_ahsl = function (color)
	local a, r, g, b = color[1], color[2], color[3], color[4]
	r, g, b = r / 255, g / 255, b / 255

	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, l

	l = (max + min) / 2

	if max == min then
		h, s = 0, 0
	else
		local d = max - min
		if l > 0.5 then
			s = d / (2 - max - min)
		else
			s = d / (max + min)
		end
		if max == r then
			h = (g - b) / d
			if g < b then
				h = h + 6
			end
		elseif max == g then
			h = (b - r) / d + 2
		elseif max == b then
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	return { a or 255, h, s, l }
end

mod.sort_comparator = function (definitions)
	return function (a_item, b_item)
		if a_item and b_item then
			for i = 1, #definitions, 2 do
				local order, func = definitions[i], definitions[i + 1]
				local is_lt = func(a_item, b_item)

				if is_lt ~= nil then
					if order == "<" or order == "true" then
						return is_lt
					else
						return not is_lt
					end
				end
			end
		end

		return nil
	end
end

mod.compare_color_name = function (a, b)
	if a.color_name < b.color_name then
		return true
	elseif b.color_name < a.color_name then
		return false
	end
	return nil
end

mod.compare_color_mono = function (a, b)
	local as = a.color_ahsl[3]
	local bs = b.color_ahsl[3]
	if as == 0 and bs ~= 0 then
		return true
	elseif as ~= 0 and bs == 0 then
		return false
	end
	return nil
end

mod.compare_color_hue = function (a, b)
	local ah, as, al = a.color_ahsl[2], a.color_ahsl[3], a.color_ahsl[4]
	local bh, bs, bl = b.color_ahsl[2], b.color_ahsl[3], b.color_ahsl[4]
	if as == 0 and bs == 0 then
		if al < bl then
			return true
		elseif bl < al then
			return false
		end
		return nil
	end
	if ah < bh then
		return true
	elseif bh < ah then
		return false
	end
	return nil
end

mod.compare_color_saturation = function (a, b)
	local as, al = a.color_ahsl[3], a.color_ahsl[4]
	local bs, bl = b.color_ahsl[3], b.color_ahsl[4]
	if as == 0 and bs == 0 then
		if al < bl then
			return true
		elseif bl < al then
			return false
		end
		return nil
	end
	if as < bs then
		return true
	elseif bs < as then
		return false
	end
	return nil
end

mod.compare_color_lightness = function (a, b)
	local al = a.color_ahsl[4]
	local bl = b.color_ahsl[4]
	if al < bl then
		return true
	elseif bl < al then
		return false
	end
	return nil
end

mod.compare_color_alpha = function (a, b)
	local aa = a.color_ahsl[1]
	local ba = b.color_ahsl[1]
	if aa < ba then
		return true
	elseif ba < aa then
		return false
	end
	return nil
end

mod:add_require_path("ColorViewer/scripts/mods/ColorViewer/color_viewer_view/color_viewer_view")
mod:register_view({
	view_name = "color_viewer_view",
	view_settings = {
		init_view_function = function (ingame_ui_context)
			return true
		end,
		state_bound = true,
		path = "ColorViewer/scripts/mods/ColorViewer/color_viewer_view/color_viewer_view",
		class = "ColorViewerView",
		disable_game_world = false,
		load_always = true,
		load_in_hub = true,
		game_world_blur = 1.1,
		enter_sound_events = {
			UISoundEvents.system_menu_enter,
		},
		exit_sound_events = {
			UISoundEvents.system_menu_exit,
		},
		wwise_states = {
			options = WwiseGameSyncSettings.state_groups.options.ingame_menu,
		},
		context = {
			use_item_categories = false,
		},
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod:command("colorview", mod:localize("cmd_open_color_viewer"), function ()
	if not Managers.ui:view_instance("color_viewer_view") then
		Managers.ui:open_view("color_viewer_view", nil, nil, nil, nil, {})
	end
end)
