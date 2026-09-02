local mod = get_mod("Realms")
local NetworkEventDelegate = require("scripts/managers/multiplayer/network_event_delegate")

local UnitRpcLifetime = {}
local Session

local function guard_callback(delegate, callback_name)
	local object_table = delegate._registered_unit_objects[callback_name]
	local original_callback = rawget(delegate.event_table, callback_name)

	if not object_table or not original_callback then
		return
	end

	local guards = delegate._realms_unit_rpc_guards

	if not guards then
		guards = {}
		delegate._realms_unit_rpc_guards = guards
	elseif guards[callback_name] and guards[callback_name].callback == original_callback then
		return
	end

	local function callback(event_table, sender, unit_id, ...)
		local registered_objects = delegate._registered_unit_objects[callback_name]

		if registered_objects and registered_objects[unit_id] then
			return original_callback(event_table, sender, unit_id, ...)
		end
		if not Session.is_active() then
			return original_callback(event_table, sender, unit_id, ...)
		end

		-- The Realms transport can deliver a reliable unit RPC after its recipient was destroyed.
		mod:info("Ignored late unit RPC %s for deleted unit id=%s", callback_name, tostring(unit_id))
	end

	guards[callback_name] = {
		callback = callback,
		original_callback = original_callback,
	}
	delegate.event_table[callback_name] = callback
end

function UnitRpcLifetime.install(session)
	Session = session

	mod:hook(NetworkEventDelegate, "register_session_unit_events", function (func, self, object, unit_id, ...)
		func(self, object, unit_id, ...)

		for i = 1, select("#", ...) do
			guard_callback(self, select(i, ...))
		end
	end)
end

return UnitRpcLifetime
