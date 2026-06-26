local mod = get_mod("SimpleAudio")
local ffi = Mods.lua.ffi

local windows = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/platform/windows")

local filesystem = {}

local ERROR_FILE_NOT_FOUND = 2
local ERROR_PATH_NOT_FOUND = 3
local ERROR_NO_MORE_FILES = 18
local FILE_ATTRIBUTE_DIRECTORY = 0x10

if not pcall(ffi.typeof, "SimpleAudio_FILESYSTEM_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } SimpleAudio_FILESYSTEM_CDEF;

		SimpleAudio_HANDLE FindFirstFileW(const SimpleAudio_WCHAR* lpFileName, SimpleAudio_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAudio_BOOL FindNextFileW(SimpleAudio_HANDLE hFindFile, SimpleAudio_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAudio_BOOL FindClose(SimpleAudio_HANDLE hFindFile);
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

return filesystem
