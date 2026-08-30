local mod = get_mod("Realms")
local SystemView = require("scripts/ui/views/system_view/system_view")

local REALMS_OWNER = "_realms_system_menu_owner"
local SOCIAL_TEXT = "loc_social_view_display_name"
local SystemMenu = {}
local missing_canonical_logged = false
local missing_social_logged = false

local function is_training_grounds()
	local game_mode_manager = Managers.state and Managers.state.game_mode

	if not game_mode_manager then
		return false
	end

	local game_mode_name = game_mode_manager:game_mode_name()

	return game_mode_name == "training_grounds" or game_mode_name == "shooting_range"
end

local function show_leave_mission_popup(Session)
	local context = {
		description_text = "loc_popup_description_leave_mission",
		title_text = "loc_popup_header_leave_mission",
		options = {
			{
				close_on_pressed = true,
				text = "loc_popup_button_leave_mission",
				callback = function ()
					Session.leave()
				end,
			},
			{
				close_on_pressed = true,
				hotkey = "back",
				template_type = "terminal_button_small",
				text = "loc_popup_button_leave_continue_mission",
			},
		},
	}

	Managers.event:trigger("event_show_ui_popup", context)
end

local function show_leave_training_grounds_popup(Session)
	local context = {
		description_text = "loc_popup_description_leave_psykhanium",
		title_text = "loc_tg_exit_training_grounds",
		options = {
			{
				close_on_pressed = true,
				text = "loc_training_grounds_choice_quit",
				callback = function ()
					Session.leave()
				end,
			},
			{
				close_on_pressed = true,
				hotkey = "back",
				template_type = "terminal_button_small",
				text = "loc_popup_button_leave_continue_mission",
			},
		},
	}

	Managers.event:trigger("event_show_ui_popup", context)
end

local function transform_standard_leave(entry, leave_index, use_training_leave, Session)
	if entry[REALMS_OWNER] then
		return entry
	end

	entry = table.clone(entry)
	entry[REALMS_OWNER] = true
	entry.validation_function = function ()
		return leave_index == 1 and not use_training_leave
	end
	if leave_index == 1 then
		entry.trigger_function = function ()
			show_leave_mission_popup(Session)
		end
	end

	return entry
end

local function transform_training_leave(entry, use_training_leave, Session)
	if entry[REALMS_OWNER] then
		return entry
	end

	entry = table.clone(entry)
	entry[REALMS_OWNER] = true
	entry.validation_function = function ()
		return use_training_leave
	end
	entry.trigger_function = function ()
		show_leave_training_grounds_popup(Session)
	end

	return entry
end

local function transform_social(entry)
	entry = table.clone(entry)
	entry.validation_function = nil

	return entry
end

local function canonical_leave_entries(source)
	local standard_leave
	local training_leave

	for i = 1, #source do
		local entry = source[i]

		if entry.text == "loc_leave_mission_display_name" and not standard_leave then
			standard_leave = entry
		elseif entry.text == "loc_tg_exit_training_grounds" then
			training_leave = entry
		end
	end

	if (not standard_leave or not training_leave) and not missing_canonical_logged then
		missing_canonical_logged = true
		mod:error("The active system-menu definition has no canonical leave entries")
	end

	return standard_leave, training_leave
end

local function canonical_entry(source, text)
	for i = 1, #source do
		if source[i].text == text then
			return source[i]
		end
	end
end

local function insert_into_large_button_group(list, entry)
	local insert_index = #list + 1
	local found_large_button = false

	for i = 1, #list do
		if list[i].type == "large_button" then
			found_large_button = true
		elseif found_large_button then
			insert_index = i

			break
		end
	end

	table.insert(list, insert_index, entry)
end

local function transform_list(source, canonical_default, Preparation, Session)
	local transformed = {}
	local standard_leave_count = 0
	local training_leave_found = false
	local social_found = false
	local use_training_leave = not Preparation.is_waiting() and is_training_grounds()
	local canonical_standard_leave, canonical_training_leave = canonical_leave_entries(canonical_default)

	for i = 1, #source do
		local entry = source[i]

		if entry.text == "loc_leave_mission_display_name" then
			standard_leave_count = standard_leave_count + 1
			entry = transform_standard_leave(entry, standard_leave_count, use_training_leave, Session)
		elseif entry.text == "loc_tg_exit_training_grounds" then
			training_leave_found = true
			entry = transform_training_leave(entry, use_training_leave, Session)
		end
		if entry.text == SOCIAL_TEXT then
			social_found = true

			if Preparation.is_waiting() then
				entry = transform_social(entry)
			end
		end

		transformed[i] = entry
	end

	if standard_leave_count == 0 and canonical_standard_leave then
		transformed[#transformed + 1] = transform_standard_leave(canonical_standard_leave, 1, use_training_leave, Session)
	end
	if not training_leave_found and canonical_training_leave then
		transformed[#transformed + 1] = transform_training_leave(canonical_training_leave, use_training_leave, Session)
	end
	if Preparation.is_waiting() and not social_found then
		local social_entry = canonical_entry(canonical_default, SOCIAL_TEXT)

		if social_entry then
			insert_into_large_button_group(transformed, transform_social(social_entry))
		elseif not missing_social_logged then
			missing_social_logged = true
			mod:error("The active system-menu definition has no canonical social entry")
		end
	end

	return transformed
end

function SystemMenu.install(Preparation, Session)
	mod:hook(SystemView, "_setup_content_widgets", function (func, self, content, scenegraph_id, callback_name)
		if not Session.is_active() or not content or not content.default then
			return func(self, content, scenegraph_id, callback_name)
		end

		local current_state_name = Managers.ui:get_current_state_name()
		local selected_key = current_state_name and content[current_state_name] and current_state_name or "default"
		local transformed_content = table.clone(content)

		transformed_content[selected_key] = transform_list(content[selected_key], content.default, Preparation, Session)

		return func(self, transformed_content, scenegraph_id, callback_name)
	end)
end

return SystemMenu
