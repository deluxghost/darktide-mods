local mod = get_mod("IME_Enable")

local ime_status = mod:persistent_table("ime_status")

local function set_ime(value)
	if not mod:is_enabled() then
		return
	end
	ime_status.status = ime_status.status or false
	value = value or false
	if ime_status.status ~= value then
		ime_status.status = value
		Window.set_ime_enabled(value)
	end
end

local function _visibility_function_intercept(content, style)
	set_ime(content.is_writing)
	return content.is_writing
end

-- handle chatbox
mod:hook("ConstantElementChat", "_handle_input", function(func, self, ...)
	set_ime(self._input_field_widget.content.is_writing)
	return func(self, ...)
end)

-- handle character name box and modded input fields
mod:hook_require("scripts/ui/pass_templates/text_input_pass_templates", function(instance)
	for _, input in pairs(instance) do
		for _, pass in ipairs(input) do
			if pass.style_id and pass.style_id == "input_caret" then
				pass.visibility_function = _visibility_function_intercept
			end
		end
	end
end)

