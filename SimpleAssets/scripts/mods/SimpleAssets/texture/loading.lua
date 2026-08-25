local mod = get_mod("SimpleAssets")
local Promise = require("scripts/foundation/utilities/promise")

local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")
local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local filesystem = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/platform/filesystem")
local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_replacement = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/replacement")

local loading = {}

local RESOURCE_TYPE = "texture"
local RESOURCE_EXTENSION = ".texture"

local function start_texture_resource(request)
	return native_runtime.texture_load(request.path)
end

local function resolved(value)
	local promise = Promise:new()

	promise:resolve(value)

	return promise
end

local function rejected(load_error)
	return Promise.rejected({
		is_ok = false,
		error = load_error,
	})
end

local function load_url_texture(virtual_path)
	if not Managers.url_loader then
		return rejected("Managers.url_loader is not available")
	end

	local created, url = pcall(native_runtime.asset_url, virtual_path)

	if not created then
		return rejected(url)
	end

	return Managers.url_loader:load_texture(url, false)
end

local load_texture_resource = resource_loading.create_loader(
	RESOURCE_TYPE,
	RESOURCE_EXTENSION,
	start_texture_resource
)

local function load_engine_texture(asset_path)
	return load_texture_resource(asset_path):next(function(result)
		return {
			is_ok = true,
			resource_name = result.resource_name,
			texture = result.resource_name,
		}
	end)
end

local function texture_candidate(virtual_path, relative_path)
	if relative_path:sub(-#RESOURCE_EXTENSION):lower() == RESOURCE_EXTENSION then
		return true
	end

	local image_format, detect_error = native_runtime.detect_image_format(virtual_path)

	if detect_error then
		return nil, detect_error
	end

	return image_format ~= nil
end

local function load_virtual_texture(virtual_path)
	local image_format, detect_error = native_runtime.detect_image_format(virtual_path)

	if detect_error then
		return rejected(detect_error)
	end
	if image_format then
		return load_url_texture(virtual_path)
	end
	if virtual_path:sub(-#RESOURCE_EXTENSION):lower() ~= RESOURCE_EXTENSION then
		return rejected(
			"Texture asset must contain PNG, JPEG, or DDS data or use the .texture extension"
		)
	end

	return load_engine_texture(virtual_path)
end

local function dense_array_length(values)
	local count = 0
	local maximum = 0

	for key in pairs(values) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			error("Asset paths must be a dense array")
		end

		count = count + 1
		maximum = math.max(maximum, key)
	end

	if count ~= maximum then
		error("Asset paths must be a dense array")
	end

	return count
end

local function settle_result(results, key, promise)
	return promise:next(function(value)
		results[key] = value
	end, function(load_error)
		results[key] = load_error
	end)
end

loading.load_texture = function(asset_path)
	local virtual_path = paths.get_asset_path(asset_path)
	return load_virtual_texture(virtual_path)
end

loading.replace_texture = resource_replacement.create_replacer(
	RESOURCE_TYPE,
	RESOURCE_EXTENSION,
	start_texture_resource,
	native_runtime.texture_replace
)

loading.load_textures = function(asset_paths)
	if type(asset_paths) ~= "table" then
		error(string.format("Asset paths must be a table, got %s", type(asset_paths)))
	end

	local count = dense_array_length(asset_paths)
	local seen = {}
	local results = {}
	local promises = {}

	local virtual_paths = {}
	for i = 1, count do
		local asset_path = asset_paths[i]

		if type(asset_path) ~= "string" then
			error(string.format("Asset path at index %d must be a string, got %s", i, type(asset_path)))
		end

		local virtual_path = paths.get_asset_path(asset_path)
		local identity = virtual_path:lower()

		if seen[identity] then
			error(string.format("Duplicate asset path is not allowed: %s", asset_path))
		end

		seen[identity] = true
		virtual_paths[i] = virtual_path
	end

	for i = 1, count do
		local asset_path = asset_paths[i]

		promises[#promises + 1] = settle_result(
			results,
			asset_path,
			load_virtual_texture(virtual_paths[i])
		)
	end

	if #promises == 0 then
		return resolved(results)
	end

	return Promise.all(unpack(promises)):next(function()
		return results
	end)
end

loading.load_textures_from_dir = function(asset_dir_path, recursive)
	local virtual_dir_path, physical_dir_paths = paths.get_asset_dir_paths(asset_dir_path)
	local listed, relative_paths = pcall(filesystem.list_files, physical_dir_paths, recursive == true)
	local candidates = {}
	local results = {}
	local promises = {}

	if not listed then
		return rejected(relative_paths)
	end

	for i = 1, #relative_paths do
		local relative_path = relative_paths[i]
		local virtual_path = paths.join_path(virtual_dir_path, relative_path)
		local is_candidate, detect_error = texture_candidate(virtual_path, relative_path)

		if detect_error then
			return rejected(detect_error)
		end
		if is_candidate then
			candidates[#candidates + 1] = {
				relative_path = relative_path,
				virtual_path = virtual_path,
			}
		end
	end

	for i = 1, #candidates do
		local candidate = candidates[i]

		promises[#promises + 1] = settle_result(
			results,
			candidate.relative_path,
			load_virtual_texture(candidate.virtual_path)
		)
	end

	if #promises == 0 then
		return resolved(results)
	end

	return Promise.all(unpack(promises)):next(function()
		return results
	end)
end

return loading
