local mod = get_mod("PsykaniumDefaultDifficulty")
local TrainingGroundsOptionsView = require("scripts/ui/views/training_grounds_options_view/training_grounds_options_view")

mod:hook_safe(TrainingGroundsOptionsView, "_setup_info", function(self)
    local difficulty = mod:get("default_difficulty")
    if difficulty == nil then
        difficulty = 3
    end
    self._widgets_by_name.difficulty_stepper.content.danger = difficulty
end)
