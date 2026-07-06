local mod = get_mod("SimpleAssets")
local Promise = require("scripts/foundation/utilities/promise")

local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")
local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local filesystem = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/platform/filesystem")

local loading = {}

local function resolved(value)
	local promise = Promise:new()

	promise:resolve(value)

	return promise
end

local function ensure_url_loader()
	if not Managers.url_loader then
		error("Managers.url_loader is not available")
	end
end

local function load_resolved_texture(resolved_path)
	ensure_url_loader()

	return Managers.url_loader:load_texture(native_runtime.asset_url(resolved_path), false)
end

loading.load_texture = function(asset_path)
	return load_resolved_texture(paths.resolve_asset_path(asset_path))
end

loading.load_textures = function(asset_paths)
	if type(asset_paths) ~= "table" then
		error(string.format("Asset paths must be a table, got %s", type(asset_paths)))
	end

	local seen = {}
	local results = {}
	local promises = {}

	for i = 1, #asset_paths do
		local asset_path = asset_paths[i]

		if type(asset_path) ~= "string" then
			error(string.format("Asset path at index %d must be a string, got %s", i, type(asset_path)))
		end
		if seen[asset_path] then
			error(string.format("Duplicate asset path is not allowed: %s", asset_path))
		end

		seen[asset_path] = true
		promises[#promises + 1] = loading.load_texture(asset_path)
			:next(function(value)
				results[asset_path] = value
			end)
			:catch(function(error)
				results[asset_path] = error
			end)
	end

	if #promises == 0 then
		return resolved(results)
	end

	return Promise.all(unpack(promises)):next(function()
		return results
	end)
end

loading.load_textures_from_dir = function(asset_dir_path, recursive)
	local resolved_dir_path = paths.resolve_asset_dir_path(asset_dir_path)
	local relative_paths = filesystem.list_files(resolved_dir_path, recursive == true)
	local results = {}
	local promises = {}

	for i = 1, #relative_paths do
		local relative_path = relative_paths[i]
		local resolved_path = paths.join_path(resolved_dir_path, relative_path)

		promises[#promises + 1] = load_resolved_texture(resolved_path)
			:next(function(value)
				results[relative_path] = value
			end)
			:catch(function(error)
				results[relative_path] = error
			end)
	end

	if #promises == 0 then
		return resolved(results)
	end

	return Promise.all(unpack(promises)):next(function()
		return results
	end)
end

return loading
