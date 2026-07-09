local mod = get_mod("ImguiPatch")

local imgui_runtime = mod:io_dofile("ImguiPatch/scripts/mods/ImguiPatch/runtime/imgui")

imgui_runtime.install()

mod.wants_text_input = function()
	return imgui_runtime.wants_text_input()
end

mod:command("igpatch", mod:localize("command_description"), function (action)
	if action == "test" then
		imgui_runtime.open_test_window()
	end
end)

mod.update = function(dt)
	imgui_runtime.update(dt)
end

mod.on_unload = function()
	imgui_runtime.restore()
end
