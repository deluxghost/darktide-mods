local mod = get_mod("SimpleAssets")

local context = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/context")
local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")

local paths = {}

local cached_game_dir
local cached_user_dir

local function normalize_path(path)
	local normalized_path = path:gsub("\\", "/")
	normalized_path = normalized_path:gsub("/+$", "")

	return normalized_path
end

local function validate_asset_path(asset_path, allow_empty)
	if type(asset_path) ~= "string" then
		error(string.format("Asset path must be a string, got %s", type(asset_path)))
	end
	if not allow_empty and asset_path == "" then
		error("Asset path must not be empty")
	end
end

local function is_windows_absolute(path)
	return path:match("^%a:[/\\]") ~= nil or path:match("^[/\\][/\\]") ~= nil
end

local function expand_relative_path(asset_path, allow_empty)
	local normalized_path = normalize_path(asset_path):gsub("^/+", "")
	local caller_name = context.mod_name()

	if caller_name == "unknown" then
		error("Could not determine the calling mod for the asset path")
	end
	if normalized_path == "" then
		if allow_empty then
			return "mods/" .. caller_name .. "/assets"
		end

		error("Asset path must not be empty")
	end
	if normalized_path:sub(1, 5):lower() == "mods/" then
		return "mods/" .. normalized_path:sub(6)
	end
	if normalized_path:sub(1, #caller_name + 1):lower() == (caller_name .. "/"):lower() then
		return "mods/" .. caller_name .. normalized_path:sub(#caller_name + 1)
	end

	return "mods/" .. caller_name .. "/assets/" .. normalized_path
end

paths.join_path = function(base_path, path)
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

paths.get_game_dir = function()
	if not cached_game_dir then
		cached_game_dir = normalize_path(native_runtime.game_dir())
	end

	return cached_game_dir
end

paths.get_user_dir = function()
	if not cached_user_dir then
		cached_user_dir = normalize_path(native_runtime.user_dir())
	end

	return cached_user_dir
end

paths.get_asset_path = function(asset_path)
	validate_asset_path(asset_path, false)

	local expanded_path = is_windows_absolute(asset_path) and asset_path or expand_relative_path(asset_path, false)

	return native_runtime.canonical_asset_path(expanded_path)
end

paths.get_resource_path = function(resource_path)
	validate_asset_path(resource_path, false)

	return native_runtime.canonical_asset_path(resource_path)
end

paths.get_asset_dir_path = function(asset_dir_path)
	validate_asset_path(asset_dir_path, true)

	local expanded_path = is_windows_absolute(asset_dir_path) and asset_dir_path or
		expand_relative_path(asset_dir_path, true)

	return native_runtime.canonical_asset_path(expanded_path)
end

paths.get_asset_dir_paths = function(asset_dir_path)
	local virtual_path = paths.get_asset_dir_path(asset_dir_path)
	local physical_paths = {}

	if virtual_path == "mods" or virtual_path:sub(1, 5) == "mods/" then
		physical_paths[#physical_paths + 1] = paths.join_path(paths.get_user_dir(), virtual_path)
	end
	physical_paths[#physical_paths + 1] = paths.join_path(paths.get_game_dir(), virtual_path)

	return virtual_path, physical_paths
end

return paths
