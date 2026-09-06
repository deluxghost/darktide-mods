local mod = get_mod("SoloPlayStratagems")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

local SOUND_MENU_OPEN = "wwise/events/player/play_device_auspex_scanner_minigame_progress_last"
local SOUND_MENU_CLOSE = "wwise/events/player/play_device_auspex_bio_minigame_progress"
local SOUND_INPUT_CORRECT = "wwise/events/ui/play_ui_mastery_trait_unlocked"
local SOUND_INPUT_WRONG = "wwise/events/player/play_device_auspex_bio_minigame_fail"
local SOUND_TRIGGER_SUCCESS = "wwise/events/player/play_device_auspex_bio_minigame_progress_last"

local direction_key_sets = { wasd = {}, arrows = {} }
for key_set_name, key_set in pairs(direction_key_sets) do
	for _, direction in pairs(mod.templates.input_directions) do
		key_set[Keyboard.button_index(direction[key_set_name])] = direction
	end
end

local reading_direction_keys = false

local function _read_key(key_index)
	local previous_reading = reading_direction_keys
	reading_direction_keys = true
	local success, value = pcall(Keyboard.button, key_index)
	reading_direction_keys = previous_reading

	if not success then
		error(value, 0)
	end

	return value
end

local function _selected_direction_keys()
	return direction_key_sets[mod:get("stratagem_direction_keys")]
end

mod.state.visible = mod.state.visible or false
mod.state.sequence = mod.state.sequence or {}
mod.state.direction_key_down = mod.state.direction_key_down or {}
mod.state.pending_stratagem_name = mod.state.pending_stratagem_name or nil
mod.state.pending_key_index = mod.state.pending_key_index or nil
mod.state.active_stratagems = mod.state.active_stratagems or nil

local function _clear_sequence()
	table.clear(mod.state.sequence)
end

local function _clear_pending_match()
	mod.state.pending_stratagem_name = nil
	mod.state.pending_key_index = nil
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
	if not mod.is_local_game() or _is_stratagem_menu_blocked() then
		return false
	end

	local player = Managers.player:local_player(1)
	local player_unit = player and player.player_unit
	if not player_unit or not HEALTH_ALIVE[player_unit] then
		return false
	end

	local unit_data_extension = ScriptUnit.extension(player_unit, "unit_data_system")
	local character_state = unit_data_extension:read_component("character_state")
	return not PlayerUnitStatus.is_disabled(character_state) and not PlayerUnitStatus.is_stunned(character_state)
end

local function _keybind_is_down(setting_id)
	local keys = mod:get(setting_id)
	if type(keys) ~= "table" then
		return false
	end

	for i = 1, #keys do
		local key = keys[i]
		local button_index = key and Keyboard.button_index(key)
		if button_index and _read_key(button_index) > 0 then
			return true
		end
	end
	return false
end

local function _is_hold_mode()
	return mod:get("stratagem_menu_hold_mode") == true
end

local function _set_pending_match(stratagem_name, key_index)
	mod.state.pending_stratagem_name = stratagem_name
	mod.state.pending_key_index = key_index
end

local function _has_pending_match()
	return mod.state.pending_stratagem_name ~= nil and mod.state.pending_key_index ~= nil
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

local function _append_direction(key_index, symbol)
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
		_set_pending_match(matched_stratagem_name, key_index)
	end
end

local function _can_trigger_pending_match(key_index)
	return mod.state.pending_key_index == key_index and _has_pending_match() and mod.state.visible and (not _is_hold_mode() or _keybind_is_down("stratagem_menu_keybind"))
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

local function _handle_direction(key_index, value, direction)
	local is_down = value and value > 0
	local was_down = mod.state.direction_key_down[key_index] == true
	mod.state.direction_key_down[key_index] = is_down and true or false

	if not mod.stratagem_menu_visible() then
		return
	end

	if is_down and not was_down then
		_append_direction(key_index, direction.internal)
	elseif not is_down and was_down and _can_trigger_pending_match(key_index) then
		local triggered = mod.trigger_stratagem(mod.state.pending_stratagem_name)
		if triggered then
			mod.stratagem_menu_set_visible(false, SOUND_TRIGGER_SUCCESS)
		else
			mod.stratagem_menu_set_visible(false)
		end
	end
end

mod.stratagem_menu_update = function ()
	for key_index, direction in pairs(_selected_direction_keys()) do
		_handle_direction(key_index, _read_key(key_index), direction)
	end

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

mod.on_setting_changed = function (setting_id)
	if setting_id ~= "stratagem_direction_keys" then
		return
	end

	_clear_sequence()
	_clear_pending_match()
	table.clear(mod.state.direction_key_down)
	for key_index in pairs(_selected_direction_keys()) do
		mod.state.direction_key_down[key_index] = _read_key(key_index) > 0
	end
end

local function _blocks_key(key_index)
	return not reading_direction_keys
		and mod.state.visible
		and _selected_direction_keys()[key_index] ~= nil
		and mod.stratagem_menu_visible()
end

mod:hook(Keyboard, "button", function (func, key_index)
	if _blocks_key(key_index) then
		return 0
	end

	return func(key_index)
end)

local function _filter_key_event(func, key_index)
	if _blocks_key(key_index) then
		return false
	end

	return func(key_index)
end

mod:hook(Keyboard, "pressed", _filter_key_event)
mod:hook(Keyboard, "released", _filter_key_event)
