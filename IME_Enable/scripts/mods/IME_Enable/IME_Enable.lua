local mod = get_mod("IME_Enable")
local UIWidget = require("scripts/managers/ui/ui_widget")

local status = mod:persistent_table("status")

local function set_ime(value)
	if not mod:is_enabled() then
		return
	end
	value = value or false
	Window.set_ime_enabled(value)
end

mod:hook_safe(UIWidget, "draw", function (widget, ui_renderer)
	local passes = widget.passes
	local content = widget.content
	local writing = false
	for _, pass in ipairs(passes) do
		local content_id = pass.content_id
		local pass_content = content_id and content[content_id] or content
		if pass.style_id and pass.style_id == "input_caret" then
			if content.is_writing or pass_content.is_writing then
				writing = true
			end
		end
	end
	if writing then
		status.is_writing = true
	end
end)

function mod.update(dt)
	set_ime(status.is_writing)
	status.is_writing = false
end
