#include "realms_bridge.h"
#include "../third_party/steam/isteamnetworkingsockets.h"
#include "../third_party/steam/isteamnetworkingutils.h"

#include <ws2tcpip.h>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>

namespace realms {
namespace {

constexpr int kVirtualPort = 731;
constexpr int kReceiveBatch = 32;
constexpr const char *kJoinArgument = "+realms_join steam:1:";
constexpr int kJoinCallbackId = 337;
constexpr int kPresenceCallbackId = 336;

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

SteamApi g_steam;

class SteamTransport final : public BridgeTransport {
public:
    const char *name() const override { return "Steam"; }
    // Steam fragments large messages itself.
    uint32_t max_message_size() const override { return static_cast<uint32_t>(kBridgeMaximumDatagram + 1); }
    BridgeSendResult send(uint64_t link, const void *data, uint32_t size, bool reliable, int *code) override {
        const int flags = reliable ? k_nSteamNetworkingSend_ReliableNoNagle : k_nSteamNetworkingSend_UnreliableNoNagle;
        const EResult result = g_steam.sockets->SendMessageToConnection(static_cast<HSteamNetConnection>(link), data,
                                                                        size, flags, nullptr);
        *code = static_cast<int>(result);
        if (result == k_EResultOK)
            return BridgeSendResult::Sent;
        return result == k_EResultLimitExceeded ? BridgeSendResult::Dropped : BridgeSendResult::Failed;
    }
    void close(uint64_t link, const char *reason) override {
        g_steam.sockets->CloseConnection(static_cast<HSteamNetConnection>(link), 0, reason, false);
    }
    void host_stopped() override;
};

SteamTransport g_transport;
Bridge g_bridge(g_transport);
JoinCallback g_join_callback;
PresenceCallback g_presence_callback;
uint64_t g_steam_id = 0;
std::atomic<bool> g_presence_updated{false};
HSteamListenSocket g_listen = 0;
bool g_initialized_steam = false;
bool g_winsock = false;
std::atomic<bool> g_running{false};
std::thread g_worker;
std::string g_published;

void SteamTransport::host_stopped() {
    if (g_listen != 0)
        g_steam.sockets->CloseListenSocket(g_listen);
    g_listen = 0;
}

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

std::string id_text(uint64_t id) { return std::to_string(id); }

std::string connect_string(uint64_t id) { return std::string(kJoinArgument) + id_text(id); }

void JoinCallback::Run(void *parameters) {
    if (parameters == nullptr)
        return;
    // GameRichPresenceJoinRequested_t: CSteamID followed by a 256-byte connect string.
    char target[257]{};
    std::memcpy(target, static_cast<const JoinRequest *>(parameters)->connect, sizeof(JoinRequest::connect));
    uint64_t id = 0;
    if (!target_id(target, &id))
        return;
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_bridge.push_event(BridgeEventType::JoinRequested, id_text(id));
}

void PresenceCallback::Run(void *) {
    // A single notification covers a callback batch. Steam owns the actual presence cache.
    g_presence_updated.store(true, std::memory_order_release);
}

void connection_status(SteamNetConnectionStatusChangedCallback_t *change) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    BridgePeer *peer = g_bridge.find(change->m_hConn);
    if (peer == nullptr) {
        if (g_listen == 0 || change->m_info.m_hListenSocket != g_listen ||
            change->m_info.m_eState != k_ESteamNetworkingConnectionState_Connecting)
            return;
        const uint64_t remote_id = change->m_info.m_identityRemote.GetSteamID64();
        peer = remote_id != 0 ? g_bridge.add_incoming(change->m_hConn, id_text(remote_id)) : nullptr;
        if (peer == nullptr) {
            g_steam.sockets->CloseConnection(change->m_hConn, 0, "Realms transport capacity is unavailable", false);
            return;
        }
        if (g_steam.sockets->AcceptConnection(change->m_hConn) != k_EResultOK) {
            g_bridge.fail(*peer, "Could not accept the Steam connection");
            return;
        }
    }
    if (change->m_info.m_eState == k_ESteamNetworkingConnectionState_Connected) {
        if (id_text(change->m_info.m_identityRemote.GetSteamID64()) != peer->remote) {
            g_bridge.fail(*peer, "Steam remote identity changed");
            return;
        }
        g_bridge.connected(*peer);
    } else if (change->m_info.m_eState == k_ESteamNetworkingConnectionState_ClosedByPeer ||
               change->m_info.m_eState == k_ESteamNetworkingConnectionState_ProblemDetectedLocally) {
        g_bridge.closed(*peer, change->m_info.m_szEndDebug, change->m_info.m_eEndReason);
    }
}

void receive_messages(BridgePeer &peer) {
    SteamNetworkingMessage_t *messages[kReceiveBatch]{};
    const int count = g_steam.sockets->ReceiveMessagesOnConnection(static_cast<HSteamNetConnection>(peer.link),
                                                                   messages, kReceiveBatch);
    if (count < 0) {
        g_bridge.fail(peer, "Could not receive Steam messages");
        return;
    }
    for (int i = 0; i < count; ++i) {
        g_bridge.receive(peer, static_cast<const uint8_t *>(messages[i]->m_pData),
                         static_cast<size_t>(messages[i]->m_cbSize));
        messages[i]->Release();
    }
}

void worker_main() {
    std::unique_lock<std::mutex> lock(g_bridge.mutex());
    while (g_running.load(std::memory_order_acquire)) {
        if (g_bridge.idle()) {
            g_bridge.wake().wait(lock,
                                 [] { return !g_running.load(std::memory_order_acquire) || !g_bridge.idle(); });
            continue;
        }
        g_bridge.pump(receive_messages);
        // Only data I/O runs here. Steam's existing game-thread callback dispatcher stays untouched.
        g_bridge.wake().wait_for(lock, std::chrono::milliseconds(1));
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
        g_bridge.push_event(BridgeEventType::JoinRequested, id_text(target));
    return true;
}

SteamNetworkingConfigValue_t status_callback_option() {
    SteamNetworkingConfigValue_t option{};
    option.SetPtr(k_ESteamNetworkingConfig_Callback_ConnectionStatusChanged,
                  reinterpret_cast<void *>(connection_status));
    return option;
}

} // namespace
} // namespace realms

using namespace realms;

int RealmsRuntime_SteamInitialize(char *steam_id, int capacity, char *error, int error_capacity) {
    if (!steam_id || capacity < 21 || !error || error_capacity <= 0) {
        write_error(error, error_capacity, "Steam identity output buffer is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (!initialize_steam(error, error_capacity))
        return 0;
    std::snprintf(steam_id, static_cast<size_t>(capacity), "%llu", static_cast<unsigned long long>(g_steam_id));
    return 1;
}

int RealmsRuntime_SteamStartHost(int password_required, char *error, int error_capacity) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (!g_initialized_steam || !g_local_session_active.load(std::memory_order_acquire)) {
        write_error(error, error_capacity, "A Realms host and Steam identity must be active first");
        return 0;
    }
    if (g_listen != 0)
        return 1;
    if (!g_bridge.start_host(password_required != 0, error, error_capacity))
        return 0;
    const SteamNetworkingConfigValue_t option = status_callback_option();
    g_listen = g_steam.sockets->CreateListenSocketP2P(kVirtualPort, 1, &option);
    if (g_listen == 0) {
        g_bridge.stop_host("Realms host failed");
        write_error(error, error_capacity, "Steam could not create the Realms P2P listener");
        return 0;
    }
    return 1;
}

void RealmsRuntime_SteamStopHost() {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_bridge.stop_host("Realms host closed");
}

void RealmsRuntime_SteamSetPasswordRequired(int required) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_bridge.set_password_required(required != 0);
}

int RealmsRuntime_SteamConnect(const char *steam_id, const char *game_peer_id, int password_supplied, char *error,
                               int error_capacity) {
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
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (!g_initialized_steam) {
        write_error(error, error_capacity, "Steam transport is not initialized");
        return 0;
    }
    if (g_bridge.client_peer() != nullptr) {
        write_error(error, error_capacity, "A Steam client connection is already active");
        return 0;
    }
    g_bridge.clear_client_events();
    SteamNetworkingIdentity identity{};
    identity.SetSteamID64(target);
    const SteamNetworkingConfigValue_t option = status_callback_option();
    const HSteamNetConnection handle = g_steam.sockets->ConnectP2P(identity, kVirtualPort, 1, &option);
    if (!handle) {
        write_error(error, error_capacity, "Steam could not start the P2P connection");
        return 0;
    }
    g_bridge.add_outgoing(handle, id_text(target), game_peer, password_supplied != 0);
    return 1;
}

void RealmsRuntime_SteamDisconnect() {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_bridge.disconnect_client("Realms client closed");
}

int RealmsRuntime_SteamStatus(RealmsSteamStatus *output, char *error, int error_capacity) {
    if (!output || output->struct_size != sizeof(*output)) {
        write_error(error, error_capacity, "Steam status structure size is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (!g_initialized_steam) {
        write_error(error, error_capacity, "Steam transport is not initialized");
        return 0;
    }
    SteamRelayNetworkStatus_t relay{};
    const BridgeStats &stats = g_bridge.stats();
    output->authentication = g_steam.sockets->GetAuthenticationStatus(nullptr);
    output->relay = g_steam.utils->GetRelayNetworkStatus(&relay);
    output->listening = g_listen != 0 ? 1 : 0;
    output->connections = g_bridge.connection_count();
    output->client_port = g_bridge.client_port();
    output->client_state = 0;
    output->sent_bytes = stats.sent_bytes;
    output->received_bytes = stats.received_bytes;
    output->dropped_datagrams = stats.dropped_datagrams;
    if (const BridgePeer *client = g_bridge.client_peer()) {
        SteamNetConnectionInfo_t info{};
        if (g_steam.sockets->GetConnectionInfo(static_cast<HSteamNetConnection>(client->link), &info))
            output->client_state = info.m_eState;
    }
    return 1;
}

void RealmsRuntime_SteamUpdate() {
    // Pump only networking callbacks, on the same thread as the game's Steam dispatcher.
    {
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        if (!g_initialized_steam || (g_listen == 0 && !g_bridge.has_peers()))
            return;
    }
    g_steam.sockets->RunCallbacks();
}

int RealmsRuntime_SteamPollEvent(RealmsSteamEvent *output, char *error, int error_capacity) {
    if (!output || output->struct_size != sizeof(*output)) {
        write_error(error, error_capacity, "Steam event structure size is invalid");
        return -1;
    }
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    BridgeEvent event{};
    const int result = g_bridge.poll_event(&event);
    if (result < 0) {
        write_error(error, error_capacity, "Steam event queue overflowed");
        return -1;
    }
    *output = {};
    output->struct_size = sizeof(*output);
    if (result == 0) {
        if (!g_presence_updated.exchange(false, std::memory_order_acq_rel))
            return 0;
        output->type = REALMS_STEAM_EVENT_PRESENCE_UPDATED;
        return 1;
    }
    output->type = static_cast<uint32_t>(event.type);
    output->code = event.code;
    output->local_port = event.port;
    std::snprintf(output->steam_id, sizeof(output->steam_id), "%s", event.remote.c_str());
    std::snprintf(output->message, sizeof(output->message), "%s", event.message.c_str());
    return 1;
}

int RealmsRuntime_SteamPublishTarget(const char *host_steam_id, char *error, int error_capacity) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
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
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
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
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
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
    g_bridge.wake().notify_one();
    if (g_worker.joinable())
        g_worker.join();
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_bridge.close_all("Realms unloaded");
    g_steam.unregister_callback(&g_join_callback);
    g_steam.unregister_callback(&g_presence_callback);
    g_bridge.clear_events();
    g_presence_updated.store(false, std::memory_order_release);
    if (g_winsock)
        WSACleanup();
    g_winsock = false;
    g_initialized_steam = false;
}
