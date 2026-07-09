local mod = get_mod("ImguiPatch")
local ffi = Mods.lua.ffi

local native = {}

local RUNTIME_PATH = "../mods/ImguiPatch/bin/darktide-imgui-patch.dll"
local OUTPUT_BUFFER_SIZE = 16384

local instances = mod:persistent_table("instances")
instances.imgui_patch_runtime = instances.imgui_patch_runtime or {}

local state = instances.imgui_patch_runtime

if not pcall(ffi.typeof, "ImguiPatch_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } ImguiPatch_CDEF;

		int ImguiPatch_ConfigureFonts(char* output_buffer, int output_buffer_size);
		int ImguiPatch_InstallTextCapture(char* output_buffer, int output_buffer_size);
		int ImguiPatch_PollTextCapture(char* output_buffer, int output_buffer_size);
		int ImguiPatch_UninstallTextCapture(char* output_buffer, int output_buffer_size);
		int ImguiPatch_WantsTextInput(void);
		const char* ImguiPatch_LastError(void);
	]])
end

local output_buffer = ffi.new("char[?]", OUTPUT_BUFFER_SIZE)

local function runtime_string(pointer)
	if pointer == nil then
		return nil
	end

	local value = ffi.string(pointer)

	if value == "" then
		return nil
	end

	return value
end

local function load_runtime()
	if state.runtime then
		return state.runtime
	end

	local ok, runtime_or_error = pcall(ffi.load, RUNTIME_PATH)

	if not ok then
		return nil, tostring(runtime_or_error)
	end

	state.runtime = runtime_or_error

	return state.runtime
end

local function call_with_output(function_name, error_message)
	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local ok = runtime[function_name](output_buffer, OUTPUT_BUFFER_SIZE)

	if ok == 0 then
		return false, runtime_string(runtime.ImguiPatch_LastError()) or error_message
	end

	return true, ffi.string(output_buffer)
end

native.configure_fonts = function()
	return call_with_output("ImguiPatch_ConfigureFonts", "ImguiPatch configure fonts failed")
end

native.install_text_capture = function()
	return call_with_output("ImguiPatch_InstallTextCapture", "ImguiPatch text capture install failed")
end

native.poll_text_capture = function()
	return call_with_output("ImguiPatch_PollTextCapture", "ImguiPatch text capture poll failed")
end

native.uninstall_text_capture = function()
	return call_with_output("ImguiPatch_UninstallTextCapture", "ImguiPatch text capture uninstall failed")
end

native.wants_text_input = function()
	local runtime = load_runtime()

	if not runtime then
		return false
	end

	return runtime.ImguiPatch_WantsTextInput() ~= 0
end

native.unload = function()
	state.runtime = nil
end

return native
