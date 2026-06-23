local ffi = Mods.lua.ffi

local windows = {}

local CP_UTF8 = 65001

if not pcall(ffi.typeof, "SimpleAudio_WIN32_FIND_DATAW") then
	ffi.cdef([[
		typedef void* SimpleAudio_HANDLE;
		typedef unsigned long SimpleAudio_DWORD;
		typedef int SimpleAudio_BOOL;
		typedef unsigned short SimpleAudio_WCHAR;

		typedef struct {
			SimpleAudio_DWORD dwLowDateTime;
			SimpleAudio_DWORD dwHighDateTime;
		} SimpleAudio_FILETIME;

		typedef struct {
			SimpleAudio_DWORD dwFileAttributes;
			SimpleAudio_FILETIME ftCreationTime;
			SimpleAudio_FILETIME ftLastAccessTime;
			SimpleAudio_FILETIME ftLastWriteTime;
			SimpleAudio_DWORD nFileSizeHigh;
			SimpleAudio_DWORD nFileSizeLow;
			SimpleAudio_DWORD dwReserved0;
			SimpleAudio_DWORD dwReserved1;
			SimpleAudio_WCHAR cFileName[260];
			SimpleAudio_WCHAR cAlternateFileName[14];
		} SimpleAudio_WIN32_FIND_DATAW;

		SimpleAudio_DWORD GetLastError(void);
		int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, SimpleAudio_WCHAR* lpWideCharStr, int cchWideChar);
		int WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const SimpleAudio_WCHAR* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, SimpleAudio_BOOL* lpUsedDefaultChar);
	]])
end

local instances = get_mod("SimpleAudio"):persistent_table("instances")

if instances.kernel32 == nil then
	instances.kernel32 = ffi.load("kernel32")
end

windows.kernel32 = instances.kernel32

windows.path = function(path)
	return path:gsub("/", "\\")
end

windows.last_error = function()
	return tonumber(windows.kernel32.GetLastError())
end

windows.utf8_to_wide = function(text)
	local length = windows.kernel32.MultiByteToWideChar(CP_UTF8, 0, text, -1, nil, 0)

	if length == 0 then
		error(string.format("Failed to convert text to UTF-16: Windows error %d", windows.last_error()))
	end

	local buffer = ffi.new("SimpleAudio_WCHAR[?]", length)
	local result = windows.kernel32.MultiByteToWideChar(CP_UTF8, 0, text, -1, buffer, length)

	if result == 0 then
		error(string.format("Failed to convert text to UTF-16: Windows error %d", windows.last_error()))
	end

	return buffer
end

windows.wide_to_utf8 = function(text)
	local length = windows.kernel32.WideCharToMultiByte(CP_UTF8, 0, text, -1, nil, 0, nil, nil)

	if length == 0 then
		error(string.format("Failed to convert text to UTF-8: Windows error %d", windows.last_error()))
	end

	local buffer = ffi.new("char[?]", length)
	local result = windows.kernel32.WideCharToMultiByte(CP_UTF8, 0, text, -1, buffer, length, nil, nil)

	if result == 0 then
		error(string.format("Failed to convert text to UTF-8: Windows error %d", windows.last_error()))
	end

	return ffi.string(buffer)
end

return windows
