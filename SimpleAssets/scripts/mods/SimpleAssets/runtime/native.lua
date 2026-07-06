local mod = get_mod("SimpleAssets")
local ffi = Mods.lua.ffi

local windows = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/platform/windows")

local native = {}

local RUNTIME_PATH = "../mods/SimpleAssets/bin/simple-assets-runtime.dll"

local instances = mod:persistent_table("instances")
instances.simple_assets_runtime = instances.simple_assets_runtime or {}

local state = instances.simple_assets_runtime

if not pcall(ffi.typeof, "SimpleAssetsRuntime_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } SimpleAssetsRuntime_CDEF;
		typedef void* SimpleAssets_HANDLE;
		typedef unsigned long SimpleAssets_DWORD;
		typedef int SimpleAssets_BOOL;
		typedef unsigned short SimpleAssets_WCHAR;

		typedef struct {
			SimpleAssets_DWORD dwLowDateTime;
			SimpleAssets_DWORD dwHighDateTime;
		} SimpleAssets_FILETIME;

		typedef struct {
			SimpleAssets_DWORD dwFileAttributes;
			SimpleAssets_FILETIME ftCreationTime;
			SimpleAssets_FILETIME ftLastAccessTime;
			SimpleAssets_FILETIME ftLastWriteTime;
			SimpleAssets_DWORD nFileSizeHigh;
			SimpleAssets_DWORD nFileSizeLow;
			SimpleAssets_DWORD dwReserved0;
			SimpleAssets_DWORD dwReserved1;
			SimpleAssets_WCHAR cFileName[260];
			SimpleAssets_WCHAR cAlternateFileName[14];
		} SimpleAssets_WIN32_FIND_DATAW;

		int SimpleAssetsRuntime_Start(void);
		const char* SimpleAssetsRuntime_GameDir(void);
		const char* SimpleAssetsRuntime_UserDir(void);
		const char* SimpleAssetsRuntime_ListenInfo(void);
		const char* SimpleAssetsRuntime_AssetUrl(const char* path);
		const char* SimpleAssetsRuntime_LastError(void);
		void SimpleAssetsRuntime_Shutdown(void);
		SimpleAssets_DWORD SimpleAssetsRuntime_GetLastError(void);
		SimpleAssets_DWORD SimpleAssetsRuntime_GetFileAttributesW(const SimpleAssets_WCHAR* lpFileName);
		int SimpleAssetsRuntime_MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, SimpleAssets_WCHAR* lpWideCharStr, int cchWideChar);
		int SimpleAssetsRuntime_WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const SimpleAssets_WCHAR* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, SimpleAssets_BOOL* lpUsedDefaultChar);
		SimpleAssets_HANDLE SimpleAssetsRuntime_FindFirstFileW(const SimpleAssets_WCHAR* lpFileName, SimpleAssets_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAssets_BOOL SimpleAssetsRuntime_FindNextFileW(SimpleAssets_HANDLE hFindFile, SimpleAssets_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAssets_BOOL SimpleAssetsRuntime_FindClose(SimpleAssets_HANDLE hFindFile);
	]])
end

local function load_runtime()
	if state.runtime then
		return state.runtime
	end

	local ok, runtime_or_error = pcall(ffi.load, windows.path(RUNTIME_PATH))

	if not ok then
		return nil, tostring(runtime_or_error)
	end

	state.runtime = runtime_or_error

	return state.runtime
end

native.runtime = load_runtime

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

local function runtime_or_error()
	local runtime = state.runtime

	if not runtime then
		error("SimpleAssets runtime is not initialized")
	end

	return runtime
end

native.initialize = function()
	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local ok = runtime.SimpleAssetsRuntime_Start()

	if ok == 0 then
		return false, runtime_string(runtime.SimpleAssetsRuntime_LastError()) or "SimpleAssets runtime failed to start"
	end

	local listen_info = runtime_string(runtime.SimpleAssetsRuntime_ListenInfo())

	if not listen_info then
		return false, "SimpleAssets runtime did not return listening information"
	end

	state.listen_info = listen_info
	state.game_dir = runtime_string(runtime.SimpleAssetsRuntime_GameDir())
	state.user_dir = runtime_string(runtime.SimpleAssetsRuntime_UserDir())

	return true
end

native.game_dir = function()
	if state.game_dir then
		return state.game_dir
	end

	local runtime = runtime_or_error()
	local game_dir = runtime_string(runtime.SimpleAssetsRuntime_GameDir())

	if not game_dir then
		error("SimpleAssets runtime did not return game directory")
	end

	state.game_dir = game_dir

	return game_dir
end

native.user_dir = function()
	if state.user_dir then
		return state.user_dir
	end

	local runtime = runtime_or_error()
	local user_dir = runtime_string(runtime.SimpleAssetsRuntime_UserDir())

	if not user_dir then
		error("SimpleAssets runtime did not return user directory")
	end

	state.user_dir = user_dir

	return user_dir
end

native.listen_info = function()
	if state.listen_info then
		return state.listen_info
	end

	local runtime = runtime_or_error()

	local listen_info = runtime_string(runtime.SimpleAssetsRuntime_ListenInfo())

	if not listen_info then
		error("SimpleAssets runtime did not return listening information")
	end

	state.listen_info = listen_info

	return listen_info
end

native.asset_url = function(path)
	local runtime = runtime_or_error()

	local asset_url = runtime_string(runtime.SimpleAssetsRuntime_AssetUrl(windows.path(path)))

	if not asset_url then
		error(runtime_string(runtime.SimpleAssetsRuntime_LastError()) or "SimpleAssets runtime failed to generate asset URL")
	end

	return asset_url
end

native.shutdown = function()
	local runtime = state.runtime

	if runtime then
		runtime.SimpleAssetsRuntime_Shutdown()
	end

	state.listen_info = nil
	state.game_dir = nil
	state.user_dir = nil
	state.runtime = nil
end

return native
