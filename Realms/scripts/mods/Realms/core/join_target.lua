local mod = get_mod("Realms")

local JoinTarget = {}

function JoinTarget.parse(value)
	if type(value) ~= "string" or value == "" or string.find(value, "%s") then
		return nil, nil, mod:localize("error_join_target_format")
	end

	local address
	local port_text

	if string.sub(value, 1, 1) == "[" then
		address, port_text = string.match(value, "^%[([^%[%]]+)%]:([^:]+)$")
	else
		address, port_text = string.match(value, "^([^:]+):([^:]+)$")
	end

	if not address or address == "" or not port_text or port_text == "" then
		return nil, nil, mod:localize("error_join_target_format")
	end

	local port = string.match(port_text, "^%d+$") and tonumber(port_text) or nil

	if not port or port % 1 ~= 0 or port < 1 or port > 65535 then
		return nil, nil, mod:localize("error_server_port_invalid")
	end

	return address, port
end

return JoinTarget