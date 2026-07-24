local M = {}

local function serialize_value(value)
	local value_type = type(value)

	if value_type == "nil" then
		return {
			type = "nil",
		}
	elseif value_type == "number" or value_type == "string" or value_type == "boolean" then
		return {
			type = value_type,
			value = value,
		}
	else
		return {
			type = value_type,
			value = tostring(value),
		}
	end
end

local function value_to_text(value)
	if value == nil then
		return "nil"
	end

	return tostring(value)
end

local function traceback(error_value)
	if debug and debug.traceback then
		return debug.traceback(tostring(error_value), 2)
	end

	return tostring(error_value)
end

local function call_chunk(chunk)
	local values = {}

	local function capture(...)
		local count = select("#", ...)

		for i = 1, count do
			values[i] = select(i, ...)
		end

		return count
	end

	local function invoke()
		return capture(chunk())
	end

	local ok, count_or_error = xpcall(invoke, traceback)

	return ok, count_or_error, values
end

function M.execute_request(request)
	if type(request) ~= "table" then
		return {
			ok = false,
			error = "request must be a JSON object",
		}
	end

	local request_id = type(request.id) == "string" and request.id or nil
	local command = type(request.command) == "string" and request.command or nil

	if command ~= nil and command ~= "exec" then
		return {
			id = request_id,
			ok = false,
			error = "unknown command: " .. command,
		}
	end

	if type(request.code) ~= "string" then
		return {
			id = request_id,
			ok = false,
			error = "request.code must be a string",
		}
	end

	local chunk, compile_error = Mods.lua.loadstring(request.code, "dt-cli:" .. tostring(request_id or "request"))
	if not chunk then
		return {
			id = request_id,
			ok = false,
			error = tostring(compile_error),
		}
	end

	local ok, count_or_error, values = call_chunk(chunk)
	if not ok then
		return {
			id = request_id,
			ok = false,
			error = tostring(count_or_error),
		}
	end

	local result_values = {}
	local output_values = {}

	for i = 1, count_or_error do
		local value = values[i]
		result_values[i] = serialize_value(value)
		output_values[i] = value_to_text(value)
	end

	return {
		id = request_id,
		ok = true,
		output = table.concat(output_values, "\t"),
		result = {
			count = count_or_error,
			values = result_values,
		},
	}
end

return M
