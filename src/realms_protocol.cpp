#include "realms_internal.h"

#include <algorithm>
#include <cstring>
#include <iterator>
#include <mutex>

namespace realms {

bool append_bits(uint8_t *buffer, size_t capacity, size_t *bit_offset, uint64_t value, uint32_t bit_count) {
    if (buffer == nullptr || bit_offset == nullptr || bit_count > 64 || *bit_offset > capacity * 8 ||
        bit_count > capacity * 8 - *bit_offset) {
        return false;
    }

    for (uint32_t index = 0; index < bit_count; ++index) {
        if ((value & (uint64_t{1} << index)) != 0) {
            const size_t destination = *bit_offset + index;
            buffer[destination / 8] |= static_cast<uint8_t>(uint8_t{1} << (destination % 8));
        }
    }

    *bit_offset += bit_count;
    return true;
}

bool build_connect_reply_packet(uint64_t local_peer_id, uint64_t lobby_id, const char *local_account_id,
                                uint8_t *packet, size_t packet_capacity, int32_t *packet_size) {
    uint8_t payload[16]{};
    size_t payload_bits = 0;

    if (!append_bits(payload, sizeof(payload), &payload_bits, 1, 1) ||
        !append_bits(payload, sizeof(payload), &payload_bits, kConnectReplyMessage, 6) ||
        !append_bits(payload, sizeof(payload), &payload_bits, lobby_id, 64) ||
        !append_bits(payload, sizeof(payload), &payload_bits, 0, 1)) {
        return false;
    }

    const uint32_t payload_size = static_cast<uint32_t>((payload_bits + 7) / 8);
    uint32_t payload_size_bits = 0;

    for (uint32_t value = payload_size; value != 0; value >>= 1) {
        ++payload_size_bits;
    }

    std::memset(packet, 0, packet_capacity);
    size_t packet_bits = 0;

    if (!append_bits(packet, packet_capacity, &packet_bits, kWireProtocol, 16) ||
        !append_bits(packet, packet_capacity, &packet_bits, 0, 24) ||
        !append_bits(packet, packet_capacity, &packet_bits, local_peer_id, 64) || local_account_id == nullptr ||
        packet_bits > packet_capacity * 8 - kWireAddressSize * 8) {
        return false;
    }

    std::memcpy(packet + packet_bits / 8, local_account_id, kWireAddressSize);
    packet_bits += kWireAddressSize * 8;

    if (!append_bits(packet, packet_capacity, &packet_bits, kLobbySystem, 4) ||
        !append_bits(packet, packet_capacity, &packet_bits, 0, 8) ||
        !append_bits(packet, packet_capacity, &packet_bits, payload_size_bits, 4) ||
        !append_bits(packet, packet_capacity, &packet_bits, payload_size, payload_size_bits)) {
        return false;
    }

    packet_bits = (packet_bits + 7) & ~size_t{7};
    const size_t packet_bytes = packet_bits / 8;

    if (packet_bytes > packet_capacity || payload_size > packet_capacity - packet_bytes) {
        return false;
    }

    std::memcpy(packet + packet_bytes, payload, payload_size);
    *packet_size = static_cast<int32_t>(packet_bytes + payload_size);
    return true;
}

int resolve_peer_reply_route(void *connection, uint64_t peer_id, void **transport_out = nullptr,
                             const sockaddr **route_out = nullptr) {
    if (transport_out != nullptr) {
        *transport_out = nullptr;
    }
    if (route_out != nullptr) {
        *route_out = nullptr;
    }

    if (connection == nullptr || peer_id == 0) {
        return 1;
    }

    const uint8_t *transport_location = static_cast<const uint8_t *>(connection) + kConnectionWanTransportOffset;

    if (!dtintutils_is_readable_range(transport_location, sizeof(void *))) {
        return 2;
    }

    void *transport = nullptr;
    std::memcpy(&transport, transport_location, sizeof(transport));

    if (transport == nullptr) {
        return 3;
    }

    const uint8_t *route_header = static_cast<const uint8_t *>(transport) + kPeerRouteCountOffset;

    if (!dtintutils_is_readable_range(route_header, sizeof(uint32_t) * 2 + sizeof(void *))) {
        return 4;
    }

    uint32_t route_count = 0;
    uint32_t route_capacity = 0;
    const uint8_t *route_entries = nullptr;
    std::memcpy(&route_count, static_cast<const uint8_t *>(transport) + kPeerRouteCountOffset, sizeof(route_count));
    std::memcpy(&route_capacity, static_cast<const uint8_t *>(transport) + kPeerRouteCapacityOffset,
                sizeof(route_capacity));
    std::memcpy(&route_entries, static_cast<const uint8_t *>(transport) + kPeerRouteEntriesOffset,
                sizeof(route_entries));
    if (route_count > route_capacity || route_count > 0x10000 || (route_count != 0 && route_entries == nullptr)) {
        return 5;
    }

    for (uint32_t index = 0; index < route_count; ++index) {
        const uint8_t *entry = route_entries + static_cast<size_t>(index) * kPeerRouteEntrySize;

        if (!dtintutils_is_readable_range(entry, kPeerRouteEntrySize)) {
            return 6;
        }

        uint64_t mapped_peer_id = 0;
        std::memcpy(&mapped_peer_id, entry, sizeof(mapped_peer_id));

        if (mapped_peer_id != peer_id) {
            continue;
        }

        const sockaddr *route = reinterpret_cast<const sockaddr *>(entry + kPeerRouteAddressOffset);
        if (route->sa_family != AF_INET6 && route->sa_family != AF_INET) {
            return 8;
        }

        if (transport_out != nullptr) {
            *transport_out = transport;
        }
        if (route_out != nullptr) {
            *route_out = route;
        }
        return 0;
    }

    return 7;
}

int send_connect_reply(void *connection, uint64_t peer_id) {
    if (connection == nullptr || connection != g_expected_connection || g_send_address == nullptr) {
        return 1;
    }

    const auto *local_peer_location = static_cast<const uint8_t *>(connection) + kLocalPeerIdOffset;

    if (!dtintutils_is_readable_range(local_peer_location, sizeof(uint64_t))) {
        return 2;
    }

    uint64_t local_peer_id = 0;
    std::memcpy(&local_peer_id, local_peer_location, sizeof(local_peer_id));

    if (local_peer_id == 0) {
        return 3;
    }

    uint8_t packet[kMaximumWirePacketSize]{};
    int32_t packet_size = 0;

    if (!build_connect_reply_packet(local_peer_id, local_peer_id, g_local_account_id, packet, sizeof(packet),
                                    &packet_size)) {
        return 4;
    }

    void *transport = nullptr;
    const sockaddr *route = nullptr;

    if (resolve_peer_reply_route(connection, peer_id, &transport, &route) != 0) {
        return 5;
    }
    if (g_send_address(transport, route, packet, packet_size) <= 0) {
        return 6;
    }

    return 0;
}

bool reader_succeeded(void *reader) {
    return reader != nullptr && dtintutils_is_readable_range(reader, 24) &&
           static_cast<const int32_t *>(reader)[5] == 0;
}

uint32_t read_unsigned_bits(void *reader, uint32_t bit_count) {
    return static_cast<uint32_t>(g_read_bits(static_cast<int32_t *>(reader), bit_count));
}

bool read_create_channel_message(void *reader, uint32_t *remote_channel_id, uint64_t *lobby_id,
                                 uint8_t *approve_message, uint32_t *approve_message_size, bool *has_approve_message) {
    if (reader == nullptr || remote_channel_id == nullptr || lobby_id == nullptr || approve_message == nullptr ||
        approve_message_size == nullptr || has_approve_message == nullptr || g_read_bits == nullptr) {
        return false;
    }

    *remote_channel_id = read_unsigned_bits(reader, 8);
    const uint64_t lobby_low = read_unsigned_bits(reader, 32);
    const uint64_t lobby_high = read_unsigned_bits(reader, 32);
    *lobby_id = lobby_low | (lobby_high << 32);
    *has_approve_message = read_unsigned_bits(reader, 1) != 0;
    const uint32_t length_bit_count = read_unsigned_bits(reader, 4);

    if (length_bit_count > 31) {
        return false;
    }

    const uint32_t message_size = read_unsigned_bits(reader, length_bit_count);

    if (message_size > kMaximumApproveMessageSize) {
        return false;
    }

    for (uint32_t index = 0; index < message_size; ++index) {
        approve_message[index] = static_cast<uint8_t>(read_unsigned_bits(reader, 8));
    }

    if (!reader_succeeded(reader)) {
        return false;
    }

    *approve_message_size = message_size;
    return true;
}

bool read_join_request(void *reader, uint64_t *lobby_id, uint16_t *port) {
    if (reader == nullptr || lobby_id == nullptr || port == nullptr || g_read_bits == nullptr) {
        return false;
    }

    const uint64_t lobby_low = read_unsigned_bits(reader, 32);
    const uint64_t lobby_high = read_unsigned_bits(reader, 32);
    *lobby_id = lobby_low | (lobby_high << 32);
    *port = static_cast<uint16_t>(read_unsigned_bits(reader, 16));
    return reader_succeeded(reader);
}

bool lobby_contains_peer(void *lobby, uint64_t peer_id) {
    if (lobby == nullptr || !dtintutils_is_readable_range(lobby, kLanLobbySize)) {
        return false;
    }

    const auto *bytes = static_cast<const uint8_t *>(lobby);
    uint32_t count = 0;
    const uint8_t *members = nullptr;
    std::memcpy(&count, bytes + kLanLobbyMemberCountOffset, sizeof(count));
    std::memcpy(&members, bytes + kLanLobbyMembersOffset, sizeof(members));

    if (count == 0 || count > 64 || members == nullptr ||
        !dtintutils_is_readable_range(members, static_cast<size_t>(count) * kLanLobbyMemberSize)) {
        return false;
    }

    for (uint32_t index = 0; index < count; ++index) {
        uint64_t member_peer_id = 0;
        std::memcpy(&member_peer_id, members + static_cast<size_t>(index) * kLanLobbyMemberSize,
                    sizeof(member_peer_id));

        if (member_peer_id == peer_id) {
            return true;
        }
    }

    return false;
}

bool add_lobby_member(void *lobby, uint64_t peer_id, uint16_t port, uint32_t channel_id) {
    if (lobby == nullptr || peer_id == 0 || g_add_lobby_member == nullptr || g_destroy_lobby_member == nullptr) {
        return false;
    }

    alignas(8) uint8_t member[kLanLobbyMemberSize]{};
    void *allocator = static_cast<uint8_t *>(lobby) + 8;
    std::memcpy(member, &peer_id, sizeof(peer_id));
    std::memcpy(member + kLanLobbyMemberChannelOffset, &channel_id, sizeof(channel_id));
    std::memcpy(member + kLanLobbyMemberAllocatorOffset, &allocator, sizeof(allocator));
    std::memcpy(member + kLanLobbyMemberAllocatorMirrorOffset, &allocator, sizeof(allocator));
    const uint64_t added = g_add_lobby_member(lobby, member, port);
    g_destroy_lobby_member(member);
    return added != 0;
}

bool send_join_reply(void *connection, uint32_t channel_id, bool allowed) {
    uint8_t payload[1]{};
    size_t payload_bits = 0;

    if (connection == nullptr || channel_id == 0 || g_send_channel == nullptr ||
        !append_bits(payload, sizeof(payload), &payload_bits, kJoinReplyMessage, 6) ||
        !append_bits(payload, sizeof(payload), &payload_bits, allowed ? 1 : 0, 1)) {
        return false;
    }

    const uint64_t result =
        g_send_channel(connection, channel_id, kLobbySystem, 1, payload, static_cast<uint32_t>(payload_bits), 0);
    return static_cast<uint8_t>(result) != 0;
}

HostPeerSlot *find_host_peer_slot(uint64_t peer_id) {
    if (peer_id == 0) {
        return nullptr;
    }

    for (HostPeerSlot &slot : g_host_peer_slots) {
        if (slot.peer_id.load(std::memory_order_acquire) == peer_id) {
            return &slot;
        }
    }

    return nullptr;
}

HostPeerSlot *claim_host_peer_slot(uint64_t peer_id) {
    std::lock_guard<std::mutex> lock(g_host_peer_slots_mutex);
    HostPeerSlot *empty_slot = nullptr;

    for (HostPeerSlot &slot : g_host_peer_slots) {
        const uint64_t current_peer = slot.peer_id.load(std::memory_order_relaxed);

        if (current_peer == peer_id) {
            slot.last_activity_tick.store(GetTickCount64(), std::memory_order_relaxed);
            return &slot;
        }
        if (current_peer == 0 && empty_slot == nullptr) {
            empty_slot = &slot;
        }
    }

    if (empty_slot == nullptr) {
        return nullptr;
    }

    empty_slot->last_activity_tick.store(GetTickCount64(), std::memory_order_relaxed);
    empty_slot->adopted.store(false, std::memory_order_relaxed);
    empty_slot->peer_id.store(peer_id, std::memory_order_release);
    return empty_slot;
}

void clear_host_peer_slot(HostPeerSlot &slot) {
    slot.last_activity_tick.store(0, std::memory_order_relaxed);
    slot.peer_listener_token.store(0, std::memory_order_relaxed);
    slot.channel_listener_token.store(0, std::memory_order_relaxed);
    slot.channel_id.store(0, std::memory_order_relaxed);
    slot.adopted.store(false, std::memory_order_relaxed);
    slot.peer_listener_registered.store(false, std::memory_order_relaxed);
    slot.channel_listener_registered.store(false, std::memory_order_relaxed);
    slot.peer_id.store(0, std::memory_order_release);
}

uint64_t __fastcall host_lobby_channel_callback(void *context, uint64_t, uint64_t peer_id, uint64_t, uint64_t, uint64_t,
                                                int32_t message_id, void *reader) {
    auto *slot = static_cast<HostPeerSlot *>(context);
    void *lobby = g_host_lobby.load(std::memory_order_acquire);
    if (slot == nullptr || lobby == nullptr || peer_id != slot->peer_id.load(std::memory_order_acquire) ||
        !g_local_session_active.load(std::memory_order_acquire)) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_INVALID_CALLBACK_STATE, peer_id, 0,
                           "Join request arrived with invalid local-session callback state");
        return 1;
    }
    if (message_id != static_cast<int32_t>(kRequestJoinMessage)) {
        return 0;
    }

    slot->last_activity_tick.store(GetTickCount64(), std::memory_order_relaxed);

    uint64_t requested_lobby_id = 0;
    uint16_t peer_port = 0;
    const uint32_t channel_id = slot->channel_id.load(std::memory_order_acquire);

    if (!read_join_request(reader, &requested_lobby_id, &peer_port)) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_PACKET_DECODE, peer_id, channel_id,
                           "Could not decode the lobby join request");
        return 2;
    }

    const uint64_t host_lobby_id = g_host_lobby_id.load(std::memory_order_acquire);
    bool allowed = requested_lobby_id == host_lobby_id && channel_id != 0;
    RealmsRuntimeEventCode rejection_code = REALMS_RUNTIME_EVENT_CODE_NONE;
    const char *rejection_message = "";

    if (requested_lobby_id != host_lobby_id || channel_id == 0) {
        rejection_code = REALMS_RUNTIME_REJECT_LOBBY;
        rejection_message = "Peer requested a different or invalid local session";
    }

    if (allowed && !lobby_contains_peer(lobby, peer_id)) {
        uint32_t member_count = 0;
        uint32_t max_members = 0;
        const auto *bytes = static_cast<const uint8_t *>(lobby);
        std::memcpy(&member_count, bytes + kLanLobbyMemberCountOffset, sizeof(member_count));
        std::memcpy(&max_members, bytes + kLanLobbyMaxMembersOffset, sizeof(max_members));
        if (member_count >= max_members) {
            allowed = false;
            rejection_code = REALMS_RUNTIME_REJECT_CAPACITY;
            rejection_message = "Local session has reached its member limit";
        } else if (!add_lobby_member(lobby, peer_id, peer_port, channel_id)) {
            allowed = false;
            push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_MEMBER_ADD, peer_id, channel_id,
                               "Darktide rejected the new lobby member");
        }
    }

    if (!send_join_reply(g_expected_connection, channel_id, allowed)) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_SEND, peer_id, channel_id,
                           "Could not send the lobby join reply");
    }

    if (!allowed) {
        if (rejection_code != REALMS_RUNTIME_EVENT_CODE_NONE) {
            push_runtime_event(REALMS_RUNTIME_EVENT_PEER_REJECTED, rejection_code, peer_id, channel_id,
                               rejection_message);
        }
        return 0;
    }

    push_runtime_event(REALMS_RUNTIME_EVENT_PEER_JOINED, REALMS_RUNTIME_EVENT_CODE_NONE, peer_id, channel_id,
                       "Peer joined the local session lobby");
    return 0;
}

uint64_t __fastcall host_lobby_peer_callback(void *context, uint64_t, uint64_t peer_id, uint64_t, uint64_t, uint64_t,
                                             int32_t message_id, void *reader) {
    auto *slot = static_cast<HostPeerSlot *>(context);
    void *lobby = g_host_lobby.load(std::memory_order_acquire);
    if (slot == nullptr || lobby == nullptr || peer_id != slot->peer_id.load(std::memory_order_acquire)) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_INVALID_CALLBACK_STATE, peer_id, 0,
                           "Lobby control message arrived with invalid peer callback state");
        return 1;
    }
    if (message_id != static_cast<int32_t>(kCreateChannelMessage)) {
        return 0;
    }

    slot->last_activity_tick.store(GetTickCount64(), std::memory_order_relaxed);

    uint32_t remote_channel_id = 0;
    uint64_t requested_lobby_id = 0;
    uint8_t approve_message[kMaximumApproveMessageSize]{};
    uint32_t approve_message_size = 0;
    bool has_approve_message = false;

    if (!read_create_channel_message(reader, &remote_channel_id, &requested_lobby_id, approve_message,
                                     &approve_message_size, &has_approve_message)) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_PACKET_DECODE, peer_id, 0,
                           "Could not decode the lobby control-channel request");
        return 2;
    }
    if (requested_lobby_id != g_host_lobby_id.load(std::memory_order_acquire)) {
        push_runtime_event(REALMS_RUNTIME_EVENT_PEER_REJECTED, REALMS_RUNTIME_REJECT_LOBBY, peer_id, 0,
                           "Peer requested a control channel for a different local session");
        return 0;
    }
    if (slot->channel_listener_registered.load(std::memory_order_acquire)) {
        return 0;
    }
    if (g_accept_channel == nullptr || g_register_channel_system_listener == nullptr) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_INVALID_CALLBACK_STATE, peer_id, 0,
                           "Darktide channel methods are unavailable");
        return 1;
    }

    uint32_t local_channel_id = 0;
    g_accept_channel(g_expected_connection, &local_channel_id, remote_channel_id, peer_id, kLobbyChannelType,
                     requested_lobby_id, has_approve_message ? approve_message : nullptr, approve_message_size);

    if (local_channel_id == 0) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_CHANNEL_ACCEPT, peer_id, 0,
                           "Darktide rejected the lobby control channel");
        return 0;
    }

    uint32_t listener_token = 0;
    g_register_channel_system_listener(g_expected_connection, &listener_token, kLobbySystem, local_channel_id,
                                       host_lobby_channel_callback, slot);

    if (listener_token == 0) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_LISTENER_REGISTRATION, peer_id,
                           local_channel_id, "Darktide did not register the lobby channel listener");
        return 0;
    }

    slot->channel_id.store(local_channel_id, std::memory_order_relaxed);
    slot->channel_listener_token.store(listener_token, std::memory_order_relaxed);
    slot->channel_listener_registered.store(true, std::memory_order_release);
    return 0;
}

int register_host_lobby_peer_listener(void *connection, HostPeerSlot *slot) {
    if (slot != nullptr && slot->peer_listener_registered.load(std::memory_order_acquire)) {
        return 0;
    }

    void *lobby = g_host_lobby.load(std::memory_order_acquire);
    const uint64_t peer_id = slot != nullptr ? slot->peer_id.load(std::memory_order_acquire) : 0;

    if (slot == nullptr || connection == nullptr || connection != g_expected_connection || lobby == nullptr ||
        !g_local_session_active.load(std::memory_order_acquire) || g_register_peer_system_listener == nullptr ||
        peer_id == 0) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_INVALID_CALLBACK_STATE, peer_id, 0,
                           "Could not prepare the peer lobby listener");
        return 1;
    }

    uint32_t listener_token = 0;
    g_register_peer_system_listener(connection, &listener_token, kLobbySystem, peer_id, host_lobby_peer_callback, slot);

    if (listener_token == 0) {
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_LISTENER_REGISTRATION, peer_id, 0,
                           "Darktide did not register the peer lobby listener");
        return 3;
    }

    slot->peer_listener_token.store(listener_token, std::memory_order_relaxed);
    slot->peer_listener_registered.store(true, std::memory_order_release);
    return 0;
}

uint64_t __fastcall host_listener_callback(void *connection, uint64_t, uint64_t peer_id, uint64_t, uint64_t,
                                           int32_t message_id, void *) {
    if (message_id == static_cast<int32_t>(kConnectRequestMessage)) {
        HostPeerSlot *slot = claim_host_peer_slot(peer_id);
        const int lobby_listener_error = slot != nullptr ? register_host_lobby_peer_listener(connection, slot) : 4;

        if (slot == nullptr) {
            push_runtime_event(REALMS_RUNTIME_EVENT_PEER_REJECTED, REALMS_RUNTIME_REJECT_CAPACITY, peer_id, 0,
                               "No native peer slot is available");
        }

        const int reply_error = lobby_listener_error == 0 ? send_connect_reply(connection, peer_id) : 7;
        if (reply_error != 0) {
            push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_SEND, peer_id, 0,
                               "Could not send the lobby discovery reply");
        } else {
            push_runtime_event(REALMS_RUNTIME_EVENT_PEER_DISCOVERED, REALMS_RUNTIME_EVENT_CODE_NONE, peer_id, 0,
                               "Peer completed Realms lobby discovery");
        }
    }

    return 0;
}

} // namespace realms
