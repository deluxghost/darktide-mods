#include "realms_bridge.h"

#include <ws2tcpip.h>
#include <algorithm>
#include <cstdio>
#include <cstring>

namespace realms {
namespace {

constexpr uint8_t kProtocol = 1;
constexpr uint8_t kDatagram = 0;
constexpr uint8_t kQuery = 1;
constexpr uint8_t kServerInfo = 2;
constexpr uint8_t kFragment = 3;
constexpr size_t kQuerySize = 2 + sizeof(uint64_t);
constexpr size_t kFragmentHeaderSize = 7;
constexpr uint8_t kMaximumFragments = 8;
constexpr size_t kMaximumEvents = 128;
constexpr size_t kReceiveBatch = 32;
constexpr uint64_t kQueryTimeoutMs = 20000;

std::vector<Bridge *> &registry() {
    static std::vector<Bridge *> bridges;
    return bridges;
}

uint16_t read_u16(const uint8_t *data) { return static_cast<uint16_t>(data[0] | (data[1] << 8)); }

void write_u16(uint8_t *data, uint16_t value) {
    data[0] = static_cast<uint8_t>(value);
    data[1] = static_cast<uint8_t>(value >> 8);
}

} // namespace

Bridge::Bridge(BridgeTransport &transport)
    : transport_(transport), buffer_(kBridgeMaximumDatagram + 1), staged_(kBridgeMaximumDatagram) {
    registry().push_back(this);
}

BridgePeer *Bridge::find(uint64_t link) {
    for (BridgePeer &peer : peers_)
        if (peer.open && peer.link == link)
            return &peer;
    return nullptr;
}

BridgePeer *Bridge::find_remote(const std::string &remote, bool client) {
    for (BridgePeer &peer : peers_)
        if (peer.open && peer.client == client && peer.remote == remote)
            return &peer;
    return nullptr;
}

BridgePeer *Bridge::client_peer() {
    for (BridgePeer &peer : peers_)
        if (peer.open && peer.client)
            return &peer;
    return nullptr;
}

bool Bridge::has_capacity() const {
    return std::count_if(peers_.begin(), peers_.end(), [](const BridgePeer &peer) {
               return peer.open && !peer.client;
           }) < static_cast<ptrdiff_t>(kMaximumRemotePeers);
}

BridgePeer *Bridge::add_incoming(uint64_t link, const std::string &remote) {
    if (remote.empty() || !hosting_ || !has_capacity())
        return nullptr;
    BridgePeer peer{};
    peer.link = link;
    peer.remote = remote;
    peer.started = GetTickCount64();
    peers_.push_back(std::move(peer));
    wake_.notify_one();
    return &peers_.back();
}

BridgePeer *Bridge::add_outgoing(uint64_t link, const std::string &remote, uint64_t game_peer,
                                 bool password_supplied) {
    BridgePeer peer{};
    peer.link = link;
    peer.remote = remote;
    peer.game_peer = game_peer;
    peer.client = true;
    peer.password_supplied = password_supplied;
    peer.started = GetTickCount64();
    peers_.push_back(std::move(peer));
    wake_.notify_one();
    return &peers_.back();
}

void Bridge::connected(BridgePeer &peer) {
    peer.connected = true;
    wake_.notify_one();
}

void Bridge::closed(BridgePeer &peer, const char *message, int code) {
    // Preflight clients close normally while the password is being entered.
    if (peer.client)
        push_event(BridgeEventType::ClientError, peer.remote, message, code);
    close(peer, message);
}

void Bridge::fail(BridgePeer &peer, const char *message, int code) {
    push_event(peer.client ? BridgeEventType::ClientError : BridgeEventType::HostError, peer.remote, message, code);
    close(peer, message);
}

void Bridge::close(BridgePeer &peer, const char *reason) {
    if (!peer.open)
        return;
    if (peer.client && peer.socket != INVALID_SOCKET)
        closesocket(peer.socket);
    transport_.close(peer.link, reason);
    peer.open = false;
    peer.socket = INVALID_SOCKET;
}

bool Bridge::send(BridgePeer &peer, const void *data, uint32_t size, bool reliable) {
    int code = 0;
    switch (transport_.send(peer.link, data, size, reliable, &code)) {
    case BridgeSendResult::Sent:
        stats_.sent_bytes += size;
        return true;
    case BridgeSendResult::Dropped:
        if (!reliable) {
            // Preserve UDP loss semantics under congestion. Engine reliability owns retransmission.
            ++stats_.dropped_datagrams;
            return true;
        }
        break;
    case BridgeSendResult::Failed:
        break;
    }
    char message[128]{};
    std::snprintf(message, sizeof(message), "%s send queue rejected a message", transport_.name());
    fail(peer, message, code);
    return false;
}

bool Bridge::send_datagram(BridgePeer &peer, const uint8_t *data, uint32_t size) {
    const uint32_t limit = transport_.max_message_size();
    if (size + 1 <= limit) {
        buffer_[0] = kDatagram;
        std::memcpy(buffer_.data() + 1, data, size);
        return send(peer, buffer_.data(), size + 1, false);
    }
    const uint32_t chunk = limit - static_cast<uint32_t>(kFragmentHeaderSize);
    const uint32_t count = (size + chunk - 1) / chunk;
    if (limit <= kFragmentHeaderSize || count > kMaximumFragments || size > BridgeReassembly::kCapacity) {
        ++stats_.dropped_datagrams;
        return true;
    }
    ++stats_.fragmented_datagrams;
    const uint16_t sequence = peer.next_fragment_sequence++;
    uint8_t *fragment = buffer_.data();
    for (uint32_t index = 0; index < count; ++index) {
        const uint32_t offset = index * chunk;
        const uint32_t length = (std::min)(chunk, size - offset);
        fragment[0] = kFragment;
        write_u16(fragment + 1, sequence);
        fragment[3] = static_cast<uint8_t>(index);
        fragment[4] = static_cast<uint8_t>(count);
        write_u16(fragment + 5, static_cast<uint16_t>(offset));
        std::memcpy(fragment + kFragmentHeaderSize, data + offset, length);
        if (!send(peer, fragment, static_cast<uint32_t>(kFragmentHeaderSize + length), false))
            return false;
    }
    return true;
}

void Bridge::receive_fragment(BridgePeer &peer, const uint8_t *data, size_t size) {
    if (size <= kFragmentHeaderSize) {
        fail(peer, "Bridge fragment is invalid");
        return;
    }
    const uint16_t sequence = read_u16(data + 1);
    const uint8_t index = data[3];
    const uint8_t count = data[4];
    const size_t offset = read_u16(data + 5);
    const size_t length = size - kFragmentHeaderSize;
    if (count < 2 || count > kMaximumFragments || index >= count || offset + length > BridgeReassembly::kCapacity) {
        fail(peer, "Bridge fragment is invalid");
        return;
    }
    BridgeReassembly *slot = nullptr;
    for (BridgeReassembly &candidate : peer.reassembly)
        if (candidate.count != 0 && candidate.sequence == sequence) {
            slot = &candidate;
            break;
        }
    if (slot == nullptr) {
        // Unreliable fragments may be lost, so recycle the stalest slot.
        slot = &*std::min_element(peer.reassembly.begin(), peer.reassembly.end(),
                                  [](const BridgeReassembly &a, const BridgeReassembly &b) {
                                      return (a.count == 0 ? 0 : a.age + 1) < (b.count == 0 ? 0 : b.age + 1);
                                  });
        if (slot->count != 0)
            ++stats_.dropped_datagrams;
        slot->sequence = sequence;
        slot->count = count;
        slot->received = 0;
        slot->size = 0;
    }
    slot->age = ++peer.reassembly_clock;
    const uint8_t bit = static_cast<uint8_t>(1u << index);
    if (slot->count != count || (slot->received & bit) != 0)
        return;
    std::memcpy(slot->data.data() + offset, data + kFragmentHeaderSize, length);
    slot->received |= bit;
    slot->size = (std::max)(slot->size, static_cast<uint32_t>(offset + length));
    if (slot->received != static_cast<uint8_t>((1u << count) - 1))
        return;
    slot->count = 0;
    deliver(peer, slot->data.data(), static_cast<int>(slot->size));
}

void Bridge::receive(BridgePeer &peer, const uint8_t *data, size_t size) {
    if (!peer.open)
        return;
    if (size < 1 || size > kBridgeMaximumDatagram + 1) {
        fail(peer, "Bridge message size is invalid");
        return;
    }
    stats_.received_bytes += size;
    if (data[0] == kQuery && !peer.client && !peer.ready && size == kQuerySize && data[1] == kProtocol) {
        uint64_t game_peer = 0;
        for (size_t i = 0; i < sizeof(game_peer); ++i)
            game_peer |= static_cast<uint64_t>(data[2 + i]) << (i * 8);
        if (game_peer == 0) {
            fail(peer, "Bridge engine peer identity is invalid");
            return;
        }
        peer.game_peer = game_peer;
        const uint8_t reply[] = {kServerInfo, kProtocol, static_cast<uint8_t>(password_required_)};
        if (send(peer, reply, sizeof(reply), true))
            peer.ready = true;
        return;
    }
    if (data[0] == kServerInfo && peer.client && !peer.ready && size == 3 && data[1] == kProtocol && data[2] <= 1) {
        if (data[2] != 0 && !peer.password_supplied) {
            push_event(BridgeEventType::PasswordRequired, peer.remote);
            close(peer, "Waiting for password input locally");
            return;
        }
        uint32_t port = 0;
        if (!open_client_socket(peer, &port)) {
            fail(peer, "Could not create the local bridge socket", WSAGetLastError());
            return;
        }
        peer.ready = true;
        push_event(BridgeEventType::ClientReady, peer.remote, "", 0, port);
        return;
    }
    if (!peer.ready || size < 2) {
        fail(peer, "Bridge protocol is invalid");
        return;
    }
    if (data[0] == kDatagram) {
        deliver(peer, data + 1, static_cast<int>(size - 1));
        return;
    }
    if (data[0] == kFragment) {
        receive_fragment(peer, data, size);
        return;
    }
    fail(peer, "Bridge protocol is invalid");
}

void Bridge::deliver(BridgePeer &peer, const uint8_t *data, int size) {
    if (!peer.client && peer.socket == INVALID_SOCKET) {
        for (const BridgePeer &other : peers_)
            if (&other != &peer && other.open && !other.client && other.socket != INVALID_SOCKET &&
                other.game_peer == peer.game_peer) {
                fail(peer, "An engine peer is already connected through this transport");
                return;
            }
        for (const HostRoute &saved : routes_)
            if (saved.game_peer == peer.game_peer) {
                if (saved.remote != peer.remote) {
                    fail(peer, "Engine peer belongs to a different remote identity");
                    return;
                }
                peer.socket = saved.socket;
                break;
            }
        if (peer.socket == INVALID_SOCKET && routes_.size() < kMaximumRemotePeers) {
            peer.socket = create_relay_game_socket(reinterpret_cast<const sockaddr *>(&game_target_),
                                                   game_target_size_, peer.game_peer);
            if (peer.socket != INVALID_SOCKET)
                routes_.push_back({peer.game_peer, peer.remote, peer.socket});
        }
        if (peer.socket == INVALID_SOCKET) {
            fail(peer, "Could not create the host bridge socket");
            return;
        }
    }
    if (peer.client && !peer.has_client_address)
        return;
    const int sent = peer.client
                         ? sendto(peer.socket, reinterpret_cast<const char *>(data), size, 0,
                                  reinterpret_cast<const sockaddr *>(&peer.client_address), sizeof(peer.client_address))
                         : ::send(peer.socket, reinterpret_cast<const char *>(data), size, 0);
    if (sent == SOCKET_ERROR) {
        const int error = WSAGetLastError();
        if (error != WSAEWOULDBLOCK)
            fail(peer, "Could not forward a bridge datagram to the game", error);
    }
}

bool Bridge::open_client_socket(BridgePeer &peer, uint32_t *port) {
    peer.socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (peer.socket == INVALID_SOCKET)
        return false;
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    u_long nonblocking = 1;
    int size = sizeof(address);
    if (bind(peer.socket, reinterpret_cast<const sockaddr *>(&address), sizeof(address)) != 0 ||
        ioctlsocket(peer.socket, FIONBIO, &nonblocking) != 0 ||
        getsockname(peer.socket, reinterpret_cast<sockaddr *>(&address), &size) != 0)
        return false;
    *port = ntohs(address.sin_port);
    return true;
}

void Bridge::pump_game_socket(BridgePeer &peer) {
    // send_datagram frames into buffer_, so game datagrams are staged separately.
    std::vector<uint8_t> &staged = staged_;
    for (size_t i = 0; i < kReceiveBatch; ++i) {
        sockaddr_in source{};
        int source_size = sizeof(source);
        const int size = peer.client
                             ? recvfrom(peer.socket, reinterpret_cast<char *>(staged.data()),
                                        static_cast<int>(staged.size()), 0, reinterpret_cast<sockaddr *>(&source),
                                        &source_size)
                             : recv(peer.socket, reinterpret_cast<char *>(staged.data()),
                                    static_cast<int>(staged.size()), 0);
        if (size == SOCKET_ERROR) {
            const int error = WSAGetLastError();
            if (error != WSAEWOULDBLOCK)
                fail(peer, "Could not receive a game datagram", error);
            return;
        }
        if (peer.client) {
            if (source.sin_addr.s_addr != htonl(INADDR_LOOPBACK)) {
                fail(peer, "Bridge received a non-local packet");
                return;
            }
            if (peer.has_client_address && source.sin_port != peer.client_address.sin_port)
                continue;
            peer.client_address = source;
            peer.has_client_address = true;
        }
        if (!send_datagram(peer, staged.data(), static_cast<uint32_t>(size)))
            return;
    }
}

void Bridge::pump(const std::function<void(BridgePeer &)> &receive_messages) {
    // Indexes stay valid while transports append peers from callbacks under the same lock.
    for (size_t index = 0; index < peers_.size(); ++index) {
        if (!peers_[index].open)
            continue;
        if (!peers_[index].ready && GetTickCount64() - peers_[index].started > kQueryTimeoutMs) {
            char message[128]{};
            std::snprintf(message, sizeof(message), "%s connection timed out before the engine handshake",
                          transport_.name());
            fail(peers_[index], message);
            continue;
        }
        if (!peers_[index].connected)
            continue;
        if (peers_[index].client && !peers_[index].ready && !peers_[index].query_sent) {
            uint8_t query[kQuerySize] = {kQuery, kProtocol};
            for (size_t i = 0; i < sizeof(uint64_t); ++i)
                query[2 + i] = static_cast<uint8_t>(peers_[index].game_peer >> (i * 8));
            if (!send(peers_[index], query, sizeof(query), true))
                continue;
            peers_[index].query_sent = true;
        }
        if (receive_messages)
            receive_messages(peers_[index]);
        if (peers_[index].open && peers_[index].socket != INVALID_SOCKET)
            pump_game_socket(peers_[index]);
    }
    peers_.erase(std::remove_if(peers_.begin(), peers_.end(), [](const BridgePeer &peer) { return !peer.open; }),
                 peers_.end());
    for (const HostRoute &route : routes_) {
        const bool used = std::any_of(peers_.begin(), peers_.end(),
                                      [&](const BridgePeer &peer) { return peer.socket == route.socket; });
        if (used)
            continue;
        for (size_t i = 0; i < kReceiveBatch; ++i)
            if (recv(route.socket, reinterpret_cast<char *>(buffer_.data()), static_cast<int>(buffer_.size()), 0) ==
                SOCKET_ERROR)
                break;
    }
}

bool Bridge::start_host(bool password_required, char *error, int error_capacity) {
    if (hosting_)
        return true;
    int port = 0;
    if (!get_local_udp_target(&port, &game_target_, &game_target_size_, error, error_capacity))
        return false;
    password_required_ = password_required;
    hosting_ = true;
    return true;
}

void Bridge::close_routes() {
    for (const HostRoute &route : routes_)
        closesocket(route.socket);
    routes_.clear();
}

void Bridge::stop_host(const char *reason) {
    for (BridgePeer &peer : peers_)
        if (!peer.client)
            close(peer, reason);
    close_routes();
    if (hosting_)
        transport_.host_stopped();
    hosting_ = false;
}

void Bridge::disconnect_client(const char *reason) {
    for (BridgePeer &peer : peers_)
        if (peer.client)
            close(peer, reason);
    clear_client_events();
}

void Bridge::release_game_peer(uint64_t game_peer) {
    for (BridgePeer &peer : peers_)
        if (!peer.client && peer.game_peer == game_peer)
            close(peer, "Game peer released");
    routes_.erase(std::remove_if(routes_.begin(), routes_.end(),
                                 [&](const HostRoute &route) {
                                     if (route.game_peer != game_peer)
                                         return false;
                                     closesocket(route.socket);
                                     return true;
                                 }),
                  routes_.end());
}

void Bridge::close_all(const char *reason) {
    for (BridgePeer &peer : peers_)
        close(peer, reason);
    peers_.clear();
    close_routes();
    if (hosting_)
        transport_.host_stopped();
    hosting_ = false;
}

void Bridge::push_event(BridgeEventType type, const std::string &remote, const char *message, int code,
                        uint32_t port) {
    if (events_.size() >= kMaximumEvents) {
        event_overflow_ = true;
        return;
    }
    BridgeEvent event{};
    event.type = type;
    event.code = code;
    event.port = port;
    event.remote = remote;
    event.message = message ? message : "";
    push_event(std::move(event));
}

void Bridge::push_event(BridgeEvent event) {
    if (events_.size() >= kMaximumEvents) {
        event_overflow_ = true;
        return;
    }
    events_.push_back(std::move(event));
}

int Bridge::poll_event(BridgeEvent *event) {
    if (event_overflow_) {
        event_overflow_ = false;
        return -1;
    }
    if (events_.empty())
        return 0;
    *event = std::move(events_.front());
    events_.pop_front();
    return 1;
}

void Bridge::clear_client_events() {
    events_.erase(std::remove_if(events_.begin(), events_.end(),
                                 [](const BridgeEvent &event) {
                                     return event.type >= BridgeEventType::ClientReady &&
                                            event.type <= BridgeEventType::ClientError;
                                 }),
                  events_.end());
}

void Bridge::clear_events() {
    events_.clear();
    event_overflow_ = false;
}

uint32_t Bridge::connection_count() const {
    return static_cast<uint32_t>(
        std::count_if(peers_.begin(), peers_.end(), [](const BridgePeer &peer) { return peer.open; }));
}

uint16_t Bridge::client_port() const {
    for (const BridgePeer &peer : peers_)
        if (peer.open && peer.client && peer.socket != INVALID_SOCKET) {
            sockaddr_in address{};
            int size = sizeof(address);
            if (getsockname(peer.socket, reinterpret_cast<sockaddr *>(&address), &size) == 0)
                return ntohs(address.sin_port);
        }
    return 0;
}

void release_bridge_peer(uint64_t game_peer) {
    for (Bridge *bridge : registry()) {
        std::lock_guard<std::mutex> lock(bridge->mutex());
        bridge->release_game_peer(game_peer);
    }
}

void stop_bridge_hosts() {
    for (Bridge *bridge : registry()) {
        std::lock_guard<std::mutex> lock(bridge->mutex());
        bridge->stop_host("Realms host closed");
    }
}

} // namespace realms
