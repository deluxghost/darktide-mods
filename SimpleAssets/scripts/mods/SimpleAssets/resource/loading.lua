local mod = get_mod("SimpleAssets")
local Promise = require("scripts/foundation/utilities/promise")

local context = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/context")
local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")
local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")

local loading = {}

local LOAD_TIMEOUT_SECONDS = 30
local RESOURCE_PREFIX = "simple_assets/external_resource/"

local pending = {}

local function validate_string(value, name)
	if type(value) ~= "string" then
		error(string.format("%s must be a string, got %s", name, type(value)))
	end
	if value == "" then
		error(string.format("%s must not be empty", name))
	end
end

local function hex_encode(value)
	return (value:gsub(".", function(character)
		return string.format("%02x", string.byte(character))
	end))
end

local function wait_until_ready(request)
	local result = Promise:new()
	local ready = Promise.until_true(function()
		local state, state_error = native_runtime.resource_state(request.type, request.name)

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

loading.prepare = function(resource_type, logical_name, asset_path)
	validate_string(resource_type, "Resource type")
	validate_string(logical_name, "Resource name")
	validate_string(asset_path, "Resource asset path")

	local calling_mod_name = context.mod_name()
	local name = RESOURCE_PREFIX .. hex_encode(calling_mod_name .. "\0" .. resource_type .. "\0" .. logical_name)
	local resolved_path = paths.resolve_asset_path(asset_path)

	return {
		key = resource_type .. "\0" .. name .. "\0" .. resolved_path,
		name = name,
		path = resolved_path,
		type = resource_type,
	}
end

loading.load_prepared = function(request)
	if pending[request.key] then
		return pending[request.key]
	end

	local started, start_error = native_runtime.resource_load(request.type, request.name, request.path)

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

	return promise
end

return loading
