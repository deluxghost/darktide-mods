local mod = get_mod("SimpleAssets")
local Promise = require("scripts/foundation/utilities/promise")

local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")
local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")

local loading = {}

local LOAD_TIMEOUT_SECONDS = 30

local pending = {}

local function follow(promise)
	return promise:next(function(value)
		return value
	end)
end

local function start_resource(request)
	return native_runtime.resource_load(request.type, request.name, request.path)
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
	return native_runtime.resource_state(request.type, request.name)
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

loading.prepare = function(resource_type, name, asset_path, variant_key)
	validate_string(resource_type, "Resource type")
	validate_string(name, "Resource name")
	validate_string(asset_path, "Resource asset path")
	if variant_key ~= nil then
		validate_string(variant_key, "Resource variant key")
	end

	local resolved_path = paths.resolve_asset_path(asset_path)
	local key = table.concat({
		resource_type,
		name,
		resolved_path,
		variant_key or "",
	}, "\0")

	return {
		key = key,
		name = name,
		path = resolved_path,
		type = resource_type,
	}
end

loading.load_prepared = function(request, start_loading)
	if pending[request.key] then
		return follow(pending[request.key])
	end

	start_loading = start_loading or start_resource
	local started, start_error = start_loading(request)

	if not started then
		return Promise.rejected(start_error)
	end

	local promise = wait_until_ready(request):next(function()
		return request.name
	end)

	promise:next(function()
		pending[request.key] = nil
	end, function()
		pending[request.key] = nil
	end)
	pending[request.key] = promise

	return follow(promise)
end

return loading
