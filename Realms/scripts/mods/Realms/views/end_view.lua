local mod = get_mod("Realms")
local EndView = require("scripts/ui/views/end_view/end_view")

local EndViewPatch = {}

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
