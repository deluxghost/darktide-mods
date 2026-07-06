local ffi = Mods.lua.ffi

local windows = {}

local CP_UTF8 = 65001
local FILE_ATTRIBUTE_DIRECTORY = 0x10
local INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF

local function has_file_attribute(attributes, attribute)
	return math.floor(attributes / attribute) % 2 == 1
end

if not pcall(ffi.typeof, "SimpleAssets_WIN32_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } SimpleAssets_WIN32_CDEF;

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

		SimpleAssets_DWORD GetLastError(void);
		SimpleAssets_DWORD GetFileAttributesW(const SimpleAssets_WCHAR* lpFileName);
		int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, SimpleAssets_WCHAR* lpWideCharStr, int cchWideChar);
		int WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const SimpleAssets_WCHAR* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, SimpleAssets_BOOL* lpUsedDefaultChar);
	]])
end

local instances = get_mod("SimpleAssets"):persistent_table("instances")

if instances.kernel32 == nil then
	instances.kernel32 = ffi.load("kernel32")
end

windows.kernel32 = instances.kernel32

windows.path = function(path)
	local windows_path = path:gsub("/", "\\")

	return windows_path
end

windows.last_error = function()
	return tonumber(windows.kernel32.GetLastError())
end

windows.utf8_to_wide = function(text)
	local length = windows.kernel32.MultiByteToWideChar(CP_UTF8, 0, text, -1, nil, 0)

	if length == 0 then
		error(string.format("Failed to convert text to UTF-16: Windows error %d", windows.last_error()))
	end

	local buffer = ffi.new("SimpleAssets_WCHAR[?]", length)
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

windows.file_attributes = function(path)
	return tonumber(windows.kernel32.GetFileAttributesW(windows.utf8_to_wide(windows.path(path))))
end

windows.is_directory = function(path)
	local attributes = windows.file_attributes(path)

	return attributes ~= INVALID_FILE_ATTRIBUTES and has_file_attribute(attributes, FILE_ATTRIBUTE_DIRECTORY)
end

return windows
