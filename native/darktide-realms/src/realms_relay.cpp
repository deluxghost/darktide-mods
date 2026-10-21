#include "realms_internal.h"
#include "realms_datagram.h"

#include <MSWSock.h>
#include <ws2tcpip.h>

#include <array>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <thread>
#include <utility>
#include <vector>

namespace realms {

namespace {

constexpr size_t kMaximumUdpPacketSize = 65536;
constexpr int kRelayPollTimeoutMs = 25;
constexpr size_t kMaximumDatagramsPerSocket = 256;
constexpr uint64_t kUnadoptedPeerTimeoutMs = 30000;

enum class RelayPeerCommandType {
    Adopt,
    Release,
};

struct RelayPeerCommand {
    RelayPeerCommandType type;
    uint64_t peer_id;
};

struct RelayPeer {
    uint64_t peer_id = 0;
    uint32_t connection_id = 0;
    SOCKET game_socket = INVALID_SOCKET;
    sockaddr_storage external_address{};
    int external_address_size = 0;
    uint64_t created_tick = 0;
    bool adopted = false;
};

using RelayPeers = std::array<RelayPeer, kMaximumRemotePeers>;

std::atomic<bool> g_relay_running{false};
std::thread g_relay_thread;
std::mutex g_relay_command_mutex;
std::vector<RelayPeerCommand> g_relay_peer_commands;
bool g_relay_winsock_started = false;

void relay_error(uint64_t peer_id, const char *operation, int socket_error) {
    char message[REALMS_RUNTIME_EVENT_MESSAGE_CAPACITY]{};
    std::snprintf(message, sizeof(message), "%s failed with WSA error %d", operation, socket_error);
    push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_RELAY, peer_id, 0, message);
}

void relay_fatal_error(const char *operation, int socket_error) {
    char message[REALMS_RUNTIME_EVENT_MESSAGE_CAPACITY]{};
    std::snprintf(message, sizeof(message), "%s failed with WSA error %d", operation, socket_error);
    push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_RELAY_FATAL, 0, 0, message);
}

int poll_socket_error(SOCKET socket_handle, short revents) {
    if ((revents & POLLNVAL) != 0) {
        return WSAENOTSOCK;
    }

    int socket_error = 0;
    int socket_error_size = sizeof(socket_error);
    if (getsockopt(socket_handle, SOL_SOCKET, SO_ERROR, reinterpret_cast<char *>(&socket_error),
                   &socket_error_size) == SOCKET_ERROR) {
        return WSAGetLastError();
    }

    if (socket_error != 0) {
        return socket_error;
    }

    return (revents & POLLHUP) != 0 ? WSAECONNRESET : WSAEINVAL;
}

bool set_nonblocking(SOCKET socket_handle, char *error, int error_capacity) {
    u_long enabled = 1;
    if (ioctlsocket(socket_handle, FIONBIO, &enabled) == 0) {
        return true;
    }

    const int socket_error = WSAGetLastError();
    if (error != nullptr && error_capacity > 0) {
        std::snprintf(error, static_cast<size_t>(error_capacity),
                      "Could not make the Realms UDP relay socket non-blocking (WSA error %d)", socket_error);
    }
    return false;
}

bool disable_udp_connection_reset(SOCKET socket_handle, char *error, int error_capacity) {
    BOOL enabled = FALSE;
    DWORD bytes_returned = 0;
    if (WSAIoctl(socket_handle, SIO_UDP_CONNRESET, &enabled, sizeof(enabled), nullptr, 0, &bytes_returned, nullptr,
                 nullptr) == 0) {
        return true;
    }

    const int socket_error = WSAGetLastError();
    if (error != nullptr && error_capacity > 0) {
        std::snprintf(error, static_cast<size_t>(error_capacity),
                      "Could not disable UDP connection reset notifications (WSA error %d)", socket_error);
    }
    return false;
}

bool same_endpoint(const sockaddr_storage &left, int left_size, const sockaddr_storage &right, int right_size) {
    if (left.ss_family != right.ss_family) {
        return false;
    }

    if (left.ss_family == AF_INET && left_size >= static_cast<int>(sizeof(sockaddr_in)) &&
        right_size >= static_cast<int>(sizeof(sockaddr_in))) {
        const auto *left_ipv4 = reinterpret_cast<const sockaddr_in *>(&left);
        const auto *right_ipv4 = reinterpret_cast<const sockaddr_in *>(&right);
        return left_ipv4->sin_port == right_ipv4->sin_port &&
               left_ipv4->sin_addr.s_addr == right_ipv4->sin_addr.s_addr;
    }

    if (left.ss_family == AF_INET6 && left_size >= static_cast<int>(sizeof(sockaddr_in6)) &&
        right_size >= static_cast<int>(sizeof(sockaddr_in6))) {
        const auto *left_ipv6 = reinterpret_cast<const sockaddr_in6 *>(&left);
        const auto *right_ipv6 = reinterpret_cast<const sockaddr_in6 *>(&right);
        return left_ipv6->sin6_port == right_ipv6->sin6_port &&
               left_ipv6->sin6_scope_id == right_ipv6->sin6_scope_id &&
               std::memcmp(&left_ipv6->sin6_addr, &right_ipv6->sin6_addr, sizeof(in6_addr)) == 0;
    }

    return false;
}

SOCKET create_game_socket(const sockaddr *game_address, int game_address_size, uint64_t peer_id) {
    const int family = game_address != nullptr ? game_address->sa_family : AF_UNSPEC;
    if ((family != AF_INET && family != AF_INET6) || game_address_size <= 0) {
        return INVALID_SOCKET;
    }

    SOCKET socket_handle = socket(family, SOCK_DGRAM, IPPROTO_UDP);
    if (socket_handle == INVALID_SOCKET) {
        relay_error(peer_id, "Creating a peer relay socket", WSAGetLastError());
        return INVALID_SOCKET;
    }

    int bind_result = SOCKET_ERROR;
    if (family == AF_INET) {
        sockaddr_in source{};
        source.sin_family = AF_INET;
        source.sin_addr.s_addr = htonl(INADDR_ANY);
        bind_result = bind(socket_handle, reinterpret_cast<const sockaddr *>(&source), sizeof(source));
    } else {
        sockaddr_in6 source{};
        source.sin6_family = AF_INET6;
        source.sin6_addr = in6addr_any;
        bind_result = bind(socket_handle, reinterpret_cast<const sockaddr *>(&source), sizeof(source));
    }

    if (bind_result == SOCKET_ERROR) {
        const int socket_error = WSAGetLastError();
        closesocket(socket_handle);
        relay_error(peer_id, "Binding a peer relay socket", socket_error);
        return INVALID_SOCKET;
    }

    if (connect(socket_handle, game_address, game_address_size) == SOCKET_ERROR) {
        const int socket_error = WSAGetLastError();
        closesocket(socket_handle);
        relay_error(peer_id, "Connecting a peer relay socket", socket_error);
        return INVALID_SOCKET;
    }

    char error[REALMS_RUNTIME_EVENT_MESSAGE_CAPACITY]{};
    if (!set_nonblocking(socket_handle, error, sizeof(error))) {
        closesocket(socket_handle);
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_RELAY, peer_id, 0, error);
        return INVALID_SOCKET;
    }

    return socket_handle;
}

void clear_peer(RelayPeer &peer) {
    if (peer.game_socket != INVALID_SOCKET) {
        closesocket(peer.game_socket);
    }
    peer = {};
}

void process_peer_commands(RelayPeers &peers) {
    std::vector<RelayPeerCommand> commands;
    {
        std::lock_guard<std::mutex> lock(g_relay_command_mutex);
        commands.swap(g_relay_peer_commands);
    }

    for (const RelayPeerCommand &command : commands) {
        for (RelayPeer &peer : peers) {
            if (peer.peer_id == command.peer_id) {
                if (command.type == RelayPeerCommandType::Adopt) {
                    peer.adopted = true;
                } else {
                    clear_peer(peer);
                }
                break;
            }
        }
    }
}

void reap_unadopted_peers(RelayPeers &peers, uint64_t now) {
    for (RelayPeer &peer : peers) {
        if (peer.peer_id != 0 && !peer.adopted && peer.created_tick != 0 &&
            now - peer.created_tick >= kUnadoptedPeerTimeoutMs) {
            clear_peer(peer);
        }
    }
}

RelayPeer *find_external_peer(RelayPeers &peers, const sockaddr_storage &external_address, int external_address_size) {
    for (RelayPeer &peer : peers) {
        if (peer.peer_id != 0 &&
            same_endpoint(peer.external_address, peer.external_address_size, external_address,
                          external_address_size)) {
            return &peer;
        }
    }
    return nullptr;
}

RelayPeer *find_routed_peer(RelayPeers &peers, const DatagramRoute &route) {
    for (RelayPeer &peer : peers) {
        const bool matches = route.connection_id == 0 ? peer.peer_id == route.peer_id
                                                       : peer.connection_id == route.connection_id;
        if (peer.peer_id != 0 && matches) {
            return &peer;
        }
    }
    return nullptr;
}

RelayPeer *empty_peer(RelayPeers &peers) {
    for (RelayPeer &peer : peers) {
        if (peer.peer_id == 0) {
            return &peer;
        }
    }
    return nullptr;
}

void receive_public_packets(SOCKET public_socket, const sockaddr *game_address, int game_address_size,
                            RelayPeers &peers, std::array<uint8_t, kMaximumUdpPacketSize> &packet,
                            const DatagramDecoder &decoder) {
    for (size_t packet_index = 0; packet_index < kMaximumDatagramsPerSocket; ++packet_index) {
        sockaddr_storage external_address{};
        int external_address_size = sizeof(external_address);
        const int packet_size = recvfrom(public_socket, reinterpret_cast<char *>(packet.data()),
                                         static_cast<int>(packet.size()), 0,
                                         reinterpret_cast<sockaddr *>(&external_address), &external_address_size);

        if (packet_size == SOCKET_ERROR) {
            const int socket_error = WSAGetLastError();
            if (socket_error != WSAEWOULDBLOCK) {
                relay_error(0, "Receiving a public relay packet", socket_error);
            }
            return;
        }

        RelayPeer *peer = find_external_peer(peers, external_address, external_address_size);
        DatagramRoute route{};
        const bool route_decoded = decoder.read_route(packet.data(), packet_size, &route);
        if (!route_decoded && peer == nullptr) {
            continue;
        }
        const bool connectionless = route_decoded && route.connection_id == 0;

        if (peer != nullptr && connectionless && peer->peer_id != route.peer_id) {
            continue;
        }

        if (peer == nullptr) {
            peer = find_routed_peer(peers, route);
            if (peer == nullptr && !connectionless) {
                continue;
            }

            if (peer != nullptr) {
                // Mirror the engine's connection-ID rebinding without changing its local endpoint.
                peer->external_address = external_address;
                peer->external_address_size = external_address_size;
            }
        }

        if (peer == nullptr) {
            peer = empty_peer(peers);
            if (peer == nullptr) {
                push_runtime_event(REALMS_RUNTIME_EVENT_PEER_REJECTED, REALMS_RUNTIME_REJECT_CAPACITY,
                                   route.peer_id, 0, "No UDP relay peer slot is available");
                continue;
            }

            const SOCKET game_socket = create_game_socket(game_address, game_address_size, route.peer_id);
            if (game_socket == INVALID_SOCKET) {
                continue;
            }

            peer->peer_id = route.peer_id;
            peer->game_socket = game_socket;
            peer->external_address = external_address;
            peer->external_address_size = external_address_size;
            peer->created_tick = GetTickCount64();
        }

        if (route_decoded && !connectionless) {
            peer->connection_id = route.connection_id;
        }

        if (send(peer->game_socket, reinterpret_cast<const char *>(packet.data()), packet_size, 0) == SOCKET_ERROR) {
            const int socket_error = WSAGetLastError();
            if (socket_error != WSAEWOULDBLOCK) {
                relay_error(peer->peer_id, "Forwarding a packet to Darktide", socket_error);
            }
        }
    }
}

void receive_game_packets(SOCKET public_socket, RelayPeer &peer,
                          std::array<uint8_t, kMaximumUdpPacketSize> &packet) {
    for (size_t packet_index = 0; packet_index < kMaximumDatagramsPerSocket; ++packet_index) {
        const int packet_size =
            recv(peer.game_socket, reinterpret_cast<char *>(packet.data()), static_cast<int>(packet.size()), 0);

        if (packet_size == SOCKET_ERROR) {
            const int socket_error = WSAGetLastError();
            if (socket_error != WSAEWOULDBLOCK) {
                relay_error(peer.peer_id, "Receiving a packet from Darktide", socket_error);
            }
            return;
        }

        if (sendto(public_socket, reinterpret_cast<const char *>(packet.data()), packet_size, 0,
                   reinterpret_cast<const sockaddr *>(&peer.external_address), peer.external_address_size) ==
            SOCKET_ERROR) {
            const int socket_error = WSAGetLastError();
            if (socket_error != WSAEWOULDBLOCK) {
                relay_error(peer.peer_id, "Forwarding a packet to the remote peer", socket_error);
            }
        }
    }
}

void relay_main(SOCKET public_socket, sockaddr_storage game_address, int game_address_size, DatagramDecoder decoder) {
    RelayPeers peers{};
    std::array<uint8_t, kMaximumUdpPacketSize> packet{};

    while (g_relay_running.load(std::memory_order_acquire)) {
        process_peer_commands(peers);
        reap_unadopted_peers(peers, GetTickCount64());

        std::array<WSAPOLLFD, kMaximumRemotePeers + 1> poll_descriptors{};
        std::array<RelayPeer *, kMaximumRemotePeers> polled_peers{};
        ULONG descriptor_count = 1;
        size_t peer_descriptor_count = 0;

        poll_descriptors[0].fd = public_socket;
        poll_descriptors[0].events = POLLRDNORM;

        for (RelayPeer &peer : peers) {
            if (peer.peer_id == 0) {
                continue;
            }

            poll_descriptors[descriptor_count].fd = peer.game_socket;
            poll_descriptors[descriptor_count].events = POLLRDNORM;
            polled_peers[peer_descriptor_count++] = &peer;
            ++descriptor_count;
        }

        const int poll_result = WSAPoll(poll_descriptors.data(), descriptor_count, kRelayPollTimeoutMs);
        if (poll_result == SOCKET_ERROR) {
            relay_fatal_error("Polling the UDP relay", WSAGetLastError());
            break;
        }
        if (poll_result == 0) {
            continue;
        }

        if ((poll_descriptors[0].revents & POLLRDNORM) != 0) {
            receive_public_packets(public_socket, reinterpret_cast<const sockaddr *>(&game_address),
                                   game_address_size, peers, packet, decoder);
        }
        if ((poll_descriptors[0].revents & (POLLERR | POLLHUP | POLLNVAL)) != 0) {
            relay_fatal_error("Polling the public UDP relay socket",
                              poll_socket_error(public_socket, poll_descriptors[0].revents));
            break;
        }

        for (size_t index = 0; index < peer_descriptor_count; ++index) {
            WSAPOLLFD &descriptor = poll_descriptors[index + 1];
            RelayPeer &peer = *polled_peers[index];

            if ((descriptor.revents & POLLRDNORM) != 0) {
                receive_game_packets(public_socket, peer, packet);
            }
            if ((descriptor.revents & (POLLERR | POLLHUP | POLLNVAL)) != 0) {
                relay_error(peer.peer_id, "Polling a peer UDP relay socket",
                            poll_socket_error(peer.game_socket, descriptor.revents));
                clear_peer(peer);
            }
        }
    }

    for (RelayPeer &peer : peers) {
        clear_peer(peer);
    }
    closesocket(public_socket);
    g_relay_running.store(false, std::memory_order_release);
}

} // namespace

bool start_udp_relay(uint16_t listen_port, const sockaddr *game_address, int game_address_size,
                     RealmsRuntimeStartError *start_error, char *error, int error_capacity) {
    if (start_error != nullptr) {
        *start_error = REALMS_RUNTIME_START_ERROR_NONE;
    }
    if (listen_port == 0 || game_address == nullptr ||
        (game_address->sa_family != AF_INET && game_address->sa_family != AF_INET6)) {
        return write_error(error, error_capacity, "UDP relay start arguments are invalid");
    }
    if (g_relay_running.load(std::memory_order_acquire) || g_relay_thread.joinable()) {
        return write_error(error, error_capacity, "The Realms UDP relay is already active");
    }

    DatagramDecoder decoder;
    if (!decoder.initialize(error, error_capacity)) {
        return false;
    }

    WSADATA winsock_data{};
    const int startup_status = WSAStartup(MAKEWORD(2, 2), &winsock_data);
    if (startup_status != 0) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Could not initialize the Realms UDP relay (WSA status %d)", startup_status);
        }
        return false;
    }
    g_relay_winsock_started = true;

    SOCKET public_socket = socket(AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
    if (public_socket == INVALID_SOCKET) {
        const int socket_error = WSAGetLastError();
        WSACleanup();
        g_relay_winsock_started = false;
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Could not create the Realms listen socket (WSA error %d)", socket_error);
        }
        return false;
    }

    const DWORD exclusive = 1;
    const DWORD dual_stack = 0;
    sockaddr_in6 listen_address{};
    listen_address.sin6_family = AF_INET6;
    listen_address.sin6_addr = in6addr_any;
    listen_address.sin6_port = htons(listen_port);

    if (setsockopt(public_socket, SOL_SOCKET, SO_EXCLUSIVEADDRUSE, reinterpret_cast<const char *>(&exclusive),
                   sizeof(exclusive)) == SOCKET_ERROR) {
        const int socket_error = WSAGetLastError();
        closesocket(public_socket);
        WSACleanup();
        g_relay_winsock_started = false;
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Could not configure exclusive use for the Realms listen socket (WSA error %d)",
                          socket_error);
        }
        return false;
    }

    if (setsockopt(public_socket, IPPROTO_IPV6, IPV6_V6ONLY, reinterpret_cast<const char *>(&dual_stack),
                   sizeof(dual_stack)) == SOCKET_ERROR) {
        const int socket_error = WSAGetLastError();
        closesocket(public_socket);
        WSACleanup();
        g_relay_winsock_started = false;
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Could not enable dual-stack mode for the Realms listen socket (WSA error %d)",
                          socket_error);
        }
        return false;
    }

    if (bind(public_socket, reinterpret_cast<const sockaddr *>(&listen_address), sizeof(listen_address)) ==
        SOCKET_ERROR) {
        const int socket_error = WSAGetLastError();
        closesocket(public_socket);
        WSACleanup();
        g_relay_winsock_started = false;
        if (start_error != nullptr) {
            *start_error = REALMS_RUNTIME_START_ERROR_LISTEN_PORT_UNAVAILABLE;
        }
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Could not bind UDP port %u for the Realms server (WSA error %d)",
                          static_cast<unsigned int>(listen_port), socket_error);
        }
        return false;
    }

    if (!set_nonblocking(public_socket, error, error_capacity)) {
        closesocket(public_socket);
        WSACleanup();
        g_relay_winsock_started = false;
        return false;
    }

    if (!disable_udp_connection_reset(public_socket, error, error_capacity)) {
        closesocket(public_socket);
        WSACleanup();
        g_relay_winsock_started = false;
        return false;
    }

    sockaddr_storage game_address_copy{};
    if (game_address_size <= 0 || game_address_size > static_cast<int>(sizeof(game_address_copy))) {
        closesocket(public_socket);
        WSACleanup();
        g_relay_winsock_started = false;
        return write_error(error, error_capacity, "Darktide UDP target address has an invalid size");
    }
    std::memcpy(&game_address_copy, game_address, static_cast<size_t>(game_address_size));

    {
        std::lock_guard<std::mutex> lock(g_relay_command_mutex);
        g_relay_peer_commands.clear();
    }

    g_relay_running.store(true, std::memory_order_release);
    try {
        g_relay_thread = std::thread(relay_main, public_socket, game_address_copy, game_address_size, std::move(decoder));
    } catch (...) {
        g_relay_running.store(false, std::memory_order_release);
        closesocket(public_socket);
        WSACleanup();
        g_relay_winsock_started = false;
        return write_error(error, error_capacity, "Could not start the Realms UDP relay thread");
    }

    return true;
}

void adopt_udp_relay_peer(uint64_t peer_id) {
    if (peer_id == 0 || !g_relay_running.load(std::memory_order_acquire)) {
        return;
    }

    std::lock_guard<std::mutex> lock(g_relay_command_mutex);
    g_relay_peer_commands.push_back({RelayPeerCommandType::Adopt, peer_id});
}

void release_udp_relay_peer(uint64_t peer_id) {
    if (peer_id == 0 || !g_relay_running.load(std::memory_order_acquire)) {
        return;
    }

    std::lock_guard<std::mutex> lock(g_relay_command_mutex);
    g_relay_peer_commands.push_back({RelayPeerCommandType::Release, peer_id});
}

void stop_udp_relay() {
    g_relay_running.store(false, std::memory_order_release);
    if (g_relay_thread.joinable()) {
        g_relay_thread.join();
    }

    {
        std::lock_guard<std::mutex> lock(g_relay_command_mutex);
        g_relay_peer_commands.clear();
    }

    if (g_relay_winsock_started) {
        WSACleanup();
        g_relay_winsock_started = false;
    }
}

} // namespace realms
