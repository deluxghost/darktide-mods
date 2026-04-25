local mod = get_mod("SoloPlayStratagems")

local SOUND_MENU_OPEN = "wwise/events/player/play_device_auspex_scanner_minigame_progress_last"
local SOUND_MENU_CLOSE = "wwise/events/player/play_device_auspex_bio_minigame_progress"
local SOUND_INPUT_CORRECT = "wwise/events/ui/play_ui_mastery_trait_unlocked"
local SOUND_INPUT_WRONG = "wwise/events/player/play_device_auspex_bio_minigame_fail"
local SOUND_TRIGGER_SUCCESS = "wwise/events/player/play_device_auspex_bio_minigame_progress_last"

mod.state.visible = mod.state.visible or false
mod.state.sequence = mod.state.sequence or {}
mod.state.direction_key_down = mod.state.direction_key_down or {}
mod.state.pending_stratagem_name = mod.state.pending_stratagem_name or nil
mod.state.pending_action_name = mod.state.pending_action_name or nil
mod.state.active_stratagems = mod.state.active_stratagems or nil

local function _clear_sequence()
	table.clear(mod.state.sequence)
end

local function _clear_pending_match()
	mod.state.pending_stratagem_name = nil
	mod.state.pending_action_name = nil
end

mod.stratagem_menu_set_visible = function (visible, close_sound_event)
	if mod.state.visible == visible then
		return
	end

	mod.state.visible = visible
	if visible then
		mod.refresh_active_stratagems()
		mod.play_sound(SOUND_MENU_OPEN)
	else
		_clear_pending_match()
		_clear_sequence()
		mod.play_sound(close_sound_event or SOUND_MENU_CLOSE)
	end
end

local function _is_stratagem_menu_blocked()
	local ui_manager = Managers.ui
	if not ui_manager then
		return false
	end

	if ui_manager:has_active_view() then
		return true
	end
	if ui_manager:handling_popups() then
		return true
	end
	if ui_manager:chat_using_input() then
		return true
	end
	return false
end

local function _can_use_stratagem_menu()
	return mod.is_local_game() and not _is_stratagem_menu_blocked()
end

local function _keybind_is_down(setting_id)
	local keys = mod:get(setting_id)
	if type(keys) ~= "table" then
		return false
	end

	for i = 1, #keys do
		local key = keys[i]
		local button_index = key and Keyboard.button_index(key)
		if button_index and Keyboard.button(button_index) > 0 then
			return true
		end
	end
	return false
end

local function _is_hold_mode()
	return mod:get("stratagem_menu_hold_mode") == true
end

local function _set_pending_match(stratagem_name, action_name)
	mod.state.pending_stratagem_name = stratagem_name
	mod.state.pending_action_name = action_name
end

local function _has_pending_match()
	return mod.state.pending_stratagem_name ~= nil and mod.state.pending_action_name ~= nil
end

local function _match_sequence(sequence)
	local stratagems = mod.get_active_stratagems()
	local has_prefix = false
	for _, template in ipairs(stratagems) do
		local pattern = template.input_sequence
		if #sequence <= #pattern then
			local matched = true
			for i = 1, #sequence do
				if sequence[i] ~= pattern[i] then
					matched = false
					break
				end
			end

			if matched then
				has_prefix = true
				if #sequence == #pattern then
					return template.pocketable, true
				end
			end
		end
	end
	return nil, has_prefix
end

local function _append_direction(action_name, symbol)
	if _has_pending_match() then
		return
	end

	local next_sequence = table.clone(mod.state.sequence)
	next_sequence[#next_sequence + 1] = symbol

	local matched_stratagem_name, has_prefix = _match_sequence(next_sequence)
	if matched_stratagem_name or has_prefix then
		mod.state.sequence[#mod.state.sequence + 1] = symbol
		mod.play_sound(SOUND_INPUT_CORRECT)
	else
		_clear_sequence()
		mod.play_sound(SOUND_INPUT_WRONG)
	end

	if matched_stratagem_name then
		_set_pending_match(matched_stratagem_name, action_name)
	end
end

local function _can_trigger_pending_match(action_name)
	return mod.state.pending_action_name == action_name and _has_pending_match() and mod.state.visible and (not _is_hold_mode() or _keybind_is_down("stratagem_menu_keybind"))
end

mod.keybind_stratagem_menu = function ()
	if not _can_use_stratagem_menu() then
		return
	end

	if _is_hold_mode() then
		mod.stratagem_menu_set_visible(true)
	else
		mod.stratagem_menu_set_visible(not mod.state.visible)
	end
end

mod.stratagem_menu_visible = function ()
	return mod.state.visible and _can_use_stratagem_menu()
end

mod.stratagem_menu_update = function ()
	if not _can_use_stratagem_menu() then
		if mod.state.visible then
			mod.stratagem_menu_set_visible(false)
		end
		return
	end

	if _is_hold_mode() and mod.state.visible and not _keybind_is_down("stratagem_menu_keybind") then
		mod.stratagem_menu_set_visible(false)
	end
end

local function _handle_stratagem_direction_action(func, self, action_name)
	local value = func(self, action_name)
	local direction = mod.templates.input_directions_by_action[action_name]

	if self.type == "Ingame" and direction then
		local is_down = value and value > 0
		local was_down = mod.state.direction_key_down[action_name] == true
		mod.state.direction_key_down[action_name] = is_down and true or false

		if not mod.stratagem_menu_visible() then
			return value
		end

		if is_down and not was_down then
			_append_direction(action_name, direction.internal)
		elseif not is_down and was_down and _can_trigger_pending_match(action_name) then
			local triggered = mod.trigger_stratagem(mod.state.pending_stratagem_name)
			if triggered then
				mod.stratagem_menu_set_visible(false, SOUND_TRIGGER_SUCCESS)
			else
				mod.stratagem_menu_set_visible(false)
			end
		end

		return self:get_default(action_name)
	end
	return value
end

mod:hook("InputService", "_get", _handle_stratagem_direction_action)
mod:hook("InputService", "_get_simulate", _handle_stratagem_direction_action)
