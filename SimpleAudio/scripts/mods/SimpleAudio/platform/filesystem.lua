local mod = get_mod("SimpleAudio")
local ffi = Mods.lua.ffi

local windows = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/platform/windows")

local filesystem = {}

local ERROR_FILE_NOT_FOUND = 2
local ERROR_PATH_NOT_FOUND = 3
local ERROR_NO_MORE_FILES = 18
local ERROR_ALREADY_EXISTS = 183
local FILE_ATTRIBUTE_DIRECTORY = 0x10
local FILE_ATTRIBUTE_NORMAL = 0x80
local FILE_BEGIN = 0
local GENERIC_READ = 0x80000000
local GENERIC_WRITE = 0x40000000
local FILE_SHARE_READ = 0x00000001
local CREATE_ALWAYS = 2
local OPEN_EXISTING = 3

if not pcall(ffi.typeof, "SimpleAudio_FILESYSTEM_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } SimpleAudio_FILESYSTEM_CDEF;

		SimpleAudio_BOOL CloseHandle(SimpleAudio_HANDLE hObject);
		SimpleAudio_HANDLE CreateFileW(const SimpleAudio_WCHAR* lpFileName, SimpleAudio_DWORD dwDesiredAccess, SimpleAudio_DWORD dwShareMode, void* lpSecurityAttributes, SimpleAudio_DWORD dwCreationDisposition, SimpleAudio_DWORD dwFlagsAndAttributes, SimpleAudio_HANDLE hTemplateFile);
		SimpleAudio_BOOL CreateDirectoryW(const SimpleAudio_WCHAR* lpPathName, void* lpSecurityAttributes);
		SimpleAudio_BOOL DeleteFileW(const SimpleAudio_WCHAR* lpFileName);
		SimpleAudio_HANDLE FindFirstFileW(const SimpleAudio_WCHAR* lpFileName, SimpleAudio_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAudio_BOOL FindNextFileW(SimpleAudio_HANDLE hFindFile, SimpleAudio_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAudio_BOOL FindClose(SimpleAudio_HANDLE hFindFile);
		SimpleAudio_DWORD GetTempPathW(SimpleAudio_DWORD nBufferLength, SimpleAudio_WCHAR* lpBuffer);
		SimpleAudio_BOOL ReadFile(SimpleAudio_HANDLE hFile, void* lpBuffer, SimpleAudio_DWORD nNumberOfBytesToRead, SimpleAudio_DWORD* lpNumberOfBytesRead, void* lpOverlapped);
		SimpleAudio_BOOL SetFilePointerEx(SimpleAudio_HANDLE hFile, long long liDistanceToMove, long long* lpNewFilePointer, SimpleAudio_DWORD dwMoveMethod);
		SimpleAudio_BOOL WriteFile(SimpleAudio_HANDLE hFile, const void* lpBuffer, SimpleAudio_DWORD nNumberOfBytesToWrite, SimpleAudio_DWORD* lpNumberOfBytesWritten, void* lpOverlapped);
	]])
end

local INVALID_HANDLE_VALUE = ffi.cast("SimpleAudio_HANDLE", -1)

local function has_file_attribute(attributes, attribute)
	return math.floor(attributes / attribute) % 2 == 1
end

local function join_path(base_path, path)
	if base_path == "" then
		return path
	end
	if path == "" then
		return base_path
	end
	if base_path:sub(-1) == "/" or base_path:sub(-1) == "\\" then
		return base_path .. path
	end

	return base_path .. "/" .. path
end

local function split_search_pattern(search_pattern)
	local first_pattern = search_pattern:find("[*?]")
	local search_end = first_pattern and first_pattern - 1 or #search_pattern
	local prefix_end = 0

	for i = search_end, 1, -1 do
		local char = search_pattern:sub(i, i)

		if char == "/" or char == "\\" then
			prefix_end = i
			break
		end
	end

	return search_pattern:sub(1, prefix_end), search_pattern:sub(prefix_end + 1)
end

local function split_segments(path)
	local segments = {}

	for segment in path:gmatch("[^/\\]+") do
		segments[#segments + 1] = segment
	end

	return segments
end

local function find_entries(search_pattern)
	local find_data = ffi.new("SimpleAudio_WIN32_FIND_DATAW[1]")
	local handle = windows.kernel32.FindFirstFileW(windows.utf8_to_wide(windows.path(search_pattern)), find_data)

	if handle == INVALID_HANDLE_VALUE then
		local last_error = windows.last_error()

		if last_error == ERROR_FILE_NOT_FOUND or last_error == ERROR_PATH_NOT_FOUND then
			return nil
		end

		error(string.format("Failed to glob audio files for %s: Windows error %d", search_pattern, last_error))
	end

	local entries = {}
	local last_error

	while true do
		local attributes = tonumber(find_data[0].dwFileAttributes)
		local name = windows.wide_to_utf8(find_data[0].cFileName)

		if name ~= "." and name ~= ".." then
			entries[#entries + 1] = {
				is_directory = has_file_attribute(attributes, FILE_ATTRIBUTE_DIRECTORY),
				name = name,
			}
		end

		if windows.kernel32.FindNextFileW(handle, find_data) == 0 then
			last_error = windows.last_error()
			break
		end
	end

	if windows.kernel32.FindClose(handle) == 0 then
		error(string.format("Failed to close audio glob handle: Windows error %d", windows.last_error()))
	end

	if last_error ~= ERROR_NO_MORE_FILES then
		error(string.format("Failed to glob audio files for %s: Windows error %d", search_pattern, last_error))
	end

	return entries
end

local function collect_matching_files(base_path, file_path_prefix, segments, index, files)
	local segment = segments[index]
	local entries = find_entries(join_path(base_path, segment))
	local is_last_segment = index == #segments

	if not entries then
		return
	end

	for i = 1, #entries do
		local entry = entries[i]
		local matched_base_path = join_path(base_path, entry.name)
		local matched_file_path = join_path(file_path_prefix, entry.name)

		if is_last_segment then
			if not entry.is_directory then
				files[#files + 1] = matched_file_path
			end
		elseif entry.is_directory then
			collect_matching_files(matched_base_path, matched_file_path, segments, index + 1, files)
		end
	end
end

filesystem.find_files = function(search_pattern, file_path_prefix)
	local base_path, relative_pattern = split_search_pattern(search_pattern)
	local segments = split_segments(relative_pattern)
	local files = {}

	file_path_prefix = file_path_prefix or ""

	if #segments == 0 then
		return nil
	end

	collect_matching_files(base_path, file_path_prefix, segments, 1, files)

	if #files == 0 then
		return nil
	end

	table.sort(files)

	return files
end

filesystem.temp_path = function()
	local required_length = windows.kernel32.GetTempPathW(0, nil)

	if required_length == 0 then
		error(string.format("Failed to get temp path: Windows error %d", windows.last_error()))
	end

	local buffer = ffi.new("SimpleAudio_WCHAR[?]", required_length + 1)
	local result = windows.kernel32.GetTempPathW(required_length + 1, buffer)

	if result == 0 or result > required_length then
		error(string.format("Failed to get temp path: Windows error %d", windows.last_error()))
	end

	return windows.wide_to_utf8(buffer):gsub("\\", "/")
end

filesystem.ensure_directory = function(path)
	if windows.kernel32.CreateDirectoryW(windows.utf8_to_wide(windows.path(path)), nil) == 0 then
		local last_error = windows.last_error()

		if last_error ~= ERROR_ALREADY_EXISTS then
			error(string.format("Failed to create directory %s: Windows error %d", path, last_error))
		end
	end
end

filesystem.open_read = function(path)
	local handle = windows.kernel32.CreateFileW(
		windows.utf8_to_wide(windows.path(path)),
		GENERIC_READ,
		FILE_SHARE_READ,
		nil,
		OPEN_EXISTING,
		FILE_ATTRIBUTE_NORMAL,
		nil
	)

	if handle == INVALID_HANDLE_VALUE then
		error(string.format("Failed to open file for reading %s: Windows error %d", path, windows.last_error()))
	end

	return handle
end

filesystem.open_write = function(path)
	local handle = windows.kernel32.CreateFileW(
		windows.utf8_to_wide(windows.path(path)),
		GENERIC_WRITE,
		0,
		nil,
		CREATE_ALWAYS,
		FILE_ATTRIBUTE_NORMAL,
		nil
	)

	if handle == INVALID_HANDLE_VALUE then
		error(string.format("Failed to open file for writing %s: Windows error %d", path, windows.last_error()))
	end

	return handle
end

filesystem.close = function(handle)
	if handle ~= nil and handle ~= INVALID_HANDLE_VALUE and windows.kernel32.CloseHandle(handle) == 0 then
		error(string.format("Failed to close file handle: Windows error %d", windows.last_error()))
	end
end

filesystem.read = function(handle, buffer, byte_count)
	local bytes_read = ffi.new("SimpleAudio_DWORD[1]")

	if windows.kernel32.ReadFile(handle, buffer, byte_count, bytes_read, nil) == 0 then
		error(string.format("Failed to read audio cache file: Windows error %d", windows.last_error()))
	end

	return tonumber(bytes_read[0])
end

filesystem.write = function(handle, buffer, byte_count)
	local bytes_written = ffi.new("SimpleAudio_DWORD[1]")

	if windows.kernel32.WriteFile(handle, buffer, byte_count, bytes_written, nil) == 0 then
		error(string.format("Failed to write audio cache file: Windows error %d", windows.last_error()))
	end
	if tonumber(bytes_written[0]) ~= byte_count then
		error(string.format("Failed to write complete audio cache file: wrote %d of %d bytes", tonumber(bytes_written[0]), byte_count))
	end
end

filesystem.seek = function(handle, byte_offset)
	local new_position = ffi.new("long long[1]")

	if windows.kernel32.SetFilePointerEx(handle, byte_offset, new_position, FILE_BEGIN) == 0 then
		error(string.format("Failed to seek audio cache file: Windows error %d", windows.last_error()))
	end
end

filesystem.delete = function(path)
	if windows.kernel32.DeleteFileW(windows.utf8_to_wide(windows.path(path))) == 0 then
		local last_error = windows.last_error()

		if last_error ~= ERROR_FILE_NOT_FOUND and last_error ~= ERROR_PATH_NOT_FOUND then
			error(string.format("Failed to delete audio cache file %s: Windows error %d", path, last_error))
		end
	end
end

return filesystem
