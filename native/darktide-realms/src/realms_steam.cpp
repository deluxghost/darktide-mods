#include "realms_internal.h"
#include "../third_party/steam/isteamnetworkingsockets.h"
#include "../third_party/steam/isteamnetworkingutils.h"

#include <ws2tcpip.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <string>
#include <thread>
#include <vector>

namespace realms {
namespace {

constexpr int kVirtualPort = 731;
constexpr uint8_t kProtocol = 1;
constexpr uint8_t kDatagram = 0;
constexpr uint8_t kQuery = 1;
constexpr uint8_t kServerInfo = 2;
constexpr size_t kQuerySize = 2 + sizeof(uint64_t);
constexpr size_t kMaximumPacket = 65536;
constexpr size_t kMaximumEvents = 128;
constexpr size_t kReceiveBatch = 32;
constexpr uint64_t kQueryTimeoutMs = 20000;
constexpr const char *kJoinArgument = "+realms_join steam:1:";
constexpr int kJoinCallbackId = 337;
constexpr int kPresenceCallbackId = 336;
using EventType = RealmsSteamEventType;

struct JoinRequest {
    uint64_t friend_id;
    char connect[256];
};
static_assert(sizeof(JoinRequest) == 264);

struct FriendPresenceUpdate {
    uint64_t friend_id;
    int32_t app_id;
};
static_assert(sizeof(FriendPresenceUpdate) == 16);

// SteamAPI_RegisterCallback's public CCallbackBase ABI, without an SDK-owned destructor.
class SteamCallback {
public:
    virtual void Run(void *parameters) = 0;
    virtual void Run(void *parameters, bool, uint64_t) { Run(parameters); }
    virtual int GetCallbackSizeBytes() = 0;
    uint8_t flags = 0;
    int callback_id = 0;
};

class JoinCallback : public SteamCallback {
public:
    void Run(void *parameters) override;
    int GetCallbackSizeBytes() override { return sizeof(JoinRequest); }
};

class PresenceCallback : public SteamCallback {
public:
    void Run(void *parameters) override;
    int GetCallbackSizeBytes() override { return sizeof(FriendPresenceUpdate); }
};

struct SteamApi {
    ISteamNetworkingSockets *sockets = nullptr;
    ISteamNetworkingUtils *utils = nullptr;
    void *friends = nullptr;
    void *apps = nullptr;
    void(__cdecl *register_callback)(void *, int) = nullptr;
    void(__cdecl *unregister_callback)(void *) = nullptr;
    bool(__cdecl *set_presence)(void *, const char *, const char *) = nullptr;
    const char *(__cdecl *get_presence)(void *, uint64_t, const char *) = nullptr;
    bool(__cdecl *invite)(void *, uint64_t, const char *) = nullptr;
    int(__cdecl *launch_command)(void *, char *, int) = nullptr;
};

struct Peer {
    HSteamNetConnection handle = 0;
    uint64_t steam_id = 0;
    uint64_t game_peer = 0;
    SOCKET socket = INVALID_SOCKET;
    bool client = false;
    bool connected = false;
    bool ready = false;
    bool password_supplied = false;
    bool query_sent = false;
    uint64_t started = 0;
    sockaddr_in client_address{};
    bool has_client_address = false;
};

struct HostRoute {
    uint64_t game_peer;
    uint64_t steam_id;
    SOCKET socket;
};

SteamApi g_steam;
JoinCallback g_join_callback;
PresenceCallback g_presence_callback;
uint64_t g_steam_id = 0;
std::mutex g_steam_mutex;
std::condition_variable g_wake;
std::deque<RealmsSteamEvent> g_events;
bool g_event_overflow = false;
std::atomic<bool> g_presence_updated{false};
std::vector<Peer> g_peers;
std::vector<HostRoute> g_routes;
HSteamListenSocket g_listen = 0;
sockaddr_storage g_game_target{};
int g_game_target_size = 0;
bool g_password_required = false;
bool g_initialized_steam = false;
bool g_winsock = false;
std::atomic<bool> g_running{false};
std::thread g_worker;
std::string g_published;
uint64_t g_sent_bytes = 0;
uint64_t g_received_bytes = 0;
uint64_t g_dropped_datagrams = 0;

template <typename T> bool load_export(HMODULE module, const char *name, T *output, char *error, int capacity) {
    *output = reinterpret_cast<T>(GetProcAddress(module, name));
    if (*output != nullptr)
        return true;
    std::snprintf(error, static_cast<size_t>(capacity), "Steam SDK export is missing: %s", name);
    return false;
}

bool parse_id(const char *text, uint64_t *id) {
    if (text == nullptr || *text == '\0' || std::strlen(text) > 20)
        return false;
    for (const char *p = text; *p; ++p)
        if (*p < '0' || *p > '9')
            return false;
    char *end = nullptr;
    errno = 0;
    const unsigned long long value = std::strtoull(text, &end, 10);
    CSteamID steam_id(value);
    if (errno != 0 || end == text || *end != '\0' || !steam_id.IsValid() || !steam_id.BIndividualAccount())
        return false;
    *id = value;
    return true;
}

bool target_id(const char *text, uint64_t *id, bool command_line = false) {
    if (text == nullptr)
        return false;
    const char *argument = std::strstr(text, kJoinArgument);
    if (!argument || (argument != text && argument[-1] != ' ' && argument[-1] != '\t'))
        return false;
    if (!command_line && argument != text)
        return false;
    argument += std::strlen(kJoinArgument);
    const size_t size = std::strspn(argument, "0123456789");
    if (size == 0 || size > 20 || (argument[size] != '\0' && argument[size] != ' ' && argument[size] != '\t'))
        return false;
    if (!command_line && argument[size] != '\0')
        return false;
    char value[21]{};
    std::memcpy(value, argument, size);
    return parse_id(value, id);
}

std::string connect_string(uint64_t id) { return std::string(kJoinArgument) + std::to_string(id); }

void event(EventType type, uint64_t id, const char *message = "", int code = 0, uint32_t port = 0) {
    if (g_events.size() >= kMaximumEvents) {
        g_event_overflow = true;
        return;
    }
    RealmsSteamEvent value{};
    value.struct_size = sizeof(value);
    value.type = type;
    value.code = code;
    value.local_port = port;
    std::snprintf(value.steam_id, sizeof(value.steam_id), "%llu", static_cast<unsigned long long>(id));
    std::snprintf(value.message, sizeof(value.message), "%s", message);
    g_events.push_back(value);
}

void JoinCallback::Run(void *parameters) {
    if (parameters == nullptr)
        return;
    // GameRichPresenceJoinRequested_t: CSteamID followed by a 256-byte connect string.
    char target[257]{};
    std::memcpy(target, static_cast<const JoinRequest *>(parameters)->connect, sizeof(JoinRequest::connect));
    uint64_t id = 0;
    if (!target_id(target, &id))
        return;
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    event(REALMS_STEAM_EVENT_JOIN_REQUESTED, id);
}

void PresenceCallback::Run(void *) {
    // A single notification covers a callback batch; Steam owns the actual presence cache.
    g_presence_updated.store(true, std::memory_order_release);
}

void close_peer(Peer &peer, const char *reason) {
    if (peer.client && peer.socket != INVALID_SOCKET)
        closesocket(peer.socket);
    g_steam.sockets->CloseConnection(peer.handle, 0, reason, false);
    peer.handle = 0;
    peer.socket = INVALID_SOCKET;
}

void fail_peer(Peer &peer, const char *message, int code = 0) {
    if (peer.client)
        event(REALMS_STEAM_EVENT_CLIENT_ERROR, peer.steam_id, message, code);
    else
        event(REALMS_STEAM_EVENT_HOST_ERROR, peer.steam_id, message, code);
    close_peer(peer, message);
}

void connection_status(SteamNetConnectionStatusChangedCallback_t *change) {
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    Peer *peer = nullptr;
    for (Peer &candidate : g_peers)
        if (candidate.handle == change->m_hConn) {
            peer = &candidate;
            break;
        }
    if (peer == nullptr) {
        if (g_listen == 0 || change->m_info.m_hListenSocket != g_listen ||
            change->m_info.m_eState != k_ESteamNetworkingConnectionState_Connecting)
            return;
        const uint64_t remote_id = change->m_info.m_identityRemote.GetSteamID64();
        if (remote_id == 0 || g_peers.size() >= kMaximumRemotePeers) {
            g_steam.sockets->CloseConnection(change->m_hConn, 0, "Realms transport capacity is unavailable", false);
            return;
        }
        Peer incoming{};
        incoming.handle = change->m_hConn;
        incoming.steam_id = remote_id;
        incoming.started = GetTickCount64();
        g_peers.push_back(incoming);
        peer = &g_peers.back();
        if (g_steam.sockets->AcceptConnection(peer->handle) != k_EResultOK) {
            fail_peer(*peer, "Could not accept the Steam connection");
            return;
        }
    }
    if (change->m_info.m_eState == k_ESteamNetworkingConnectionState_Connected) {
        if (change->m_info.m_identityRemote.GetSteamID64() != peer->steam_id) {
            fail_peer(*peer, "Steam remote identity changed");
            return;
        }
        peer->connected = true;
        g_wake.notify_one();
    } else if (change->m_info.m_eState == k_ESteamNetworkingConnectionState_ClosedByPeer ||
               change->m_info.m_eState == k_ESteamNetworkingConnectionState_ProblemDetectedLocally) {
        // Preflight clients close normally while the password is being entered.
        if (peer->client)
            event(REALMS_STEAM_EVENT_CLIENT_ERROR, peer->steam_id, change->m_info.m_szEndDebug,
                  change->m_info.m_eEndReason);
        close_peer(*peer, "Steam connection closed");
    }
}

bool send_message(Peer &peer, const void *data, uint32_t size, int flags) {
    const EResult result = g_steam.sockets->SendMessageToConnection(peer.handle, data, size, flags, nullptr);
    if (result == k_EResultOK) {
        g_sent_bytes += size;
        return true;
    }
    if (result == k_EResultLimitExceeded && (flags & k_nSteamNetworkingSend_Reliable) == 0) {
        // Preserve UDP loss semantics under congestion; engine reliability owns retransmission.
        ++g_dropped_datagrams;
        return true;
    }
    fail_peer(peer, "Steam send queue rejected a message", static_cast<int>(result));
    return false;
}

bool open_client_socket(Peer &peer, uint32_t *port) {
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

void receive_message(Peer &peer, const SteamNetworkingMessage_t &message) {
    if (message.m_cbSize < 1 || message.m_cbSize > static_cast<int>(kMaximumPacket + 1)) {
        fail_peer(peer, "Steam bridge message size is invalid");
        return;
    }
    const auto *data = static_cast<const uint8_t *>(message.m_pData);
    g_received_bytes += static_cast<uint32_t>(message.m_cbSize);
    if (data[0] == kQuery && !peer.client && !peer.ready &&
        message.m_cbSize == static_cast<int>(kQuerySize) && data[1] == kProtocol) {
        for (size_t i = 0; i < sizeof(peer.game_peer); ++i)
            peer.game_peer |= static_cast<uint64_t>(data[2 + i]) << (i * 8);
        if (peer.game_peer == 0) {
            fail_peer(peer, "Steam bridge engine peer identity is invalid");
            return;
        }
        const uint8_t reply[] = {kServerInfo, kProtocol, static_cast<uint8_t>(g_password_required)};
        if (send_message(peer, reply, sizeof(reply), k_nSteamNetworkingSend_ReliableNoNagle))
            peer.ready = true;
        return;
    }
    if (data[0] == kServerInfo && peer.client && !peer.ready && message.m_cbSize == 3 && data[1] == kProtocol &&
        data[2] <= 1) {
        if (data[2] != 0 && !peer.password_supplied) {
            event(REALMS_STEAM_EVENT_PASSWORD_REQUIRED, peer.steam_id);
            close_peer(peer, "Waiting for password input locally");
            return;
        }
        uint32_t port = 0;
        if (!open_client_socket(peer, &port)) {
            fail_peer(peer, "Could not create the local Steam bridge", WSAGetLastError());
            return;
        }
        peer.ready = true;
        event(REALMS_STEAM_EVENT_CLIENT_READY, peer.steam_id, "", 0, port);
        return;
    }
    if (data[0] != kDatagram || !peer.ready || message.m_cbSize < 2) {
        fail_peer(peer, "Steam bridge protocol is invalid");
        return;
    }
    const int size = message.m_cbSize - 1;
    if (!peer.client && peer.socket == INVALID_SOCKET) {
        for (const Peer &other : g_peers)
            if (&other != &peer && !other.client && other.handle != 0 && other.socket != INVALID_SOCKET &&
                other.game_peer == peer.game_peer) {
                fail_peer(peer, "An engine peer is already connected through Steam");
                return;
            }
        for (const HostRoute &saved : g_routes)
            if (saved.game_peer == peer.game_peer) {
                if (saved.steam_id != peer.steam_id) {
                    fail_peer(peer, "Engine peer belongs to a different Steam identity");
                    return;
                }
                peer.socket = saved.socket;
                break;
            }
        if (peer.socket == INVALID_SOCKET && g_routes.size() < kMaximumRemotePeers) {
            peer.socket = create_relay_game_socket(reinterpret_cast<const sockaddr *>(&g_game_target),
                                                   g_game_target_size, peer.game_peer);
            if (peer.socket != INVALID_SOCKET)
                g_routes.push_back({peer.game_peer, peer.steam_id, peer.socket});
        }
        if (peer.socket == INVALID_SOCKET) {
            fail_peer(peer, "Could not create the host Steam bridge");
            return;
        }
    }
    if (peer.client && !peer.has_client_address)
        return;
    const int sent = peer.client
                         ? sendto(peer.socket, reinterpret_cast<const char *>(data + 1), size, 0,
                                  reinterpret_cast<const sockaddr *>(&peer.client_address), sizeof(peer.client_address))
                         : send(peer.socket, reinterpret_cast<const char *>(data + 1), size, 0);
    if (sent == SOCKET_ERROR) {
        const int error = WSAGetLastError();
        if (error != WSAEWOULDBLOCK)
            fail_peer(peer, "Could not forward a Steam datagram to the game", error);
    }
}

void pump_peer(Peer &peer, std::array<uint8_t, kMaximumPacket + 1> &buffer) {
    if (!peer.connected)
        return;
    if (peer.client && !peer.ready && !peer.query_sent) {
        uint8_t query[kQuerySize] = {kQuery, kProtocol};
        for (size_t i = 0; i < sizeof(peer.game_peer); ++i)
            query[2 + i] = static_cast<uint8_t>(peer.game_peer >> (i * 8));
        if (!send_message(peer, query, sizeof(query), k_nSteamNetworkingSend_ReliableNoNagle))
            return;
        peer.query_sent = true;
    }
    SteamNetworkingMessage_t *messages[kReceiveBatch]{};
    const int count =
        g_steam.sockets->ReceiveMessagesOnConnection(peer.handle, messages, static_cast<int>(kReceiveBatch));
    if (count < 0) {
        fail_peer(peer, "Could not receive Steam messages");
        return;
    }
    for (int i = 0; i < count; ++i) {
        if (peer.handle != 0)
            receive_message(peer, *messages[i]);
        messages[i]->Release();
    }
    if (peer.handle == 0 || peer.socket == INVALID_SOCKET)
        return;
    buffer[0] = kDatagram;
    for (size_t i = 0; i < kReceiveBatch; ++i) {
        sockaddr_in source{};
        int source_size = sizeof(source);
        const int size =
            peer.client
                ? recvfrom(peer.socket, reinterpret_cast<char *>(buffer.data() + 1), static_cast<int>(kMaximumPacket),
                           0, reinterpret_cast<sockaddr *>(&source), &source_size)
                : recv(peer.socket, reinterpret_cast<char *>(buffer.data() + 1), static_cast<int>(kMaximumPacket), 0);
        if (size == SOCKET_ERROR) {
            const int error = WSAGetLastError();
            if (error != WSAEWOULDBLOCK)
                fail_peer(peer, "Could not receive a game datagram", error);
            return;
        }
        if (peer.client) {
            if (source.sin_addr.s_addr != htonl(INADDR_LOOPBACK)) {
                fail_peer(peer, "Steam bridge received a non-local packet");
                return;
            }
            if (peer.has_client_address && source.sin_port != peer.client_address.sin_port)
                continue;
            peer.client_address = source;
            peer.has_client_address = true;
        }
        if (!send_message(peer, buffer.data(), static_cast<uint32_t>(size + 1),
                          k_nSteamNetworkingSend_UnreliableNoNagle))
            return;
    }
}

void worker_main() {
    std::array<uint8_t, kMaximumPacket + 1> buffer{};
    std::unique_lock<std::mutex> lock(g_steam_mutex);
    while (g_running.load(std::memory_order_acquire)) {
        if (g_peers.empty() && g_routes.empty()) {
            g_wake.wait(lock, [] {
                return !g_running.load(std::memory_order_acquire) || !g_peers.empty() || !g_routes.empty();
            });
            continue;
        }
        for (Peer &peer : g_peers) {
            if (peer.handle == 0)
                continue;
            if (peer.started != 0 && GetTickCount64() - peer.started > kQueryTimeoutMs && !peer.ready) {
                fail_peer(peer, "Steam connection timed out before the engine handshake");
                continue;
            }
            pump_peer(peer, buffer);
        }
        g_peers.erase(std::remove_if(g_peers.begin(), g_peers.end(), [](const Peer &peer) { return peer.handle == 0; }),
                      g_peers.end());
        for (const HostRoute &route : g_routes) {
            const bool used = std::any_of(g_peers.begin(), g_peers.end(),
                                          [&](const Peer &peer) { return peer.socket == route.socket; });
            if (!used)
                for (size_t i = 0; i < kReceiveBatch; ++i) {
                    if (recv(route.socket, reinterpret_cast<char *>(buffer.data()), static_cast<int>(buffer.size()),
                             0) == SOCKET_ERROR)
                        break;
                }
        }
        // Only data I/O runs here. Steam's existing game-thread callback dispatcher stays untouched.
        g_wake.wait_for(lock, std::chrono::milliseconds(1));
    }
}

bool initialize_steam(char *error, int capacity) {
    if (g_initialized_steam)
        return true;
    HMODULE module = GetModuleHandleW(L"steam_api64.dll");
    if (!module)
        return write_error(error, capacity, "Steam SDK is not loaded by the game");
    ISteamNetworkingSockets *(__cdecl * sockets)() = nullptr;
    ISteamNetworkingUtils *(__cdecl * utils)() = nullptr;
    void *(__cdecl * friends)() = nullptr;
    void *(__cdecl * apps)() = nullptr;
    if (!load_export(module, "SteamAPI_SteamNetworkingSockets_SteamAPI_v012", &sockets, error, capacity) ||
        !load_export(module, "SteamAPI_SteamNetworkingUtils_SteamAPI_v004", &utils, error, capacity) ||
        !load_export(module, "SteamAPI_SteamFriends_v018", &friends, error, capacity) ||
        !load_export(module, "SteamAPI_SteamApps_v008", &apps, error, capacity) ||
        !load_export(module, "SteamAPI_RegisterCallback", &g_steam.register_callback, error, capacity) ||
        !load_export(module, "SteamAPI_UnregisterCallback", &g_steam.unregister_callback, error, capacity) ||
        !load_export(module, "SteamAPI_ISteamFriends_SetRichPresence", &g_steam.set_presence, error, capacity) ||
        !load_export(module, "SteamAPI_ISteamFriends_GetFriendRichPresence", &g_steam.get_presence, error, capacity) ||
        !load_export(module, "SteamAPI_ISteamFriends_InviteUserToGame", &g_steam.invite, error, capacity) ||
        !load_export(module, "SteamAPI_ISteamApps_GetLaunchCommandLine", &g_steam.launch_command, error, capacity))
        return false;
    g_steam.sockets = sockets();
    g_steam.utils = utils();
    g_steam.friends = friends();
    g_steam.apps = apps();
    SteamNetworkingIdentity identity{};
    if (!g_steam.sockets || !g_steam.utils || !g_steam.friends || !g_steam.apps ||
        !g_steam.sockets->GetIdentity(&identity) || identity.GetSteamID64() == 0) {
        return write_error(error, capacity, "The game's Steam identity is not available");
    }
    g_steam_id = identity.GetSteamID64();
    WSADATA data{};
    const int result = WSAStartup(MAKEWORD(2, 2), &data);
    if (result != 0)
        return write_formatted_error(error, capacity, "Steam bridge WSAStartup failed: %lu", result);
    g_winsock = true;
    g_steam.sockets->InitAuthentication();
    g_steam.utils->InitRelayNetworkAccess();
    g_steam.register_callback(&g_join_callback, kJoinCallbackId);
    g_steam.register_callback(&g_presence_callback, kPresenceCallbackId);
    g_running.store(true, std::memory_order_release);
    try {
        g_worker = std::thread(worker_main);
    } catch (const std::system_error &) {
        g_running.store(false, std::memory_order_release);
        g_steam.unregister_callback(&g_join_callback);
        g_steam.unregister_callback(&g_presence_callback);
        WSACleanup();
        g_winsock = false;
        return write_error(error, capacity, "Could not start the Steam bridge thread");
    }
    g_initialized_steam = true;
    char command[4096]{};
    g_steam.launch_command(g_steam.apps, command, sizeof(command));
    uint64_t target = 0;
    if (target_id(command, &target, true) || target_id(GetCommandLineA(), &target, true))
        event(REALMS_STEAM_EVENT_JOIN_REQUESTED, target);
    return true;
}

} // namespace

void release_steam_peer(uint64_t peer_id) {
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    for (Peer &peer : g_peers)
        if (!peer.client && peer.game_peer == peer_id && peer.handle != 0)
            close_peer(peer, "Game peer released");
    g_routes.erase(std::remove_if(g_routes.begin(), g_routes.end(),
                                  [&](const HostRoute &route) {
                                      if (route.game_peer != peer_id)
                                          return false;
                                      closesocket(route.socket);
                                      return true;
                                  }),
                   g_routes.end());
}
} // namespace realms

using namespace realms;

int RealmsRuntime_SteamInitialize(char *steam_id, int capacity, char *error, int error_capacity) {
    if (!steam_id || capacity < 21 || !error || error_capacity <= 0) {
        write_error(error, error_capacity, "Steam identity output buffer is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    if (!initialize_steam(error, error_capacity))
        return 0;
    std::snprintf(steam_id, static_cast<size_t>(capacity), "%llu", static_cast<unsigned long long>(g_steam_id));
    return 1;
}

int RealmsRuntime_SteamStartHost(int password_required, char *error, int error_capacity) {
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    if (!g_initialized_steam || !g_local_session_active.load(std::memory_order_acquire)) {
        write_error(error, error_capacity, "A Realms host and Steam identity must be active first");
        return 0;
    }
    if (g_listen != 0)
        return 1;
    int port = 0;
    if (!get_local_udp_target(&port, &g_game_target, &g_game_target_size, error, error_capacity))
        return 0;
    SteamNetworkingConfigValue_t option{};
    option.SetPtr(k_ESteamNetworkingConfig_Callback_ConnectionStatusChanged,
                  reinterpret_cast<void *>(connection_status));
    g_listen = g_steam.sockets->CreateListenSocketP2P(kVirtualPort, 1, &option);
    if (g_listen == 0) {
        write_error(error, error_capacity, "Steam could not create the Realms P2P listener");
        return 0;
    }
    g_password_required = password_required != 0;
    return 1;
}

void RealmsRuntime_SteamStopHost() {
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    for (Peer &peer : g_peers)
        if (!peer.client && peer.handle != 0)
            close_peer(peer, "Realms host closed");
    for (const HostRoute &route : g_routes)
        closesocket(route.socket);
    g_routes.clear();
    if (g_listen != 0)
        g_steam.sockets->CloseListenSocket(g_listen);
    g_listen = 0;
}

void RealmsRuntime_SteamSetPasswordRequired(int required) {
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    g_password_required = required != 0;
}

int RealmsRuntime_SteamConnect(const char *steam_id, const char *game_peer_id, int password_supplied,
                              char *error, int error_capacity) {
    uint64_t target = 0, game_peer = 0;
    if (!parse_id(steam_id, &target)) {
        write_error(error, error_capacity, "Steam target identity is invalid");
        return 0;
    }
    if (!parse_hex_id(game_peer_id, &game_peer, "Steam bridge engine peer", error, error_capacity))
        return 0;
    if (game_peer == 0) {
        write_error(error, error_capacity, "Steam bridge engine peer identity is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    if (!g_initialized_steam) {
        write_error(error, error_capacity, "Steam transport is not initialized");
        return 0;
    }
    for (const Peer &peer : g_peers)
        if (peer.client && peer.handle != 0) {
            write_error(error, error_capacity, "A Steam client connection is already active");
            return 0;
        }
    g_events.erase(std::remove_if(g_events.begin(), g_events.end(),
                                  [](const RealmsSteamEvent &value) {
                                      return value.type >= REALMS_STEAM_EVENT_CLIENT_READY &&
                                             value.type <= REALMS_STEAM_EVENT_CLIENT_ERROR;
                                  }),
                   g_events.end());
    SteamNetworkingIdentity identity{};
    identity.SetSteamID64(target);
    SteamNetworkingConfigValue_t option{};
    option.SetPtr(k_ESteamNetworkingConfig_Callback_ConnectionStatusChanged,
                  reinterpret_cast<void *>(connection_status));
    Peer peer{};
    peer.handle = g_steam.sockets->ConnectP2P(identity, kVirtualPort, 1, &option);
    if (!peer.handle) {
        write_error(error, error_capacity, "Steam could not start the P2P connection");
        return 0;
    }
    peer.steam_id = target;
    peer.game_peer = game_peer;
    peer.client = true;
    peer.password_supplied = password_supplied != 0;
    peer.started = GetTickCount64();
    g_peers.push_back(peer);
    g_wake.notify_one();
    return 1;
}

void RealmsRuntime_SteamDisconnect() {
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    for (Peer &peer : g_peers)
        if (peer.client && peer.handle != 0)
            close_peer(peer, "Realms client closed");
    g_events.erase(std::remove_if(g_events.begin(), g_events.end(),
                                  [](const RealmsSteamEvent &value) {
                                      return value.type >= REALMS_STEAM_EVENT_CLIENT_READY &&
                                             value.type <= REALMS_STEAM_EVENT_CLIENT_ERROR;
                                  }),
                   g_events.end());
}

int RealmsRuntime_SteamStatus(RealmsSteamStatus *output, char *error, int error_capacity) {
    if (!output || output->struct_size != sizeof(*output)) {
        write_error(error, error_capacity, "Steam status structure size is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    if (!g_initialized_steam) {
        write_error(error, error_capacity, "Steam transport is not initialized");
        return 0;
    }
    SteamRelayNetworkStatus_t relay{};
    output->authentication = g_steam.sockets->GetAuthenticationStatus(nullptr);
    output->relay = g_steam.utils->GetRelayNetworkStatus(&relay);
    output->listening = g_listen != 0 ? 1 : 0;
    output->connections = 0;
    output->client_port = 0;
    output->client_state = 0;
    output->sent_bytes = g_sent_bytes;
    output->received_bytes = g_received_bytes;
    output->dropped_datagrams = g_dropped_datagrams;
    for (const Peer &peer : g_peers)
        if (peer.handle != 0) {
            ++output->connections;
            if (peer.client) {
                SteamNetConnectionInfo_t info{};
                if (g_steam.sockets->GetConnectionInfo(peer.handle, &info))
                    output->client_state = info.m_eState;
            }
            if (peer.client && peer.socket != INVALID_SOCKET) {
                sockaddr_in address{};
                int size = sizeof(address);
                if (getsockname(peer.socket, reinterpret_cast<sockaddr *>(&address), &size) == 0)
                    output->client_port = ntohs(address.sin_port);
            }
        }
    return 1;
}

void RealmsRuntime_SteamUpdate() {
    // Pump only networking callbacks, on the same thread as the game's Steam dispatcher.
    {
        std::lock_guard<std::mutex> lock(g_steam_mutex);
        if (!g_initialized_steam || (g_listen == 0 && g_peers.empty()))
            return;
    }
    g_steam.sockets->RunCallbacks();
}

int RealmsRuntime_SteamPollEvent(RealmsSteamEvent *output, char *error, int error_capacity) {
    if (!output || output->struct_size != sizeof(*output)) {
        write_error(error, error_capacity, "Steam event structure size is invalid");
        return -1;
    }
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    if (g_event_overflow) {
        g_event_overflow = false;
        write_error(error, error_capacity, "Steam event queue overflowed");
        return -1;
    }
    if (g_events.empty() && g_presence_updated.exchange(false, std::memory_order_acq_rel)) {
        *output = {};
        output->struct_size = sizeof(*output);
        output->type = REALMS_STEAM_EVENT_PRESENCE_UPDATED;
        return 1;
    }
    if (g_events.empty())
        return 0;
    *output = g_events.front();
    g_events.pop_front();
    return 1;
}

int RealmsRuntime_SteamPublishTarget(const char *host_steam_id, char *error, int error_capacity) {
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    if (!g_initialized_steam) {
        write_error(error, error_capacity, "Steam transport is not initialized");
        return 0;
    }
    uint64_t id = 0;
    if (host_steam_id && *host_steam_id && !parse_id(host_steam_id, &id)) {
        write_error(error, error_capacity, "Steam host identity is invalid");
        return 0;
    }
    const char *current = g_steam.get_presence(g_steam.friends, g_steam_id, "connect");
    const std::string observed = current ? current : "";
    if (id == 0) {
        if (!g_published.empty() && observed == g_published &&
            !g_steam.set_presence(g_steam.friends, "connect", nullptr)) {
            write_error(error, error_capacity, "Could not clear Steam join information");
            return 0;
        }
        g_published.clear();
        return 1;
    }
    const std::string target = connect_string(id);
    if (observed == target) {
        g_published = target;
        return 1;
    }
    if (!g_steam.set_presence(g_steam.friends, "connect", target.c_str())) {
        write_error(error, error_capacity, "Could not publish Steam join information");
        return 0;
    }
    g_published = target;
    return 1;
}

int RealmsRuntime_SteamFriendTarget(const char *steam_id, char *host, int capacity, char *error, int error_capacity) {
    uint64_t id = 0;
    if (!parse_id(steam_id, &id) || !host || capacity < 21) {
        write_error(error, error_capacity, "Steam friend target arguments are invalid");
        return -1;
    }
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    if (!g_initialized_steam) {
        write_error(error, error_capacity, "Steam transport is not initialized");
        return -1;
    }
    uint64_t target = 0;
    if (!target_id(g_steam.get_presence(g_steam.friends, id, "connect"), &target))
        return 0;
    std::snprintf(host, static_cast<size_t>(capacity), "%llu", static_cast<unsigned long long>(target));
    return 1;
}

int RealmsRuntime_SteamInvite(const char *steam_id, const char *host_steam_id, char *error, int error_capacity) {
    uint64_t friend_id = 0, host = 0;
    if (!parse_id(steam_id, &friend_id) || !parse_id(host_steam_id, &host)) {
        write_error(error, error_capacity, "Steam invite identities are invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    if (!g_initialized_steam || !g_steam.invite(g_steam.friends, friend_id, connect_string(host).c_str())) {
        write_error(error, error_capacity, "Steam could not send the game invitation");
        return 0;
    }
    return 1;
}

void RealmsRuntime_SteamShutdown() {
    if (!g_initialized_steam)
        return;
    char error[256]{};
    if (!RealmsRuntime_SteamPublishTarget("", error, sizeof(error)))
        push_runtime_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_SEND, 0, 0, error);
    g_running.store(false, std::memory_order_release);
    g_wake.notify_one();
    if (g_worker.joinable())
        g_worker.join();
    std::lock_guard<std::mutex> lock(g_steam_mutex);
    for (Peer &peer : g_peers)
        if (peer.handle != 0)
            close_peer(peer, "Realms unloaded");
    g_peers.clear();
    for (const HostRoute &route : g_routes)
        closesocket(route.socket);
    g_routes.clear();
    if (g_listen)
        g_steam.sockets->CloseListenSocket(g_listen);
    g_listen = 0;
    g_steam.unregister_callback(&g_join_callback);
    g_steam.unregister_callback(&g_presence_callback);
    g_events.clear();
    g_event_overflow = false;
    g_presence_updated.store(false, std::memory_order_release);
    if (g_winsock)
        WSACleanup();
    g_winsock = false;
    g_initialized_steam = false;
}
