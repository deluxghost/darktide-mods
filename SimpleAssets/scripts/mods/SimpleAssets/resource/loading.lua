local mod = get_mod("SimpleAssets")

if mod._simple_assets_resource_loading then
	return mod._simple_assets_resource_loading
end

local Promise = require("scripts/foundation/utilities/promise")

local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")
local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local resource_naming = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/naming")

local loading = {}

local LOAD_TIMEOUT_SECONDS = 30

local pending = {}

local function follow(promise)
	return promise:next(function(value)
		return value
	end)
end

local function load_result(request, is_ok, load_error)
	local result = {
		is_ok = is_ok,
		resource_name = request.name,
	}

	if load_error ~= nil then
		result.error = load_error
	end

	return result
end

local function rejected_result(request, load_error)
	return Promise.rejected(load_result(request, false, load_error))
end

local function validate_string(value, name)
	if type(value) ~= "string" then
		error(string.format("%s must be a string, got %s", name, type(value)))
	end
	if value == "" then
		error(string.format("%s must not be empty", name))
	end
end

local function query_resource_state(request)
	return native_runtime.resource_state(request.type, request.path)
end

local function wait_until_ready(request)
	local result = Promise:new()
	local ready = Promise.until_true(function()
		local state, state_error = query_resource_state(request)

		if state == nil then
			return false, state_error
		end

		return state == 1
	end)
	local timeout = Promise.delay(LOAD_TIMEOUT_SECONDS)

	ready:next(function(value)
		if result:is_pending() then
			timeout:cancel()
			result:resolve(value)
		end
	end, function(reason)
		if result:is_pending() then
			timeout:cancel()
			result:reject(reason)
		end
	end)
	timeout:next(function()
		if result:is_pending() then
			ready:cancel()
			result:reject(string.format(
				"Timed out waiting for external %s resource: %s",
				request.type,
				request.name
			))
		end
	end)

	return result
end

local function prepare_request(resource_type, virtual_path)
	local name = resource_naming.get_name(virtual_path)

	return {
		key = resource_type .. "\0" .. name,
		name = name,
		path = virtual_path,
		type = resource_type,
	}
end

loading.prepare = function(resource_type, asset_path)
	validate_string(resource_type, "Resource type")
	validate_string(asset_path, "Resource asset path")

	return prepare_request(resource_type, paths.get_asset_path(asset_path))
end

loading.load_prepared = function(request, start_loading)
	if pending[request.key] then
		return follow(pending[request.key])
	end

	local call_ok, started, start_error = pcall(start_loading, request)

	if not call_ok then
		return rejected_result(request, started)
	end

	if not started then
		return rejected_result(request, start_error)
	end

	local promise = wait_until_ready(request):next(
		function()
			return load_result(request, true)
		end,
		function(load_error)
			return rejected_result(request, load_error)
		end
	)

	promise:next(function()
		pending[request.key] = nil
	end, function()
		pending[request.key] = nil
	end)
	pending[request.key] = promise

	return follow(promise)
end

loading.create_loader = function(resource_type, extension, start_loading)
	validate_string(resource_type, "Resource type")
	validate_string(extension, "Resource extension")
	if type(start_loading) ~= "function" then
		error(string.format("Resource loader must be a function, got %s", type(start_loading)))
	end
	if extension:sub(1, 1) ~= "." then
		error("Resource extension must start with a dot")
	end

	return function(asset_path)
		validate_string(asset_path, "Resource asset path")
		if asset_path:sub(-#extension):lower() ~= extension:lower() then
			error(string.format("%s asset path must refer to a %s file", resource_type, extension))
		end

		local request = loading.prepare(resource_type, asset_path)

		return loading.load_prepared(request, start_loading)
	end
end

mod._simple_assets_resource_loading = loading

return loading
