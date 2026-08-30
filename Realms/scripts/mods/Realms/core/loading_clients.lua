local mod = get_mod("Realms")
local LoadingManager = require("scripts/managers/loading/loading_manager")
local SpawnQueue = require("scripts/loading/spawn_queue")

local LoadingClients = {}
local state = mod:persistent_table("loading_clients")
local barriers = setmetatable({}, {
	__mode = "k",
})

state.deferred_channels = state.deferred_channels or {}

local function should_defer(Session, Preparation, loading_manager, channel_id)
	local phase = Preparation.phase()

	return Session.is_active_host()
		and Session.is_host_channel(channel_id)
		and (phase == "waiting" or phase == "started")
		and loading_manager:mission() == nil
end

local function clear_barrier(loading_manager)
	local loading_host = loading_manager._loading_host

	if loading_host then
		barriers[loading_host._spawn_queue] = nil
	end
end

local function remove_barrier_channel(loading_manager, channel_id)
	local loading_host = loading_manager._loading_host
	local barrier = loading_host and barriers[loading_host._spawn_queue]
	local peer_id = barrier and barrier.channel_peers[channel_id]

	if peer_id then
		barrier.channel_peers[channel_id] = nil
		barrier.expected_peers[peer_id] = nil
	end
end

function LoadingClients.install(Session, Preparation)
	mod:hook(SpawnQueue, "place_in_queue", function (func, self, peer_id, callback)
		local result = func(self, peer_id, callback)
		local barrier = barriers[self]

		if barrier then
			barrier.waiting_peers[peer_id] = true
		end

		return result
	end)

	mod:hook(SpawnQueue, "remove_from_queue", function (func, self, peer_id)
		local barrier = barriers[self]

		if barrier then
			barrier.waiting_peers[peer_id] = nil
		end

		return func(self, peer_id)
	end)

	mod:hook(SpawnQueue, "ready_group", function (func, self)
		local barrier = barriers[self]

		if barrier then
			for peer_id in pairs(barrier.expected_peers) do
				if not barrier.waiting_peers[peer_id] then
					return nil
				end
			end

			mod:info("All %d preparation clients joined the initial spawn group", table.size(barrier.expected_peers))
			barriers[self] = nil
		end

		return func(self)
	end)

	mod:hook(LoadingManager, "add_client", function (func, self, channel_id)
		if should_defer(Session, Preparation, self, channel_id) then
			state.deferred_channels[channel_id] = true
			mod:info("Deferred loading client channel=%d until mission loading starts", channel_id)
			return
		end

		return func(self, channel_id)
	end)

	mod:hook(LoadingManager, "remove_client", function (func, self, channel_id)
		if state.deferred_channels[channel_id] then
			state.deferred_channels[channel_id] = nil
			mod:info("Removed deferred loading client channel=%d", channel_id)
			return
		end

		remove_barrier_channel(self, channel_id)

		return func(self, channel_id)
	end)

	mod:hook(LoadingManager, "load_mission", function (func, self, loading_context)
		local result = func(self, loading_context)

		if not Session.is_active_host() then
			return result
		end

		local channel_ids = table.keys(state.deferred_channels)
		local loading_host = self._loading_host
		local spawn_queue = loading_host and loading_host._spawn_queue
		local barrier = {
			channel_peers = {},
			expected_peers = {},
			waiting_peers = {},
		}

		for i = 1, #channel_ids do
			local channel_id = channel_ids[i]

			state.deferred_channels[channel_id] = nil

			if Session.is_host_channel(channel_id) then
				local peer_id = Network.peer_id(channel_id)

				barrier.channel_peers[channel_id] = peer_id
				barrier.expected_peers[peer_id] = true
				self:add_client(channel_id)
				mod:info("Added deferred loading client channel=%d", channel_id)
			end
		end

		if spawn_queue and not table.is_empty(barrier.expected_peers) then
			barriers[spawn_queue] = barrier
			mod:info("Waiting for %d preparation clients to join the initial spawn group", table.size(barrier.expected_peers))
		end

		return result
	end)

	mod:hook(LoadingManager, "stop_load_mission", function (func, self)
		clear_barrier(self)

		return func(self)
	end)

	mod:hook(LoadingManager, "cleanup", function (func, self)
		clear_barrier(self)
		func(self)
		table.clear(state.deferred_channels)
	end)
end

return LoadingClients
