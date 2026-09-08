local mod = get_mod("Realms")
local EndView = require("scripts/ui/views/end_view/end_view")
local ProgressionManager = require("scripts/managers/progression/progression_manager")

local EndViewPatch = {}
local UNLIMITED_END_TIME = math.huge

local function hide_stay_in_party_vote(view)
	view._realms_hide_stay_in_party_vote = true
	view._stay_in_party_voting_active = false
	view._stay_in_party_voting_id = nil

	local widget = view._widgets_by_name.stay_in_party_vote

	widget.visible = false
	widget.alpha_multiplier = 0
	widget.content.hotspot.disabled = true
	widget.content.hotspot.pressed_callback = nil
end

function EndViewPatch.install(Session)
	mod:hook(ProgressionManager, "game_score_end_time", function (func, self)
		local end_time = func(self)

		if end_time and Session.is_active() then
			-- Both StateGameScore and EndView read this deadline. EndView also needs
			-- a truthy value to finish waiting; keep the stored/networked timestamp unchanged.
			return UNLIMITED_END_TIME
		end

		return end_time
	end)

	mod:hook(EndView, "_update_continue_button_time", function (func, self, end_time, server_time)
		if end_time == UNLIMITED_END_TIME then
			end_time = nil
		end

		return func(self, end_time, server_time)
	end)

	mod:hook(EndView, "_setup_stay_in_party_vote", function (func, self)
		if not Session.is_active() then
			return func(self)
		end

		hide_stay_in_party_vote(self)
	end)

	mod:hook(EndView, "_update_voting_button_visibility", function (func, self, dt)
		if not self._realms_hide_stay_in_party_vote then
			return func(self, dt)
		end

		hide_stay_in_party_vote(self)
	end)

	mod:hook(EndView, "_cb_on_stay_in_party_pressed", function (func, self)
		if self._realms_hide_stay_in_party_vote then
			return
		end

		return func(self)
	end)
end

return EndViewPatch
