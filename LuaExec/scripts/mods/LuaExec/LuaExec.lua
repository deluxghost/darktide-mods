local mod = get_mod("LuaExec")

local logs = mod:io_dofile("LuaExec/scripts/mods/LuaExec/logs")
local executor = mod:io_dofile("LuaExec/scripts/mods/LuaExec/executor")
local runtime = mod:io_dofile("LuaExec/scripts/mods/LuaExec/runtime/native")

local function encode_response(response)
	local ok, payload = pcall(cjson.encode, response)

	if ok then
		return payload
	end

	return cjson.encode({
		ok = false,
		error = "failed to encode response: " .. tostring(payload),
	})
end

local function handle_payload(payload)
	local ok, request = pcall(cjson.decode, payload)

	if not ok then
		return encode_response({
			ok = false,
			error = "invalid request JSON: " .. tostring(request),
		})
	end

	return encode_response(executor.execute_request(request, logs))
end

logs.install_hooks()

local runtime_ok, runtime_error = runtime.start()

if not runtime_ok then
	mod:error(runtime_error)
end

mod.update = function()
	while true do
		local request_id, payload_or_error = runtime.poll_request()

		if request_id == nil then
			return
		end
		if request_id == false then
			mod:error(payload_or_error)
			return
		end

		local response = handle_payload(payload_or_error)
		local ok, send_error = runtime.send_response(request_id, response)

		if not ok then
			mod:error(send_error)
		end
	end
end

mod.on_all_mods_loaded = function()
	logs.install_hooks()
end

mod.on_unload = function()
	logs.uninstall_hooks()
	logs.stop_session()
	runtime.stop()
end
