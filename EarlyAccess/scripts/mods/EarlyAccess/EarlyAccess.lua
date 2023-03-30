local mod = get_mod("EarlyAccess")
local ConstantElementBetaLabel = require("scripts/ui/constant_elements/elements/beta_label/constant_element_beta_label")

mod:hook(ConstantElementBetaLabel, "draw", function(func, self, dt, t, ui_renderer, render_settings, input_service)
    self._description_text = os.date("Closed Beta Test %B %d %Y")
    self._widgets_by_name.label.content.text = self._description_text or ""
    ConstantElementBetaLabel.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end)
