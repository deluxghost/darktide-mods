local mod = get_mod("SimpleAssets")
local ffi = Mods.lua.ffi

local windows = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/platform/windows")
local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")

local filesystem = {}

local ERROR_FILE_NOT_FOUND = 2
local ERROR_PATH_NOT_FOUND = 3
local ERROR_NO_MORE_FILES = 18
local FILE_ATTRIBUTE_DIRECTORY = 0x10

local INVALID_HANDLE_VALUE = ffi.cast("SimpleAssets_HANDLE", -1)

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

local function find_entries(runtime, search_pattern)
	local find_data = ffi.new("SimpleAssets_WIN32_FIND_DATAW[1]")
	local handle = runtime.SimpleAssetsRuntime_FindFirstFileW(windows.utf8_to_wide(runtime, windows.path(search_pattern)), find_data)

	if handle == INVALID_HANDLE_VALUE then
		local last_error = windows.last_error(runtime)

		if last_error == ERROR_FILE_NOT_FOUND or last_error == ERROR_PATH_NOT_FOUND then
			return nil
		end

		error(string.format("Failed to list asset files for %s: Windows error %d", search_pattern, last_error))
	end

	local entries = {}
	local last_error

	while true do
		local attributes = tonumber(find_data[0].dwFileAttributes)
		local name = windows.wide_to_utf8(runtime, find_data[0].cFileName)

		if name ~= "." and name ~= ".." then
			entries[#entries + 1] = {
				is_directory = has_file_attribute(attributes, FILE_ATTRIBUTE_DIRECTORY),
				name = name,
			}
		end

		if runtime.SimpleAssetsRuntime_FindNextFileW(handle, find_data) == 0 then
			last_error = windows.last_error(runtime)
			break
		end
	end

	if runtime.SimpleAssetsRuntime_FindClose(handle) == 0 then
		error(string.format("Failed to close asset file listing handle: Windows error %d", windows.last_error(runtime)))
	end

	if last_error ~= ERROR_NO_MORE_FILES then
		error(string.format("Failed to list asset files for %s: Windows error %d", search_pattern, last_error))
	end

	return entries
end

local function collect_files(runtime, directory_path, relative_base_path, recursive, files)
	local entries = find_entries(runtime, join_path(directory_path, "*"))

	if not entries then
		return
	end

	for i = 1, #entries do
		local entry = entries[i]
		local child_path = join_path(directory_path, entry.name)
		local relative_path = join_path(relative_base_path, entry.name)

		if entry.is_directory then
			if recursive then
				collect_files(runtime, child_path, relative_path, recursive, files)
			end
		else
			files[#files + 1] = relative_path:gsub("\\", "/")
		end
	end
end

filesystem.list_files = function(directory_path, recursive)
	if type(directory_path) ~= "string" then
		error(string.format("Asset directory path must be a string, got %s", type(directory_path)))
	end

	local runtime, load_error = native_runtime.runtime()

	if not runtime then
		error(load_error)
	end

	if not windows.is_directory(runtime, directory_path) then
		error(string.format("Asset directory was not found: %s", directory_path))
	end

	local files = {}

	collect_files(runtime, directory_path, "", recursive == true, files)
	table.sort(files)

	return files
end

return filesystem
