local mod = get_mod("Realms")

local MAX_ARGUMENTS = 32
local MAX_NAME_LENGTH = 64
local ROUTE_ERROR_MESSAGE_REJECTED = "message_rejected"
local ROUTE_ERROR_PEER_UNAVAILABLE = "target_peer_unavailable"
local ROUTE_ERROR_RPC_UNSUPPORTED = "target_rpc_unsupported"

local state = mod:persistent_table("mod_network")
state.registrations = state.registrations or {}

local ModNetwork = {}
local GameplayControl
local remote_capabilities = {}

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function local_peer_id()
	local peer_id = Network.peer_id()

	return peer_id and normalize_peer_id(peer_id) or nil
end

local function valid_name(value)
	return type(value) == "string" and #value > 0 and #value <= MAX_NAME_LENGTH
end

local function owner_name(owner_mod)
	if type(owner_mod) ~= "table"
		or type(owner_mod.get_name) ~= "function"
		or type(owner_mod.is_enabled) ~= "function"
		or type(owner_mod.pcall) ~= "function"
	then
		return nil, "Network owner must be a DMF mod"
	end

	local name = owner_mod:get_name()

	if not valid_name(name) then
		return nil, "Network owner name is invalid"
	end

	return name
end

local function pack_arguments(...)
	local count = select("#", ...)

	if count > MAX_ARGUMENTS then
		return nil, string.format("Network call exceeds the %d argument limit", MAX_ARGUMENTS)
	end

	local values = { ... }

	for i = 1, count do
		if values[i] == nil then
			values[i] = cjson.null
		end
	end

	return {
		count = count,
		values = values,
	}
end

local function unpack_arguments(arguments)
	local packed_values = arguments.values
	local count = arguments.count
	local values = {}

	for i = 1, count do
		if packed_values[i] == cjson.null then
			values[i] = nil
		else
			values[i] = packed_values[i]
		end
	end

	return values, count
end

local function registration(mod_name, rpc_name)
	local mod_registrations = state.registrations[mod_name]

	return mod_registrations and mod_registrations[rpc_name] or nil
end

local function dispatch(mod_name, rpc_name, sender_peer_id, arguments)
	local rpc_registration = registration(mod_name, rpc_name)

	if not rpc_registration or not rpc_registration.owner:is_enabled() then
		return true
	end

	local values, count = unpack_arguments(arguments)

	rpc_registration.owner:pcall(rpc_registration.callback, sender_peer_id, unpack(values, 1, count))

	return true
end

local function delivery(mod_name, rpc_name, sender_peer_id, arguments)
	return {
		arguments = arguments,
		mod_name = mod_name,
		rpc_name = rpc_name,
		sender_peer_id = sender_peer_id,
	}
end

local function manifest()
	local result = {}

	for mod_name, registrations in pairs(state.registrations) do
		local rpc_names = table.keys(registrations)

		table.sort(rpc_names)
		result[mod_name] = rpc_names
	end

	return result
end

local function store_manifest(peer_id, rpc_manifest)
	local capabilities = {}

	for mod_name, rpc_names in pairs(rpc_manifest) do
		local registered_rpcs = {}

		for i = 1, #rpc_names do
			registered_rpcs[rpc_names[i]] = true
		end

		capabilities[mod_name] = registered_rpcs
	end

	remote_capabilities[normalize_peer_id(peer_id)] = capabilities
end

local function supports(peer_id, mod_name, rpc_name)
	local capabilities = remote_capabilities[normalize_peer_id(peer_id)]
	local registered_rpcs = capabilities and capabilities[mod_name]

	return registered_rpcs and registered_rpcs[rpc_name] == true or false
end

local function publish_manifest()
	if not GameplayControl or not GameplayControl.is_available() then
		return true
	end

	local data = {
		rpcs = manifest(),
	}
	local connection = Managers.connection

	if connection and connection:is_host() then
		return GameplayControl.send_to_clients("mod_network_manifest", data)
	end
	if connection and connection:is_client() then
		return GameplayControl.send_to_host("mod_network_manifest", data)
	end

	return false, "Realms network session is unavailable"
end

local function send_manifest(channel_id, role)
	local data = {
		rpcs = manifest(),
	}

	if role == "host" then
		return GameplayControl.send_to_client(channel_id, "mod_network_manifest", data)
	end

	return GameplayControl.send_to_host("mod_network_manifest", data)
end

local function send_route_error(channel_id, data, reason)
	local sent, send_error = GameplayControl.send_to_client(channel_id, "mod_network_error", {
		mod_name = data.mod_name,
		reason = reason,
		rpc_name = data.rpc_name,
	})

	if not sent then
		mod:info("Could not report network route error to peer: %s", send_error)
	end
end

local function send_to_peer(peer_id, mod_name, rpc_name, sender_peer_id, arguments)
	if not GameplayControl.is_peer_available(peer_id) then
		return false, ROUTE_ERROR_PEER_UNAVAILABLE
	end
	if not supports(peer_id, mod_name, rpc_name) then
		return false, ROUTE_ERROR_RPC_UNSUPPORTED
	end

	local sent, send_error = GameplayControl.send_to_peer(
		peer_id,
		"mod_network_delivery",
		delivery(mod_name, rpc_name, sender_peer_id, arguments)
	)

	if not sent and not GameplayControl.is_peer_available(peer_id) then
		return false, ROUTE_ERROR_PEER_UNAVAILABLE
	end

	return sent, send_error
end

local function send_to_capable_clients(mod_name, rpc_name, sender_peer_id, arguments, excluded_peer_id)
	local peer_ids = GameplayControl.ready_peer_ids()

	excluded_peer_id = excluded_peer_id and normalize_peer_id(excluded_peer_id) or nil

	for i = 1, #peer_ids do
		local peer_id = peer_ids[i]

		if peer_id ~= excluded_peer_id and supports(peer_id, mod_name, rpc_name) then
			local sent, send_error = send_to_peer(peer_id, mod_name, rpc_name, sender_peer_id, arguments)

			if not sent then
				mod:info("Network RPC %s.%s skipped peer %s: %s", mod_name, rpc_name, peer_id, send_error)
			end
		end
	end

	return true
end

local function receive_manifest(channel_id, sender_peer_id, data)
	store_manifest(sender_peer_id, data.rpcs)

	return true
end

local function receive_host_request(channel_id, sender_peer_id, data)
	local recipient = data.recipient
	local self_peer_id = local_peer_id()

	if recipient == "local" then
		return false, "Remote network requests cannot target local"
	end
	if recipient == "all" or recipient == "others" then
		if registration(data.mod_name, data.rpc_name) then
			dispatch(data.mod_name, data.rpc_name, sender_peer_id, data.arguments)
		end

		local excluded_peer_id = recipient == "others" and sender_peer_id or nil

		return send_to_capable_clients(
			data.mod_name,
			data.rpc_name,
			sender_peer_id,
			data.arguments,
			excluded_peer_id
		)
	end
	if recipient == self_peer_id then
		if not registration(data.mod_name, data.rpc_name) then
			send_route_error(channel_id, data, ROUTE_ERROR_RPC_UNSUPPORTED)

			return true
		end

		return dispatch(data.mod_name, data.rpc_name, sender_peer_id, data.arguments)
	end

	local sent, send_error = send_to_peer(
		recipient,
		data.mod_name,
		data.rpc_name,
		sender_peer_id,
		data.arguments
	)

	if not sent then
		local route_error = send_error

		if route_error ~= ROUTE_ERROR_PEER_UNAVAILABLE and route_error ~= ROUTE_ERROR_RPC_UNSUPPORTED then
			route_error = ROUTE_ERROR_MESSAGE_REJECTED
			mod:info("Network RPC %s.%s could not be delivered: %s", data.mod_name, data.rpc_name, send_error)
		end

		send_route_error(channel_id, data, route_error)
	end

	return true
end

local function receive_client_delivery(channel_id, sender_peer_id, data)
	return dispatch(data.mod_name, data.rpc_name, data.sender_peer_id, data.arguments)
end

local function receive_client_error(channel_id, sender_peer_id, data)
	local rpc_registration = registration(data.mod_name, data.rpc_name)

	if rpc_registration and rpc_registration.owner:is_enabled() then
		rpc_registration.owner:info("Network RPC %s could not be routed: %s", data.rpc_name, data.reason)
	end

	return true
end

function ModNetwork.install(gameplay_control)
	GameplayControl = gameplay_control

	GameplayControl.register_host_handler("mod_network_manifest", receive_manifest)
	GameplayControl.register_host_handler("mod_network_request", receive_host_request)
	GameplayControl.register_client_handler("mod_network_delivery", receive_client_delivery)
	GameplayControl.register_client_handler("mod_network_error", receive_client_error)
	GameplayControl.register_client_handler("mod_network_manifest", receive_manifest)
	GameplayControl.register_disconnect_handler("mod_network", function (peer_id)
		remote_capabilities[normalize_peer_id(peer_id)] = nil
	end)
	GameplayControl.register_ready_handler("mod_network", function (channel_id, peer_id, role)
		return send_manifest(channel_id, role)
	end)
end

function ModNetwork.is_available()
	if not GameplayControl.is_available() then
		return false
	end

	local connection = Managers.connection

	if connection and connection:is_client() then
		return remote_capabilities[normalize_peer_id(connection:host())] ~= nil
	end

	return true
end

function ModNetwork.register(owner_mod, rpc_name, callback)
	local mod_name, owner_error = owner_name(owner_mod)

	if not mod_name then
		return false, owner_error
	end
	if not valid_name(rpc_name) then
		return false, "Network RPC name is invalid"
	end
	if type(callback) ~= "function" then
		return false, "Network RPC callback must be a function"
	end

	state.registrations[mod_name] = state.registrations[mod_name] or {}
	state.registrations[mod_name][rpc_name] = {
		callback = callback,
		owner = owner_mod,
	}

	local published, publish_error = publish_manifest()

	if not published then
		mod:info("Could not publish the updated mod network manifest: %s", publish_error)
	end

	return true
end

function ModNetwork.send(owner_mod, rpc_name, recipient, ...)
	local mod_name, owner_error = owner_name(owner_mod)

	if not mod_name then
		return false, owner_error
	end
	if not registration(mod_name, rpc_name) then
		return false, "Attempted to send an unregistered network RPC"
	end
	if type(recipient) ~= "string" or recipient == "" then
		return false, "Network recipient must be all, local, others, or a peer id"
	end

	local arguments, arguments_error = pack_arguments(...)

	if not arguments then
		return false, arguments_error
	end

	local sender_peer_id = local_peer_id()

	if not sender_peer_id then
		return false, "Local peer id is unavailable"
	end

	local normalized_recipient = recipient

	if recipient ~= "all" and recipient ~= "local" and recipient ~= "others" then
		normalized_recipient = normalize_peer_id(recipient)
	end
	if normalized_recipient == "local" or normalized_recipient == sender_peer_id then
		return dispatch(mod_name, rpc_name, sender_peer_id, arguments)
	end

	local connection = Managers.connection

	if connection and connection:is_host() then
		if normalized_recipient == "all" then
			dispatch(mod_name, rpc_name, sender_peer_id, arguments)

			return send_to_capable_clients(mod_name, rpc_name, sender_peer_id, arguments)
		end
		if normalized_recipient == "others" then
			return send_to_capable_clients(mod_name, rpc_name, sender_peer_id, arguments)
		end

		return send_to_peer(normalized_recipient, mod_name, rpc_name, sender_peer_id, arguments)
	end
	if not connection or not connection:is_client() or not ModNetwork.is_available() then
		return false, "Realms network session is unavailable"
	end

	local host_peer_id = normalize_peer_id(connection:host())

	if normalized_recipient == host_peer_id and not supports(host_peer_id, mod_name, rpc_name) then
		return false, ROUTE_ERROR_RPC_UNSUPPORTED
	end
	if normalized_recipient == "all" then
		dispatch(mod_name, rpc_name, sender_peer_id, arguments)
		normalized_recipient = "others"
	end

	return GameplayControl.send_to_host("mod_network_request", {
		arguments = arguments,
		mod_name = mod_name,
		recipient = normalized_recipient,
		rpc_name = rpc_name,
	})
end

return ModNetwork
