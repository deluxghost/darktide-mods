# Realms Integration

This documentation reflects the current behavior and is not guaranteed to remain unchanged.

## Detecting the Session and Role

Realms uses Darktide's player-hosted session type:

```lua
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local HOST_TYPES = MatchmakingConstants.HOST_TYPES

local function is_realms_session()
	local multiplayer_session = Managers.multiplayer_session

	return multiplayer_session
		and multiplayer_session:host_type() == HOST_TYPES.player
		or false
end

local function is_realms_host()
	local connection = Managers.connection

	return is_realms_session() and connection and connection:is_host() or false
end

local function is_realms_client()
	local connection = Managers.connection

	return is_realms_session() and connection and connection:is_client() or false
end
```

Use `Managers.connection` to determine the connection role. For authoritative gameplay logic, also require an active game session for which `game_session:is_server()` returns `true`. The game-session manager may be absent during setup, loading, or teardown.

## Network API

The optional API sends named messages between mods over an active Realms session. Each receiving peer must have the same mod enabled and register the same RPC name.

Get the Realms mod object and register RPCs in `on_all_mods_loaded`. Registration does not require an active session. Messages can be sent only when `network_is_available()` returns `true`. The API remains available during preparation, loading, gameplay, and end-of-round while the Realms session remains connected. A callback can therefore run when `Managers.state.game_session` is absent; mods must check any game-state APIs they use.

### `network_register`

```lua
local registered, register_error = realms.network_register(mod, rpc_name, callback)
```

Registers an RPC in the calling DMF mod's namespace. The callback receives the sender peer ID followed by the message arguments:

```lua
callback(sender_peer_id, ...)
```

Returns `true` on success or `false, error_message` when the arguments are invalid. Validate all received arguments.

### `network_is_available`

```lua
local available = realms.network_is_available()
```

Returns `true` when the Realms session-control channel and peer capability exchange are ready.

### `network_send`

```lua
local sent, send_error = realms.network_send(mod, rpc_name, recipient, ...)
```

The RPC must be registered locally before it can be sent. Recipient values are:

- `"local"`: only the sender.
- `"host"`: the session host. On the host, this targets the sender itself.
- `"all"`: the sender and every capable peer.
- `"others"`: every capable peer except the sender.
- A peer ID: that peer only. The host routes client-to-client messages.

A capable peer is one that has the same mod enabled and has registered that RPC. Broadcasts skip incapable peers. Direct sends to an unavailable or incapable peer fail.

A `true` result means that Realms accepted the message for dispatch, not that the remote callback completed. Use a reply RPC when an acknowledgment is required.

Arguments must be JSON-serializable. Top-level `nil` arguments are preserved. Each call supports up to 32 arguments and a maximum encoded size of 96 KiB.

Peer callback registration returns `true` or `false, error_message`. Registering the same callback type again replaces the calling mod's previous callback.

### `network_on_peer_joined`

```lua
local registered, register_error = realms.network_on_peer_joined(mod, callback)
```

Registers a callback when a remote peer becomes available to Realms message routing:

```lua
callback(peer_id)
```

Existing peers are reported immediately. Every node observes the host and all other clients, but never itself. Register RPCs before registering this callback.

### `network_on_peer_left`

```lua
local registered, register_error = realms.network_on_peer_left(mod, callback)
```

Registers a callback for remote peers leaving. Every remaining node receives the departed peer ID, which is no longer a valid `network_send` recipient.

## Mission Transition API

### `queue_mission_transition`

```lua
local queued, queue_error = realms.queue_mission_transition(mod, mission_context)
```

Queues the next mission while hosting an active Realms gameplay session. Pass the mission context used by `Managers.mechanism:change_mechanism`; it must contain a valid `mission_name`.

Connected peers remain in the Realms session. The next mission follows the normal Realms preparation rules; retained peers do not trigger join or leave callbacks.

Only the host can queue a transition, and only one can be pending. Returns `true` when accepted or `false, error_message` otherwise.

Start the first local mission normally; use this API only to continue an existing Realms session.

## Example

This entry file registers one RPC. The host sends a string to all capable clients, while a client sends it to the host.

```lua
local mod = get_mod("ExampleMod")

local RPC_MESSAGE = "rpc_my_mod_message"

local realms

local function on_message(sender_peer_id, message)
	mod:info("%s: %s", sender_peer_id, message)
end

mod.on_all_mods_loaded = function ()
	realms = get_mod("Realms")

	if not realms then
		return
	end

	local registered, register_error = realms.network_register(mod, RPC_MESSAGE, on_message)

	if not registered then
		mod:error("Failed registering %s: %s", RPC_MESSAGE, register_error)
	end
end

mod.send_message = function (message)
	if not realms or not realms.network_is_available() then
		return false, "Realms network is unavailable"
	end

	local connection = Managers.connection

	if connection:is_host() then
		return realms.network_send(mod, RPC_MESSAGE, "others", message)
	end

	return realms.network_send(mod, RPC_MESSAGE, "host", message)
end
```
