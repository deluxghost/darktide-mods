local mod = get_mod("PsykaniumDefaultDifficulty")
local TrainingGroundsOptionsView = require("scripts/ui/views/training_grounds_options_view/training_grounds_options_view")
local TrainingGroundsView = require("scripts/ui/views/training_grounds_view/training_grounds_view")

mod:hook_safe(TrainingGroundsOptionsView, "_setup_info", function (self)
	local difficulty = mod:get("default_difficulty")
	if difficulty == nil then
		difficulty = 3
	end
	self._widgets_by_name.difficulty_stepper.content.danger = difficulty
end)

mod:hook_safe(TrainingGroundsOptionsView, "on_enter", function (self)
	if mod:get("interact_psykanium_option") >= 3 then
		local play_button = self._widgets_by_name.play_button
		play_button.content.hotspot.pressed_callback()
	end
end)

mod:hook_safe(TrainingGroundsView, "on_enter", function (self)
	if mod:get("interact_psykanium_option") >= 2 then
		local shooting_range_button = self._widgets_by_name.option_button_3
		if shooting_range_button.content.hotspot.disabled then
			return
		end
		shooting_range_button.content.hotspot.pressed_callback()
	end
end)
