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
	if mod:get("auto_select") == "shootingrange_skip" then
		local play_button = self._widgets_by_name.play_button
		play_button.content.hotspot.pressed_callback()
	end
end)

mod:hook_safe(TrainingGroundsView, "on_enter", function (self)
	local auto_select = mod:get("auto_select")
	if auto_select == "horde" then
		local button = self._widgets_by_name.option_button_1
		if button.content.hotspot.disabled then
			return
		end
		button.content.hotspot.pressed_callback()
	elseif auto_select == "shootingrange" or auto_select == "shootingrange_skip" then
		local button = self._widgets_by_name.option_button_4
		if button.content.hotspot.disabled then
			return
		end
		button.content.hotspot.pressed_callback()
	end
end)
