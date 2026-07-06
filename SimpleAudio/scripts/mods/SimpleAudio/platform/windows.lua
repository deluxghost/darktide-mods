local ffi = Mods.lua.ffi

local windows = {}

local CP_UTF8 = 65001

windows.path = function(path)
	return path:gsub("/", "\\")
end

windows.last_error = function(runtime)
	return tonumber(runtime.SimpleAudioRuntime_GetLastError())
end

windows.utf8_to_wide = function(runtime, text)
	local length = runtime.SimpleAudioRuntime_MultiByteToWideChar(CP_UTF8, 0, text, -1, nil, 0)

	if length == 0 then
		error(string.format("Failed to convert text to UTF-16: Windows error %d", windows.last_error(runtime)))
	end

	local buffer = ffi.new("SimpleAudio_WCHAR[?]", length)
	local result = runtime.SimpleAudioRuntime_MultiByteToWideChar(CP_UTF8, 0, text, -1, buffer, length)

	if result == 0 then
		error(string.format("Failed to convert text to UTF-16: Windows error %d", windows.last_error(runtime)))
	end

	return buffer
end

windows.wide_to_utf8 = function(runtime, text)
	local length = runtime.SimpleAudioRuntime_WideCharToMultiByte(CP_UTF8, 0, text, -1, nil, 0, nil, nil)

	if length == 0 then
		error(string.format("Failed to convert text to UTF-8: Windows error %d", windows.last_error(runtime)))
	end

	local buffer = ffi.new("char[?]", length)
	local result = runtime.SimpleAudioRuntime_WideCharToMultiByte(CP_UTF8, 0, text, -1, buffer, length, nil, nil)

	if result == 0 then
		error(string.format("Failed to convert text to UTF-8: Windows error %d", windows.last_error(runtime)))
	end

	return ffi.string(buffer)
end

return windows
