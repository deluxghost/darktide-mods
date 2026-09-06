#include <ws2tcpip.h>
#include <rpc.h>

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstring>
#include <iterator>
#include <mutex>

#include "darktide_realms.h"
#include "realms_internal.h"

using namespace realms;

int RealmsRuntime_Initialize(char *error, int error_capacity) {
    return ensure_initialized(error, error_capacity) ? 1 : 0;
}

uint32_t RealmsRuntime_MaximumHostMembers(void) {
    return kMaximumHostMembers;
}

int RealmsRuntime_ResolveAddresses(const char *address, RealmsResolvedAddresses *resolved, char *error,
                                   int error_capacity) {
    if (resolved == nullptr || resolved->struct_size != sizeof(RealmsResolvedAddresses)) {
        write_error(error, error_capacity, "Resolved-address output has an invalid structure size");
        return 0;
    }

    resolved->count = 0;
    std::memset(resolved->addresses, 0, sizeof(resolved->addresses));

    if (address == nullptr || address[0] == '\0') {
        write_error(error, error_capacity, "Server address is empty");
        return 0;
    }
    if (std::strlen(address) > 253) {
        write_error(error, error_capacity, "Server address exceeds the DNS name length limit");
        return 0;
    }

    WSADATA winsock_data{};
    const int startup_status = WSAStartup(MAKEWORD(2, 2), &winsock_data);

    if (startup_status != 0) {
        write_formatted_error(error, error_capacity, "Windows socket initialization failed with status %lu",
                              static_cast<unsigned long>(startup_status));
        return 0;
    }

    addrinfo hints{};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;

    addrinfo *results = nullptr;
    const int resolve_status = getaddrinfo(address, nullptr, &hints, &results);

    if (resolve_status != 0) {
        write_formatted_error(error, error_capacity, "Windows address resolution failed with status %lu",
                              static_cast<unsigned long>(resolve_status));
        WSACleanup();
        return 0;
    }

    for (const addrinfo *candidate = results; candidate != nullptr; candidate = candidate->ai_next) {
        const void *binary_address = nullptr;

        if (candidate->ai_family == AF_INET && candidate->ai_addrlen >= sizeof(sockaddr_in)) {
            binary_address = &reinterpret_cast<const sockaddr_in *>(candidate->ai_addr)->sin_addr;
        } else if (candidate->ai_family == AF_INET6 && candidate->ai_addrlen >= sizeof(sockaddr_in6)) {
            const auto *ipv6 = reinterpret_cast<const sockaddr_in6 *>(candidate->ai_addr);

            if (ipv6->sin6_scope_id != 0) {
                continue;
            }

            binary_address = &ipv6->sin6_addr;
        } else {
            continue;
        }

        char numeric_address[REALMS_RUNTIME_ADDRESS_CAPACITY]{};

        if (InetNtopA(candidate->ai_family, const_cast<void *>(binary_address), numeric_address,
                      static_cast<DWORD>(sizeof(numeric_address))) == nullptr) {
            continue;
        }

        bool duplicate = false;
        for (uint32_t index = 0; index < resolved->count; ++index) {
            duplicate = duplicate || std::strcmp(resolved->addresses[index], numeric_address) == 0;
        }

        if (!duplicate && resolved->count < REALMS_RUNTIME_MAX_RESOLVED_ADDRESSES) {
            std::snprintf(resolved->addresses[resolved->count], REALMS_RUNTIME_ADDRESS_CAPACITY, "%s",
                          numeric_address);
            ++resolved->count;
        }
    }

    freeaddrinfo(results);

    if (resolved->count == 0) {
        write_error(error, error_capacity, "Windows resolver returned no usable unscoped IPv4 or IPv6 address");
    }

    WSACleanup();
    return resolved->count > 0 ? 1 : 0;
}

bool get_local_udp_target(int *port, sockaddr_storage *target, int *target_size, char *error, int error_capacity) {
    if (port == nullptr || target == nullptr || target_size == nullptr) {
        write_error(error, error_capacity, "Local UDP target output is null");
        return 0;
    }

    void *manager = nullptr;

    if (!current_network_manager(&manager, error, error_capacity)) {
        return 0;
    }

    void *transport = nullptr;

    if (!read_pointer(static_cast<const uint8_t *>(manager) + kTransportOffset, &transport, "Darktide LAN transport",
                      error, error_capacity)) {
        return 0;
    }

    const uint8_t *socket_location = static_cast<const uint8_t *>(transport) + kTransportSocketOffset;

    if (!dtintutils_is_readable_range(socket_location, sizeof(SOCKET))) {
        write_error(error, error_capacity, "Darktide UDP socket location is unreadable");
        return 0;
    }

    SOCKET socket_handle = INVALID_SOCKET;
    std::memcpy(&socket_handle, socket_location, sizeof(socket_handle));

    if (socket_handle == INVALID_SOCKET) {
        write_error(error, error_capacity, "Darktide UDP socket is not initialized");
        return 0;
    }

    std::memset(target, 0, sizeof(*target));
    *target_size = sizeof(*target);

    if (getsockname(socket_handle, reinterpret_cast<sockaddr *>(target), target_size) != 0) {
        write_formatted_error(error, error_capacity, "getsockname failed with WSA error %lu", WSAGetLastError());
        return 0;
    }

    if (target->ss_family == AF_INET6 && *target_size >= static_cast<int>(sizeof(sockaddr_in6))) {
        auto *ipv6 = reinterpret_cast<sockaddr_in6 *>(target);
        *port = ntohs(ipv6->sin6_port);
        if (IN6_IS_ADDR_UNSPECIFIED(&ipv6->sin6_addr)) {
            ipv6->sin6_addr = in6addr_loopback;
            ipv6->sin6_scope_id = 0;
        }
        *target_size = sizeof(sockaddr_in6);
    } else if (target->ss_family == AF_INET && *target_size >= static_cast<int>(sizeof(sockaddr_in))) {
        auto *ipv4 = reinterpret_cast<sockaddr_in *>(target);
        *port = ntohs(ipv4->sin_port);
        if (ipv4->sin_addr.s_addr == htonl(INADDR_ANY)) {
            ipv4->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        }
        *target_size = sizeof(sockaddr_in);
    } else {
        write_error(error, error_capacity, "Darktide UDP socket has an unsupported address family");
        return 0;
    }

    return 1;
}

int RealmsRuntime_IsPeerConnected(const char *peer_id_text, int *connected, char *error, int error_capacity) {
    if (connected == nullptr) {
        write_error(error, error_capacity, "Peer connection output is null");
        return 0;
    }

    uint64_t peer_id = 0;

    if (!parse_hex_id(peer_id_text, &peer_id, "Peer ID", error, error_capacity)) {
        return 0;
    }

    void *connection = nullptr;
    IsPeerConnectedFunction is_peer_connected = nullptr;

    if (!current_connection(&connection, &is_peer_connected, nullptr, nullptr, error, error_capacity)) {
        return 0;
    }

    *connected = is_peer_connected(connection, peer_id) != 0 ? 1 : 0;
    return 1;
}

bool set_local_account_id(const char *account_id, char *error, int error_capacity) {
    if (g_host_listener_registered.load(std::memory_order_acquire)) {
        write_error(error, error_capacity, "Local account ID cannot change while the host listener is active");
        return 0;
    }

    if (account_id == nullptr || std::strlen(account_id) != kWireAddressSize - 1) {
        write_error(error, error_capacity, "Local account ID must contain exactly 36 characters");
        return 0;
    }

    UUID parsed_account_id{};
    const RPC_STATUS parse_status =
        UuidFromStringA(reinterpret_cast<RPC_CSTR>(const_cast<char *>(account_id)), &parsed_account_id);

    if (parse_status != RPC_S_OK) {
        write_error(error, error_capacity, "Local account ID is not a canonical UUID");
        return 0;
    }

    std::memcpy(g_local_account_id, account_id, kWireAddressSize);
    return 1;
}

bool initialize_local_session_lobby(uint64_t local_peer_id, uint16_t local_port, uint32_t max_members, char *error,
                                    int error_capacity) {
    void *lan_client = nullptr;

    if (!current_network_manager(&lan_client, error, error_capacity) ||
        !dtintutils_is_readable_range(lan_client, kLanClientLobbyEntriesOffset + sizeof(void *))) {
        return write_error(error, error_capacity, "Darktide LanClient lobby container is unreadable");
    }

    const auto *client_bytes = static_cast<const uint8_t *>(lan_client);
    uint32_t lobby_count = 0;
    uint32_t lobby_capacity = 0;
    void **lobby_entries = nullptr;
    std::memcpy(&lobby_count, client_bytes + kLanClientLobbyCountOffset, sizeof(lobby_count));
    std::memcpy(&lobby_capacity, client_bytes + kLanClientLobbyCapacityOffset, sizeof(lobby_capacity));
    std::memcpy(&lobby_entries, client_bytes + kLanClientLobbyEntriesOffset, sizeof(lobby_entries));

    if (lobby_count == 0 || lobby_count > lobby_capacity || lobby_capacity > 4096 || lobby_entries == nullptr ||
        !dtintutils_is_readable_range(lobby_entries, static_cast<size_t>(lobby_count) * sizeof(void *))) {
        write_error(error, error_capacity, "Darktide LanClient has no valid local-session lobby collection");
        return 0;
    }
    void *client_connection = nullptr;
    void *client_transport = nullptr;
    std::memcpy(&client_transport, client_bytes + kTransportOffset, sizeof(client_transport));
    std::memcpy(&client_connection, client_bytes + kConnectionOffset, sizeof(client_connection));

    void *lobby = nullptr;
    uint64_t current_lobby_id = 0;
    size_t candidate_count = 0;

    for (uint32_t index = 0; index < lobby_count; ++index) {
        void *candidate = lobby_entries[index];
        if (candidate == nullptr || !dtintutils_is_readable_range(candidate, kLanLobbySize)) {
            return write_error(error, error_capacity, "Darktide LanClient contains an unreadable lobby object");
        }

        const auto *candidate_bytes = static_cast<const uint8_t *>(candidate);
        void *owner = nullptr;
        void *connection = nullptr;
        void *transport = nullptr;
        uint64_t candidate_lobby_id = 0;
        uint64_t candidate_local_peer_id = 0;
        uint64_t guest_channel = 0;
        uint32_t state = 0;
        uint32_t member_count = 0;
        uint32_t member_capacity = 0;
        uint32_t system_listener_token = 0;
        void *members = nullptr;
        std::memcpy(&owner, candidate_bytes + kLanLobbyOwnerOffset, sizeof(owner));
        std::memcpy(&candidate_lobby_id, candidate_bytes + kLanLobbyIdOffset, sizeof(candidate_lobby_id));
        std::memcpy(&candidate_local_peer_id, candidate_bytes + kLanLobbyLocalPeerOffset,
                    sizeof(candidate_local_peer_id));
        std::memcpy(&connection, candidate_bytes + kLanLobbyConnectionOffset, sizeof(connection));
        std::memcpy(&transport, candidate_bytes + kLanLobbyTransportOffset, sizeof(transport));
        std::memcpy(&state, candidate_bytes + kLanLobbyStateOffset, sizeof(state));
        std::memcpy(&guest_channel, candidate_bytes + kLanLobbyGuestChannelOffset, sizeof(guest_channel));
        std::memcpy(&member_count, candidate_bytes + kLanLobbyMemberCountOffset, sizeof(member_count));
        std::memcpy(&member_capacity, candidate_bytes + kLanLobbyMemberCapacityOffset, sizeof(member_capacity));
        std::memcpy(&members, candidate_bytes + kLanLobbyMembersOffset, sizeof(members));
        std::memcpy(&system_listener_token, candidate_bytes + kLanLobbySystemListenerTokenOffset,
                    sizeof(system_listener_token));

        if (owner == lan_client && connection == client_connection && connection == g_expected_connection &&
            transport == client_transport && candidate_local_peer_id == local_peer_id && (state == 1 || state == 3) &&
            guest_channel == 0 && member_count == 0 && member_capacity == 0 && members == nullptr &&
            system_listener_token != 0) {
            lobby = candidate;
            current_lobby_id = candidate_lobby_id;
            ++candidate_count;
        }
    }

    if (candidate_count != 1) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected one local-session LanLobby candidate, found %zu", candidate_count);
        }
        return false;
    }

    auto *lobby_bytes = static_cast<uint8_t *>(lobby);

    AddLobbyMemberFunction add_member = nullptr;
    DestroyLobbyMemberFunction destroy_member = nullptr;

    if (!locate_lobby_member_helpers(&add_member, &destroy_member, error, error_capacity)) {
        return 0;
    }

    g_add_lobby_member = add_member;
    g_destroy_lobby_member = destroy_member;
    std::memcpy(lobby_bytes + kLanLobbyIdOffset, &local_peer_id, sizeof(local_peer_id));
    std::memcpy(lobby_bytes + kLanLobbyHostOffset, &local_peer_id, sizeof(local_peer_id));
    std::memcpy(lobby_bytes + kLanLobbyMaxMembersOffset, &max_members, sizeof(max_members));

    if (!add_lobby_member(lobby, local_peer_id, static_cast<uint16_t>(local_port), 0)) {
        const uint64_t empty_host = 0;
        const uint32_t empty_max_members = 0;
        std::memcpy(lobby_bytes + kLanLobbyIdOffset, &current_lobby_id, sizeof(current_lobby_id));
        std::memcpy(lobby_bytes + kLanLobbyHostOffset, &empty_host, sizeof(empty_host));
        std::memcpy(lobby_bytes + kLanLobbyMaxMembersOffset, &empty_max_members, sizeof(empty_max_members));
        g_add_lobby_member = nullptr;
        g_destroy_lobby_member = nullptr;
        write_error(error, error_capacity, "Darktide LanLobby rejected the local-session host member");
        return 0;
    }

    const uint32_t joined_state = 2;
    std::memcpy(lobby_bytes + kLanLobbyStateOffset, &joined_state, sizeof(joined_state));
    g_host_lobby.store(lobby, std::memory_order_relaxed);
    g_host_lobby_id.store(local_peer_id, std::memory_order_relaxed);
    g_local_session_active.store(true, std::memory_order_release);
    return 1;
}

void clear_runtime_bindings() {
    g_expected_connection = nullptr;
    g_expected_connection_vtable = nullptr;
    g_register_channel_system_listener = nullptr;
    g_register_peer_system_listener = nullptr;
    g_remove_listener = nullptr;
    g_read_bits = nullptr;
    g_send_address = nullptr;
    g_accept_channel = nullptr;
    g_send_channel = nullptr;
    g_add_lobby_member = nullptr;
    g_destroy_lobby_member = nullptr;
}

bool initialize_connection_listener(const char *local_account_id, char *error, int error_capacity) {
    if (!set_local_account_id(local_account_id, error, error_capacity)) {
        return false;
    }

    void *connection = nullptr;
    RegisterSystemListenerFunction register_system_listener = nullptr;
    RemoveListenerFunction remove_listener = nullptr;
    if (!current_connection(&connection, nullptr, &register_system_listener, &remove_listener, error, error_capacity)) {
        return false;
    }

    ReadBitsFunction read_bits = nullptr;
    if (!locate_read_bits(&read_bits, error, error_capacity)) {
        return false;
    }

    void *connection_vtable = nullptr;
    if (!read_pointer(static_cast<const uint8_t *>(connection), &connection_vtable, "Darktide Connection vtable", error,
                      error_capacity)) {
        return false;
    }

    void *register_channel_listener_target = nullptr;
    void *register_peer_listener_target = nullptr;
    void *accept_channel_target = nullptr;
    void *send_channel_target = nullptr;
    const auto *vtable = static_cast<const uint8_t *>(connection_vtable);
    if (!read_pointer(vtable + kRegisterChannelSystemListenerSlot, &register_channel_listener_target,
                      "Darktide register-channel-listener method", error, error_capacity) ||
        !read_pointer(vtable + kRegisterPeerSystemListenerSlot, &register_peer_listener_target,
                      "Darktide register-peer-listener method", error, error_capacity) ||
        !read_pointer(vtable + kAcceptChannelSlot, &accept_channel_target, "Darktide accept-channel method", error,
                      error_capacity) ||
        !read_pointer(vtable + kSendChannelSlot, &send_channel_target, "Darktide send-channel method", error,
                      error_capacity)) {
        return false;
    }

    if (!validate_routed_listener_methods(register_channel_listener_target, register_peer_listener_target, error,
                                          error_capacity) ||
        !validate_engine_function(accept_channel_target, EngineFunctionRole::AcceptChannel,
                                  "Darktide accept-channel", error, error_capacity) ||
        !validate_engine_function(send_channel_target, EngineFunctionRole::SendChannel, "Darktide send-channel",
                                  error, error_capacity)) {
        return false;
    }

    void *wan_transport = nullptr;
    void *wan_transport_vtable = nullptr;
    void *send_address_target = nullptr;
    if (!read_pointer(static_cast<const uint8_t *>(connection) + kConnectionWanTransportOffset, &wan_transport,
                      "Darktide WAN transport", error, error_capacity) ||
        !read_pointer(static_cast<const uint8_t *>(wan_transport), &wan_transport_vtable,
                      "Darktide WAN transport vtable", error, error_capacity) ||
        !read_pointer(static_cast<const uint8_t *>(wan_transport_vtable) + kSendAddressSlot, &send_address_target,
                      "Darktide WAN explicit-address send", error, error_capacity) ||
        !validate_send_address_method(send_address_target, error, error_capacity)) {
        return false;
    }

    const auto *listener_selector = static_cast<const uint8_t *>(connection) + kListenerTableSelectorOffset;
    if (!dtintutils_is_readable_range(listener_selector, sizeof(uint8_t))) {
        return write_error(error, error_capacity, "Darktide listener-table selector is unreadable");
    }

    uint8_t selector = 0;
    std::memcpy(&selector, listener_selector, sizeof(selector));
    if (selector != 0) {
        return write_error(error, error_capacity,
                           "Darktide listener registration is not in the immediate game-thread table");
    }

    g_expected_connection = connection;
    g_expected_connection_vtable = connection_vtable;
    g_register_channel_system_listener =
        reinterpret_cast<RegisterChannelSystemListenerFunction>(register_channel_listener_target);
    g_register_peer_system_listener =
        reinterpret_cast<RegisterPeerSystemListenerFunction>(register_peer_listener_target);
    g_remove_listener = remove_listener;
    g_read_bits = read_bits;
    g_send_address = reinterpret_cast<SendAddressFunction>(send_address_target);
    g_accept_channel = reinterpret_cast<AcceptChannelFunction>(accept_channel_target);
    g_send_channel = reinterpret_cast<SendChannelFunction>(send_channel_target);

    uint32_t listener_token = 0;
    register_system_listener(connection, &listener_token, kLobbyConnectRequestSystem, host_listener_callback,
                             connection);
    if (listener_token == 0) {
        clear_runtime_bindings();
        return write_error(error, error_capacity, "Darktide did not register the local-session listener");
    }

    g_host_listener_connection.store(connection, std::memory_order_relaxed);
    g_host_listener_token.store(listener_token, std::memory_order_relaxed);
    g_host_listener_registered.store(true, std::memory_order_release);
    return true;
}

int fail_start_after_cleanup(char *error, int error_capacity) {
    char start_error[512]{};
    if (error != nullptr && error_capacity > 0) {
        std::snprintf(start_error, sizeof(start_error), "%s", error);
    }

    char cleanup_error[512]{};
    if (!RealmsRuntime_CloseLocalSession(cleanup_error, sizeof(cleanup_error))) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity), "%s; local-session cleanup also failed: %s",
                          start_error, cleanup_error);
        }
        return 0;
    }

    write_error(error, error_capacity, start_error);
    return 0;
}

int RealmsRuntime_StartLocalSession(const char *local_account_id, const char *local_peer_id, int requested_listen_port,
                                    int *listen_udp_port, int *start_error_code, char *error, int error_capacity) {
    if (listen_udp_port == nullptr || start_error_code == nullptr) {
        write_error(error, error_capacity, "Local-session start output is null");
        return 0;
    }
    *listen_udp_port = 0;
    *start_error_code = REALMS_RUNTIME_START_ERROR_NONE;
    if (requested_listen_port < 0 || requested_listen_port > 65535) {
        write_error(error, error_capacity, "Requested listen UDP port is outside the valid range");
        return 0;
    }
    if (g_host_listener_registered.load(std::memory_order_acquire) ||
        g_local_session_active.load(std::memory_order_acquire)) {
        write_error(error, error_capacity, "A Realms local session is already active");
        return 0;
    }
    uint64_t native_peer_id = 0;
    if (!parse_hex_id(local_peer_id, &native_peer_id, "Local peer ID", error, error_capacity)) {
        return 0;
    }

    clear_runtime_events();
    for (HostPeerSlot &slot : g_host_peer_slots) {
        clear_host_peer_slot(slot);
    }

    if (!initialize_connection_listener(local_account_id, error, error_capacity)) {
        return 0;
    }

    int native_port = 0;
    sockaddr_storage native_target{};
    int native_target_size = 0;
    if (!get_local_udp_target(&native_port, &native_target, &native_target_size, error, error_capacity) ||
        native_port <= 0 || native_port > 65535) {
        if (native_port <= 0 || native_port > 65535) {
            write_error(error, error_capacity, "Darktide UDP socket reported an invalid port");
        }
        return fail_start_after_cleanup(error, error_capacity);
    }

    if (!initialize_local_session_lobby(native_peer_id, static_cast<uint16_t>(native_port),
                                        kMaximumHostMembers, error, error_capacity)) {
        return fail_start_after_cleanup(error, error_capacity);
    }

    if (requested_listen_port != 0 && requested_listen_port != native_port) {
        RealmsRuntimeStartError start_error = REALMS_RUNTIME_START_ERROR_NONE;
        if (!start_udp_relay(static_cast<uint16_t>(requested_listen_port),
                             reinterpret_cast<const sockaddr *>(&native_target), native_target_size, &start_error,
                             error, error_capacity)) {
            *start_error_code = static_cast<int>(start_error);
            return fail_start_after_cleanup(error, error_capacity);
        }
    }

    *listen_udp_port = requested_listen_port != 0 ? requested_listen_port : native_port;
    return 1;
}

bool validate_host_peer_slot_listeners(const HostPeerSlot &slot, void *connection, char *error, int error_capacity) {
    const bool has_peer_listener = slot.peer_listener_registered.load(std::memory_order_acquire);
    const bool has_channel_listener = slot.channel_listener_registered.load(std::memory_order_acquire);
    const uint32_t peer_listener_token = slot.peer_listener_token.load(std::memory_order_relaxed);
    const uint32_t channel_listener_token = slot.channel_listener_token.load(std::memory_order_relaxed);

    if (!has_peer_listener && !has_channel_listener) {
        return true;
    }

    if (connection == nullptr || g_remove_listener == nullptr || (has_peer_listener && peer_listener_token == 0) ||
        (has_channel_listener && channel_listener_token == 0)) {
        write_error(error, error_capacity, "Registered host peer listener state is no longer valid for removal");
        return false;
    }

    return true;
}

bool remove_host_peer_slot_listeners(HostPeerSlot &slot, void *connection, char *error, int error_capacity) {
    if (!validate_host_peer_slot_listeners(slot, connection, error, error_capacity)) {
        return false;
    }

    const bool has_peer_listener = slot.peer_listener_registered.load(std::memory_order_acquire);
    const bool has_channel_listener = slot.channel_listener_registered.load(std::memory_order_acquire);
    const uint32_t peer_listener_token = slot.peer_listener_token.load(std::memory_order_relaxed);
    const uint32_t channel_listener_token = slot.channel_listener_token.load(std::memory_order_relaxed);

    if (has_channel_listener) {
        g_remove_listener(connection, channel_listener_token);
    }
    if (has_peer_listener) {
        g_remove_listener(connection, peer_listener_token);
    }
    std::lock_guard<std::mutex> lock(g_host_peer_slots_mutex);
    clear_host_peer_slot(slot);
    return true;
}

int RealmsRuntime_ReleasePeerTransportState(const char *peer_id_text, char *error, int error_capacity) {
    uint64_t peer_id = 0;

    if (!parse_hex_id(peer_id_text, &peer_id, "Host peer ID", error, error_capacity)) {
        return 0;
    }

    HostPeerSlot *slot = find_host_peer_slot(peer_id);

    if (slot == nullptr) {
        return 1;
    }

    // Leaving a lobby does not end the engine connection. Rejoining may already be using it.
    slot->state.store(HostPeerState::Released, std::memory_order_release);
    return 1;
}

int RealmsRuntime_AdoptPeerTransportState(const char *peer_id_text, char *error, int error_capacity) {
    uint64_t peer_id = 0;

    if (!parse_hex_id(peer_id_text, &peer_id, "Host peer ID", error, error_capacity)) {
        return 0;
    }

    HostPeerSlot *slot = find_host_peer_slot(peer_id);

    if (slot == nullptr) {
        write_error(error, error_capacity, "No native peer transport state exists for adoption");
        return 0;
    }

    slot->last_activity_tick.store(GetTickCount64(), std::memory_order_relaxed);
    slot->state.store(HostPeerState::Adopted, std::memory_order_release);
    return 1;
}

int RealmsRuntime_ReapAbandonedPeerTransportState(uint32_t idle_timeout_ms, int *reaped_count, char *error,
                                                   int error_capacity) {
    if (reaped_count == nullptr || idle_timeout_ms == 0) {
        write_error(error, error_capacity, "Abandoned peer reaper arguments are invalid");
        return 0;
    }

    *reaped_count = 0;
    const uint64_t now = GetTickCount64();
    void *connection = nullptr;
    IsPeerConnectedFunction is_peer_connected = nullptr;

    if (!current_connection(&connection, &is_peer_connected, nullptr, nullptr, error, error_capacity)) {
        return 0;
    }

    for (HostPeerSlot &slot : g_host_peer_slots) {
        const uint64_t peer_id = slot.peer_id.load(std::memory_order_acquire);
        const uint64_t last_activity = slot.last_activity_tick.load(std::memory_order_relaxed);
        const HostPeerState state = slot.state.load(std::memory_order_acquire);

        if (peer_id == 0 || state == HostPeerState::Adopted || is_peer_connected(connection, peer_id) != 0) {
            continue;
        }
        if (state == HostPeerState::Pending && now - last_activity < idle_timeout_ms) {
            continue;
        }
        if (!remove_host_peer_slot_listeners(slot, connection, error, error_capacity)) {
            return 0;
        }

        release_udp_relay_peer(peer_id);
        ++*reaped_count;
    }

    return 1;
}

int RealmsRuntime_PollEvent(RealmsRuntimeEvent *event, char *error, int error_capacity) {
    return poll_runtime_event(event, error, error_capacity);
}

int RealmsRuntime_CloseLocalSession(char *error, int error_capacity) {
    void *connection = g_host_listener_connection.load(std::memory_order_acquire);
    const bool listener_registered = g_host_listener_registered.load(std::memory_order_acquire);
    const uint32_t listener_token = g_host_listener_token.load(std::memory_order_relaxed);

    if (listener_registered) {
        if (connection == nullptr || listener_token == 0 || g_remove_listener == nullptr ||
            !dtintutils_is_readable_range(connection, sizeof(void *))) {
            write_error(error, error_capacity, "Registered host listener state is no longer valid for removal");
            return 0;
        }

        void *vtable = nullptr;
        std::memcpy(&vtable, connection, sizeof(vtable));

        if (vtable != g_expected_connection_vtable ||
            !dtintutils_is_readable_range(static_cast<const uint8_t *>(vtable) + kRemoveListenerSlot, sizeof(void *))) {
            write_error(error, error_capacity, "Registered host listener Connection vtable changed before removal");
            return 0;
        }

        void *remove_listener_target = nullptr;
        std::memcpy(&remove_listener_target, static_cast<const uint8_t *>(vtable) + kRemoveListenerSlot,
                    sizeof(remove_listener_target));

        if (remove_listener_target != reinterpret_cast<void *>(g_remove_listener)) {
            write_error(error, error_capacity, "Registered host listener removal method changed before removal");
            return 0;
        }
    }

    for (const HostPeerSlot &slot : g_host_peer_slots) {
        if (!validate_host_peer_slot_listeners(slot, connection, error, error_capacity)) {
            return 0;
        }
    }

    stop_udp_relay();

    for (HostPeerSlot &slot : g_host_peer_slots) {
        if (!remove_host_peer_slot_listeners(slot, connection, error, error_capacity)) {
            return 0;
        }
    }

    if (listener_registered) {
        g_remove_listener(connection, listener_token);
    }

    g_host_listener_connection.store(nullptr, std::memory_order_relaxed);
    g_host_listener_token.store(0, std::memory_order_relaxed);
    g_host_listener_registered.store(false, std::memory_order_relaxed);
    g_host_lobby.store(nullptr, std::memory_order_relaxed);
    g_host_lobby_id.store(0, std::memory_order_relaxed);
    g_local_session_active.store(false, std::memory_order_relaxed);
    std::memset(g_local_account_id, 0, sizeof(g_local_account_id));
    clear_runtime_bindings();

    return 1;
}
