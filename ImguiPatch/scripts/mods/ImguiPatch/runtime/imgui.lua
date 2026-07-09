local mod = get_mod("ImguiPatch")
local native = mod:io_dofile("ImguiPatch/scripts/mods/ImguiPatch/runtime/native")

local imgui_runtime = {}

local instances = mod:persistent_table("instances")
instances.imgui_patch_runtime = instances.imgui_patch_runtime or {}

local state = instances.imgui_patch_runtime

local TEST_WINDOW_WIDTH = 480
local TEST_WINDOW_HEIGHT = 320
local TEST_GREETING_LINES = {
	"Hello! Czesc! こんにちは!",
	"Hola! 你好! Ola!",
	"Hallo! 안녕하세요! Привет!",
	"Ciao! Bonjour!",
}
local TEST_SYMBOLS = "© ® ™ € £ ¥ ± × ÷ ≤ ≥ ≠ ← → ↑ ↓ ✓ ✕ ★ … • ∞"

local function report_has_status(report, status)
	return string.find(report, "capture_status=" .. status, 1, true) ~= nil
		or string.find(report, "configure_status=" .. status, 1, true) ~= nil
end

local function fail(message, result)
	local error_message = message .. ": " .. tostring(result)
	mod:error(error_message)
	error(error_message)
end

function imgui_runtime.install()
	if not state.capture_installed then
		local ok, result = native.install_text_capture()

		if not ok then
			fail("ImguiPatch text capture install failed", result)
		end

		if not report_has_status(result, "installed") then
			fail("ImguiPatch text capture install returned unexpected status", result)
		end

		state.capture_installed = true
	end

	state.fonts_configured = false
	state.warmup_frames_remaining = nil
	state.imgui_opened = nil
end

local function configure_fonts()
	if state.fonts_configured then
		return true
	end

	local ok, result = native.configure_fonts()

	if not ok then
		fail("ImguiPatch configure fonts failed", result)
	end

	if report_has_status(result, "atlas_locked") then
		return false
	end

	if not report_has_status(result, "applied") then
		fail("ImguiPatch configure fonts returned unexpected status", result)
	end

	state.fonts_configured = true

	return true
end

local function update_capture()
	if not state.capture_installed then
		return
	end

	local ok, result = native.poll_text_capture()

	if not ok then
		fail("ImguiPatch text capture poll failed", result)
	end

	if report_has_status(result, "idle")
		or report_has_status(result, "pending")
		or report_has_status(result, "preparing")
		or report_has_status(result, "atlas_locked") then
		return
	end

	if not report_has_status(result, "applied") then
		fail("ImguiPatch text capture returned unexpected status", result)
	end

end

local function update_test_window()
	if not state.test_window_open then
		return
	end

	Imgui.open_imgui()

	if not state.test_window_initialized then
		Imgui.set_next_window_size(TEST_WINDOW_WIDTH, TEST_WINDOW_HEIGHT)
		state.test_window_initialized = true
	end

	local open, do_close = Imgui.begin_window(mod:localize("test_window_title"))

	if open then
		Imgui.text(mod:localize("test_window_description"))

		for _, line in ipairs(TEST_GREETING_LINES) do
			Imgui.text(line)
		end

		Imgui.text(TEST_SYMBOLS)
		Imgui.push_item_width(-1)
		state.test_input_text = Imgui.input_text("##igpatch_test_input", state.test_input_text or "")
		Imgui.pop_item_width()
	end

	Imgui.end_window()

	if do_close then
		state.test_window_open = false
	end
end

function imgui_runtime.open_test_window()
	state.test_input_text = ""
	state.test_window_open = true
	state.test_window_initialized = false
	Imgui.open_imgui()
end

function imgui_runtime.wants_text_input()
	return native.wants_text_input()
end

function imgui_runtime.update()
	local fonts_configured = configure_fonts()

	if fonts_configured then
		update_capture()
	end

	update_test_window()
end

function imgui_runtime.restore()
	if state.capture_installed then
		local ok, result = native.uninstall_text_capture()

		if not ok then
			fail("ImguiPatch text capture uninstall failed", result)
		end

		if not report_has_status(result, "uninstalled") then
			fail("ImguiPatch text capture uninstall returned unexpected status", result)
		end
	end

	state.capture_installed = false
	state.fonts_configured = false
	state.warmup_frames_remaining = nil
	state.imgui_opened = nil
	state.test_window_open = false
	state.test_window_initialized = false
	native.unload()
end

return imgui_runtime
