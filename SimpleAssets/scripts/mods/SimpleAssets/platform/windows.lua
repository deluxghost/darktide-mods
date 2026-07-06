local ffi = Mods.lua.ffi

local windows = {}

local CP_UTF8 = 65001
local FILE_ATTRIBUTE_DIRECTORY = 0x10
local INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF

local function has_file_attribute(attributes, attribute)
	return math.floor(attributes / attribute) % 2 == 1
end

windows.path = function(path)
	local windows_path = path:gsub("/", "\\")

	return windows_path
end

windows.last_error = function(runtime)
	return tonumber(runtime.SimpleAssetsRuntime_GetLastError())
end

windows.utf8_to_wide = function(runtime, text)
	local length = runtime.SimpleAssetsRuntime_MultiByteToWideChar(CP_UTF8, 0, text, -1, nil, 0)

	if length == 0 then
		error(string.format("Failed to convert text to UTF-16: Windows error %d", windows.last_error(runtime)))
	end

	local buffer = ffi.new("SimpleAssets_WCHAR[?]", length)
	local result = runtime.SimpleAssetsRuntime_MultiByteToWideChar(CP_UTF8, 0, text, -1, buffer, length)

	if result == 0 then
		error(string.format("Failed to convert text to UTF-16: Windows error %d", windows.last_error(runtime)))
	end

	return buffer
end

windows.wide_to_utf8 = function(runtime, text)
	local length = runtime.SimpleAssetsRuntime_WideCharToMultiByte(CP_UTF8, 0, text, -1, nil, 0, nil, nil)

	if length == 0 then
		error(string.format("Failed to convert text to UTF-8: Windows error %d", windows.last_error(runtime)))
	end

	local buffer = ffi.new("char[?]", length)
	local result = runtime.SimpleAssetsRuntime_WideCharToMultiByte(CP_UTF8, 0, text, -1, buffer, length, nil, nil)

	if result == 0 then
		error(string.format("Failed to convert text to UTF-8: Windows error %d", windows.last_error(runtime)))
	end

	return ffi.string(buffer)
end

windows.file_attributes = function(runtime, path)
	return tonumber(runtime.SimpleAssetsRuntime_GetFileAttributesW(windows.utf8_to_wide(runtime, windows.path(path))))
end

windows.is_directory = function(runtime, path)
	local attributes = windows.file_attributes(runtime, path)

	return attributes ~= INVALID_FILE_ATTRIBUTES and has_file_attribute(attributes, FILE_ATTRIBUTE_DIRECTORY)
end

return windows
