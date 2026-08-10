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

paths.normalize_asset_path = function(asset_path)
	local normalized_path = asset_path:gsub("\\", "/")
	normalized_path = normalized_path:gsub("^/+", "")

	return normalized_path
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

paths.resolve_asset_path = function(asset_path)
	if type(asset_path) ~= "string" then
		error(string.format("Asset path must be a string, got %s", type(asset_path)))
	end

	local normalized_path = paths.normalize_asset_path(asset_path)

	if normalized_path == "" then
		error("Asset path must not be empty")
	end

	if normalized_path:match("^%a:/") then
		return normalized_path
	end

	local game_dir = paths.get_game_dir()

	if normalized_path:sub(1, 5) == "mods/" then
		return paths.join_path(game_dir, normalized_path)
	end

	local caller_name = context.mod_name()

	if normalized_path:sub(1, #caller_name + 1) == caller_name .. "/" then
		return paths.join_path(game_dir, "mods/" .. normalized_path)
	end

	return paths.join_path(game_dir, "mods/" .. caller_name .. "/assets/" .. normalized_path)
end

paths.resolve_asset_dir_path = function(asset_dir_path)
	if type(asset_dir_path) ~= "string" then
		error(string.format("Asset path must be a string, got %s", type(asset_dir_path)))
	end

	local normalized_path = paths.normalize_asset_path(asset_dir_path)
	local resolved_path

	if normalized_path == "" then
		resolved_path = paths.join_path(paths.get_game_dir(), "mods/" .. context.mod_name() .. "/assets")
	else
		resolved_path = paths.resolve_asset_path(asset_dir_path)
	end

	return paths.normalize_asset_path(native_runtime.resolve_asset_path(resolved_path, true))
end

return paths
