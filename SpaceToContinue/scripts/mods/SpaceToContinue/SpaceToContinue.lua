local mod = get_mod("SpaceToContinue")
local EndView = require("scripts/ui/views/end_view/end_view")
local EndViewSettings = require("scripts/ui/views/end_view/end_view_settings")
local DefaultViewInputSettings = require("scripts/settings/input/default_view_input_settings")
local TextUtilities = require("scripts/utilities/ui/text")

local _continue_button_action = "next"
local _vote_button_action = EndViewSettings.stay_in_party_vote_button

mod:hook(EndView, "_handle_input", function(func, self, input_service, dt, t)
	if input_service:get(_continue_button_action) then
		self:_trigger_current_presentation_skip()
	end

	if self._stay_in_party_voting_active and input_service:get(_vote_button_action) then
		self:_cb_on_stay_in_party_pressed()
	end

	return EndView.super._handle_input(self, input_service, dt, t)
end)

mod:hook_safe(EndView, "_update_buttons", function(self)
	local service_type = DefaultViewInputSettings.service_type
	local continue_button_widget = self._widgets_by_name.continue_button
	local continue_button_content = continue_button_widget.content
	local continue_button_loc_string = continue_button_content.loc_string
	local can_skip = self._can_skip
	local input_legend_text_template = can_skip and Localize("loc_input_legend_text_template") or nil
	local button_text = TextUtilities.localize_with_button_hint(_continue_button_action, continue_button_loc_string, nil,
		service_type, input_legend_text_template)
	local time = continue_button_content.time

	if time and self._has_shown_summary_view then
		local timer_text = self:_get_timer_text(time)
		button_text = button_text .. " (" .. timer_text .. ")"
	end

	continue_button_content.text = button_text
end)
