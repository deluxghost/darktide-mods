local mod = get_mod("ImguiPatch")
local ffi = Mods.lua.ffi

local native = {}

local RUNTIME_PATH = "../mods/ImguiPatch/bin/darktide-imgui-patch.dll"
local instances = mod:persistent_table("instances")
instances.imgui_patch_runtime = instances.imgui_patch_runtime or {}

local state = instances.imgui_patch_runtime

if not pcall(ffi.typeof, "ImguiPatch_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } ImguiPatch_CDEF;

		int ImguiPatch_ConfigureFonts(void);
		int ImguiPatch_InstallTextCapture(void);
		int ImguiPatch_PollTextCapture(void);
		int ImguiPatch_UninstallTextCapture(void);
		int ImguiPatch_WantsTextInput(void);
		const char* ImguiPatch_LastError(void);
	]])
end

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

local function call_boolean(function_name, error_message)
	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local ok = runtime[function_name]()

	if ok == 0 then
		return false, runtime_string(runtime.ImguiPatch_LastError()) or error_message
	end

	return true
end

native.configure_fonts = function()
	local runtime, load_error = load_runtime()

	if not runtime then
		return nil, load_error
	end

	local status = runtime.ImguiPatch_ConfigureFonts()

	if status < 0 then
		return nil, runtime_string(runtime.ImguiPatch_LastError()) or "ImguiPatch configure fonts failed"
	end

	return status
end

native.install_text_capture = function()
	return call_boolean("ImguiPatch_InstallTextCapture", "ImguiPatch text capture install failed")
end

native.poll_text_capture = function()
	local runtime, load_error = load_runtime()

	if not runtime then
		return nil, load_error
	end

	local status = runtime.ImguiPatch_PollTextCapture()

	if status < 0 then
		return nil, runtime_string(runtime.ImguiPatch_LastError()) or "ImguiPatch text capture poll failed"
	end

	return status
end

native.uninstall_text_capture = function()
	return call_boolean("ImguiPatch_UninstallTextCapture", "ImguiPatch text capture uninstall failed")
end

native.CONFIGURE_ATLAS_LOCKED = 0
native.CONFIGURE_APPLIED = 1
native.CAPTURE_IDLE = 0
native.CAPTURE_PENDING = 1
native.CAPTURE_PREPARING = 2
native.CAPTURE_ATLAS_LOCKED = 3
native.CAPTURE_APPLIED = 4
native.CAPTURE_NOT_INSTALLED = 5

native.wants_text_input = function()
	local runtime = load_runtime()

	if not runtime then
		return false
	end

	return runtime.ImguiPatch_WantsTextInput() ~= 0
end

return native
