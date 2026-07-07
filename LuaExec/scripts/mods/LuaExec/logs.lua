local LOG_MAX_ENTRIES = 128
local LOG_MAX_LINE_LENGTH = 4096
local LOG_SESSION_TIMEOUT = 5
local DMF_DEFAULT_LOG_MODES = {
	notify = 5,
	echo = 4,
	error = 7,
	warning = 4,
	info = 1,
	debug = 0,
}
local DMF_LOG_OUTPUT_MODES = {
	[1] = true,
	[4] = true,
	[5] = true,
	[7] = true,
}

local M = {}

local log_state = {
	sessions = {},
	originals = {},
	dmf_originals = {},
}

local function current_time()
	if Application and Application.time_since_launch then
		return Application.time_since_launch()
	end

	return 0
end

function M.stop_session()
	log_state.sessions = {}
end

local function logs_session_expired(session, now)
	return now - session.last_poll_time > LOG_SESSION_TIMEOUT
end

local function shorten_log_line(line)
	if #line <= LOG_MAX_LINE_LENGTH then
		return line
	end

	return string.sub(line, 1, LOG_MAX_LINE_LENGTH) .. "... [truncated]"
end

local function prune_expired_sessions(now)
	for id, session in pairs(log_state.sessions) do
		if logs_session_expired(session, now) then
			log_state.sessions[id] = nil
		end
	end
end

local function capture_session_log_line(session, line)
	local queue = session.queue
	if #queue >= LOG_MAX_ENTRIES then
		table.remove(queue, 1)
		session.dropped = session.dropped + 1
	end

	queue[#queue + 1] = line
end

local function capture_log_line(line)
	local now = current_time()
	prune_expired_sessions(now)

	local shortened_line = shorten_log_line(tostring(line))
	for _, session in pairs(log_state.sessions) do
		capture_session_log_line(session, shortened_line)
	end
end

local function print_args_to_line(...)
	local count = select("#", ...)
	if count == 0 then
		return ""
	end

	local parts = {}
	for i = 1, count do
		parts[i] = tostring(select(i, ...))
	end

	return table.concat(parts, "\t")
end

local function wrap_print_function(name)
	if log_state.originals[name] ~= nil or type(_G[name]) ~= "function" then
		return
	end

	local original = _G[name]
	log_state.originals[name] = original

	_G[name] = function(...)
		capture_log_line(print_args_to_line(...))
		return original(...)
	end
end

local function format_dmf_message(message, ...)
	local ok, formatted = pcall(string.format, tostring(message), ...)
	if ok then
		return formatted
	end

	return nil
end

local function dmf_sends_to_log(method_name)
	local dmf = rawget(_G, "get_mod") and get_mod("DMF")
	local mode = DMF_DEFAULT_LOG_MODES[method_name]

	if dmf and dmf.get and dmf:get("logging_mode") == "custom" then
		local setting_name = method_name == "notify" and "notification" or method_name
		mode = dmf:get("output_mode_" .. setting_name)
	end

	return DMF_LOG_OUTPUT_MODES[mode] == true
end

local function wrap_dmf_log_method(method_name, tag)
	if not DMFMod or log_state.dmf_originals[method_name] ~= nil or type(DMFMod[method_name]) ~= "function" then
		return
	end

	local original = DMFMod[method_name]
	log_state.dmf_originals[method_name] = original

	DMFMod[method_name] = function(self, message, ...)
		if dmf_sends_to_log(method_name) then
			local formatted = format_dmf_message(message, ...)
			local mod_name = self and self.get_name and self:get_name() or "Unknown"

			if formatted then
				capture_log_line(string.format("[MOD][%s][%s] %s", mod_name, tag, formatted))
			end
		end

		return original(self, message, ...)
	end
end

local function wrap_crashify_function(name, formatter)
	if not Crashify or log_state.originals["Crashify." .. name] ~= nil or type(Crashify[name]) ~= "function" then
		return
	end

	local key = "Crashify." .. name
	local original = Crashify[name]
	log_state.originals[key] = original

	Crashify[name] = function(...)
		local line = formatter(...)
		if line then
			capture_log_line(line)
		end

		return original(...)
	end
end

function M.install_hooks()
	wrap_print_function("__print")
	wrap_print_function("__print_warning")
	wrap_print_function("__print_error")

	wrap_crashify_function("print_exception", function(system, message, print_func)
		if print_func ~= nil or system == nil or message == nil then
			return nil
		end

		local callstack = Script and Script.callstack and Script.callstack() or ""

		return string.format("<<crashify-exception>>\n             \t<<system>>%s<</system>>\n             \t<<message>>%s<</message>>\n             \t<<callstack>>%s<</callstack>>\n             <</crashify-exception>>", tostring(system), tostring(message), callstack)
	end)

	wrap_crashify_function("print_property", function(key, value, print_func)
		if print_func ~= nil or key == nil or value == nil then
			return nil
		end

		return string.format("<<crashify-property>>%s = %s<</crashify-property>>", tostring(key), tostring(value))
	end)

	wrap_crashify_function("print_breadcrumb", function(crumb, print_func)
		if print_func ~= nil or crumb == nil then
			return nil
		end

		return string.format("<<crashify-breadcrumb>>\n             \t<<timestamp>%f<</timestamp>>\n             \t<<value>>%s<</value>>\n             <</crashify-breadcrumb>>", current_time(), tostring(crumb))
	end)

	wrap_dmf_log_method("notify", "NOTIFICATION")
	wrap_dmf_log_method("echo", "ECHO")
	wrap_dmf_log_method("error", "ERROR")
	wrap_dmf_log_method("warning", "WARNING")
	wrap_dmf_log_method("info", "INFO")
	wrap_dmf_log_method("debug", "DEBUG")
end

function M.uninstall_hooks()
	for name, original in pairs(log_state.originals) do
		local crashify_name = string.match(name, "^Crashify%.(.+)$")
		if crashify_name then
			if Crashify then
				Crashify[crashify_name] = original
			end
		else
			_G[name] = original
		end
	end

	for name, original in pairs(log_state.dmf_originals) do
		if DMFMod then
			DMFMod[name] = original
		end
	end

	log_state.originals = {}
	log_state.dmf_originals = {}
end

function M.start_request(request_id)
	if request_id == nil then
		return {
			ok = false,
			error = "request.id must be a string",
		}
	end

	local now = current_time()
	prune_expired_sessions(now)

	log_state.sessions[request_id] = {
		last_poll_time = now,
		queue = {},
		dropped = 0,
	}

	return {
		id = request_id,
		ok = true,
		session = request_id,
	}
end

function M.poll_request(request_id, session_id)
	prune_expired_sessions(current_time())

	local session = log_state.sessions[session_id]
	if not session then
		return {
			id = request_id,
			ok = false,
			error = "logs session is not active",
		}
	end

	session.last_poll_time = current_time()

	local entries = {}
	for i = 1, #session.queue do
		entries[i] = session.queue[i]
		session.queue[i] = nil
	end

	local dropped = session.dropped
	session.dropped = 0

	local response = {
		id = request_id,
		ok = true,
		dropped = dropped,
	}

	if #entries > 0 then
		response.entries = entries
	end

	return response
end

function M.stop_request(request_id, session_id)
	log_state.sessions[session_id] = nil

	return {
		id = request_id,
		ok = true,
	}
end

return M
