local mod = get_mod("SimpleAssets")
local Promise = require("scripts/foundation/utilities/promise")

local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")
local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_naming = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/naming")

local replacement = {}

local function validate_string(value, name)
	if type(value) ~= "string" then
		error(string.format("%s must be a string, got %s", name, type(value)))
	end
	if value == "" then
		error(string.format("%s must not be empty", name))
	end
end

local function validate_extension(path, extension, name)
	if path:sub(-#extension):lower() ~= extension:lower() then
		error(string.format("%s must refer to a %s file", name, extension))
	end
end

local function result(target_name, source_name, is_ok, replace_error)
	local value = {
		is_ok = is_ok,
		source_resource_name = source_name,
		target_resource_name = target_name,
	}

	if replace_error ~= nil then
		value.error = replace_error
	end

	return value
end

local function rejected(target_name, source_name, replace_error)
	if type(replace_error) == "table" and replace_error.error ~= nil then
		replace_error = replace_error.error
	end

	return Promise.rejected(result(target_name, source_name, false, replace_error))
end

replacement.replace = function(
	resource_type,
	target_extension,
	source_extension,
	target_resource_path,
	source_asset_path,
	start_loading,
	install_replacement
)
	validate_string(target_resource_path, "Target resource path")
	validate_string(source_asset_path, "Source asset path")
	validate_extension(target_resource_path, target_extension, "Target resource path")
	validate_extension(source_asset_path, source_extension, "Source asset path")

	local target_path = paths.get_resource_path(target_resource_path)
	local target_name = resource_naming.get_name(target_path)
	local source_request = resource_loading.prepare(resource_type, source_asset_path)

	return resource_loading.load_prepared(source_request, start_loading):next(function()
		local call_ok, installed, install_error = pcall(
			install_replacement,
			target_path,
			source_request.path
		)

		if not call_ok then
			return rejected(target_name, source_request.name, installed)
		end
		if not installed then
			return rejected(target_name, source_request.name, install_error)
		end

		return result(target_name, source_request.name, true)
	end, function(load_error)
		return rejected(target_name, source_request.name, load_error)
	end)
end

replacement.create_replacer = function(resource_type, extension, start_loading, install_replacement)
	validate_string(resource_type, "Resource type")
	validate_string(extension, "Resource extension")
	if type(start_loading) ~= "function" then
		error(string.format("Resource loader must be a function, got %s", type(start_loading)))
	end
	if type(install_replacement) ~= "function" then
		error(string.format("Resource replacement installer must be a function, got %s", type(install_replacement)))
	end
	if extension:sub(1, 1) ~= "." then
		error("Resource extension must start with a dot")
	end

	return function(target_resource_path, source_asset_path)
		return replacement.replace(
			resource_type,
			extension,
			extension,
			target_resource_path,
			source_asset_path,
			start_loading,
			install_replacement
		)
	end
end

return replacement
