#pragma once

#include "realms_internal.h"

#include <array>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <string>
#include <vector>

namespace realms {

// Bridges the engine's loopback UDP traffic onto a message transport (Steam, EOS).
// A client peer exposes a local UDP port the engine connects to as if it were a LAN host.
// A host peer forwards to the engine through a relay socket bound to the remote engine peer.

enum class BridgeEventType : uint32_t {
    JoinRequested = 1,
    ClientReady = 2,
    PasswordRequired = 3,
    ClientError = 4,
    HostError = 5,
};

struct BridgeEvent {
    BridgeEventType type = BridgeEventType::ClientError;
    int32_t code = 0;
    uint32_t port = 0;
    std::string remote;
    std::string text;
    std::string message;
};

struct BridgeStats {
    uint64_t sent_bytes = 0;
    uint64_t received_bytes = 0;
    uint64_t dropped_datagrams = 0;
    uint64_t fragmented_datagrams = 0;
};

enum class BridgeSendResult {
    Sent,
    Dropped,
    Failed,
};

class BridgeTransport {
public:
    virtual ~BridgeTransport() = default;
    // Display name used in diagnostics, e.g. "Steam".
    virtual const char *name() const = 0;
    // Largest message, including the bridge header byte, the transport accepts.
    virtual uint32_t max_message_size() const = 0;
    virtual BridgeSendResult send(uint64_t link, const void *data, uint32_t size, bool reliable, int *code) = 0;
    virtual void close(uint64_t link, const char *reason) = 0;
    virtual void host_stopped() {}
};

inline constexpr size_t kBridgeMaximumDatagram = 65536;

struct BridgeReassembly {
    static constexpr size_t kCapacity = 4096;
    uint16_t sequence = 0;
    uint8_t count = 0;
    uint8_t received = 0;
    uint32_t size = 0;
    uint64_t age = 0;
    std::array<uint8_t, kCapacity> data{};
};

struct BridgePeer {
    uint64_t link = 0;
    std::string remote;
    uint64_t game_peer = 0;
    SOCKET socket = INVALID_SOCKET;
    bool open = true;
    bool client = false;
    bool connected = false;
    bool ready = false;
    bool password_supplied = false;
    bool query_sent = false;
    uint64_t started = 0;
    sockaddr_in client_address{};
    bool has_client_address = false;
    uint16_t next_fragment_sequence = 0;
    uint64_t reassembly_clock = 0;
    std::array<BridgeReassembly, 4> reassembly{};
};

class Bridge {
public:
    explicit Bridge(BridgeTransport &transport);
    Bridge(const Bridge &) = delete;
    Bridge &operator=(const Bridge &) = delete;

    // Every method below expects mutex() to be held by the caller.
    std::mutex &mutex() { return mutex_; }
    std::condition_variable &wake() { return wake_; }

    BridgePeer *find(uint64_t link);
    BridgePeer *find_remote(const std::string &remote, bool client);
    BridgePeer *client_peer();
    bool has_capacity() const;
    BridgePeer *add_incoming(uint64_t link, const std::string &remote);
    BridgePeer *add_outgoing(uint64_t link, const std::string &remote, uint64_t game_peer, bool password_supplied);

    void connected(BridgePeer &peer);
    // The transport reported the link closed. Clients receive this as an error.
    void closed(BridgePeer &peer, const char *message, int code);
    void fail(BridgePeer &peer, const char *message, int code = 0);
    void close(BridgePeer &peer, const char *reason);
    void receive(BridgePeer &peer, const uint8_t *data, size_t size);
    // Runs one I/O step. `receive` pulls transport messages for connection-oriented transports.
    void pump(const std::function<void(BridgePeer &)> &receive);
    bool idle() const { return peers_.empty() && routes_.empty(); }
    bool has_peers() const { return !peers_.empty(); }

    bool start_host(bool password_required, char *error, int error_capacity);
    void stop_host(const char *reason);
    bool hosting() const { return hosting_; }
    void set_password_required(bool required) { password_required_ = required; }
    void disconnect_client(const char *reason);
    void release_game_peer(uint64_t game_peer);
    void close_all(const char *reason);

    void push_event(BridgeEventType type, const std::string &remote, const char *message = "", int code = 0,
                    uint32_t port = 0);
    void push_event(BridgeEvent event);
    // Returns 1 with an event, 0 when empty, -1 after an overflow.
    int poll_event(BridgeEvent *event);
    void clear_client_events();
    void clear_events();

    const BridgeStats &stats() const { return stats_; }
    uint32_t connection_count() const;
    uint16_t client_port() const;

private:
    struct HostRoute {
        uint64_t game_peer;
        std::string remote;
        SOCKET socket;
    };

    bool send(BridgePeer &peer, const void *data, uint32_t size, bool reliable);
    bool send_datagram(BridgePeer &peer, const uint8_t *data, uint32_t size);
    void receive_fragment(BridgePeer &peer, const uint8_t *data, size_t size);
    void deliver(BridgePeer &peer, const uint8_t *data, int size);
    bool open_client_socket(BridgePeer &peer, uint32_t *port);
    void pump_game_socket(BridgePeer &peer);
    void close_routes();

    BridgeTransport &transport_;
    std::mutex mutex_;
    std::condition_variable wake_;
    std::vector<BridgePeer> peers_;
    std::vector<HostRoute> routes_;
    std::deque<BridgeEvent> events_;
    bool event_overflow_ = false;
    bool hosting_ = false;
    bool password_required_ = false;
    sockaddr_storage game_target_{};
    int game_target_size_ = 0;
    BridgeStats stats_{};
    std::vector<uint8_t> buffer_;
    std::vector<uint8_t> staged_;
};

// Every bridge registers itself so engine-side peer teardown reaches each transport.
void release_bridge_peer(uint64_t game_peer);
void stop_bridge_hosts();

} // namespace realms
