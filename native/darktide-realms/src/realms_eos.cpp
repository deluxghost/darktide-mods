#include "realms_bridge.h"
#include "eos/eos_api.h"

#include <shlobj.h>
#include <algorithm>
#include <chrono>
#include <deque>
#include <iterator>
#include <memory>
#include <cstdio>
#include <cstring>
#include <functional>
#include <random>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#if __has_include("realms_eos_config.h")
#include "realms_eos_config.h"
#endif
#ifndef REALMS_EOS_PRODUCT_ID
#define REALMS_EOS_PRODUCT_ID ""
#define REALMS_EOS_SANDBOX_ID ""
#define REALMS_EOS_DEPLOYMENT_ID ""
#define REALMS_EOS_CLIENT_ID ""
#define REALMS_EOS_CLIENT_SECRET ""
#endif

namespace realms {
namespace {

// All EOS calls happen on g_worker. Public entry points only queue commands or read snapshots.
// Bridge state, commands and the snapshot share the bridge mutex. EOS callbacks fire during
// EOS_Platform_Tick, which runs without the lock held, so callbacks lock it themselves.

constexpr const wchar_t *kSdkLibrary = L"EOSSDK-Win64-Shipping.dll";
constexpr const char *kSocketName = "realms";
constexpr const char *kLobbyBucket = "realms:1";
constexpr const char *kCodeAttribute = "code";
constexpr const char *kCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
constexpr size_t kDisplayNameLimit = 32;
constexpr int kReceiveBatch = 256;
constexpr auto kActiveWait = std::chrono::milliseconds(1);
constexpr auto kIdleWait = std::chrono::milliseconds(16);
constexpr uint64_t kStopTimeoutMs = 1500;
constexpr uint64_t kSignInRetryMs = 30000;

using Command = std::function<void()>;

class EosTransport final : public BridgeTransport {
public:
    const char *name() const override { return "EOS"; }
    uint32_t max_message_size() const override { return eos::kP2PMaxPacketSize; }
    BridgeSendResult send(uint64_t link, const void *data, uint32_t size, bool reliable, int *code) override;
    void close(uint64_t link, const char *reason) override;
    void host_stopped() override;
};

struct Snapshot {
    uint32_t state = REALMS_EOS_STATE_STOPPED;
    int32_t last_result = 0;
    int32_t nat_type = 0;
    int32_t client_network_type = -1;
    std::string local_id;
};

EosTransport g_transport;
Bridge g_bridge(g_transport);
eos::Api g_api;
HMODULE g_library = nullptr;
bool g_sdk_initialized = false;
std::thread g_worker;
std::atomic<bool> g_running{false};
std::atomic<DWORD> g_worker_thread{0};
bool g_exiting = false;
bool g_winsock = false;

// Guarded by the bridge mutex. Links are also closed from the game thread.
std::vector<Command> g_commands;
std::unordered_map<uint64_t, std::string> g_links;
uint64_t g_next_link = 1;
std::vector<std::string> g_pending_closes;
Snapshot g_snapshot;
bool g_accepting = false;

// Worker-thread only.
eos::HPlatform g_platform = nullptr;
eos::HConnect g_connect = nullptr;
eos::HP2P g_p2p = nullptr;
eos::HLobby g_lobby = nullptr;
eos::ProductUserId g_local_user = nullptr;
std::string g_display_name;
eos::NotificationId g_auth_expiration = eos::kInvalidNotificationId;
eos::NotificationId g_connection_request = eos::kInvalidNotificationId;
eos::NotificationId g_connection_established = eos::kInvalidNotificationId;
eos::NotificationId g_connection_closed = eos::kInvalidNotificationId;
std::string g_lobby_id;
bool g_lobby_pending = false;
bool g_lobby_destroy_pending = false;
uint64_t g_lobby_generation = 0;
uint64_t g_sign_in_retry_at = 0;
eos::P2PSocketId g_socket{};
std::vector<uint8_t> g_receive_buffer(eos::kP2PMaxPacketSize);

// EOS may log synchronously from inside any SDK call, including calls made under the bridge mutex,
// so log lines use their own queue and are merged into the event stream on poll.
std::mutex g_log_mutex;
std::deque<BridgeEvent> g_log;
constexpr size_t kMaximumLogEvents = 64;

bool pop_log(BridgeEvent *event) {
    std::lock_guard<std::mutex> lock(g_log_mutex);
    if (g_log.empty())
        return false;
    *event = std::move(g_log.front());
    g_log.pop_front();
    return true;
}

bool on_worker() { return GetCurrentThreadId() == g_worker_thread.load(std::memory_order_acquire); }

std::string result_text(eos::Result result) {
    const char *text = g_api.result_to_string ? g_api.result_to_string(result) : nullptr;
    return text ? text : std::to_string(result);
}

std::string user_text(eos::ProductUserId user) {
    char buffer[eos::kProductUserIdMaxLength + 1]{};
    int32_t size = sizeof(buffer);
    if (user == nullptr || g_api.product_user_id_to_string(user, buffer, &size) != eos::kSuccess)
        return {};
    return buffer;
}

bool valid_user_text(const char *text) {
    if (text == nullptr)
        return false;
    const size_t size = std::strlen(text);
    if (size == 0 || size > eos::kProductUserIdMaxLength)
        return false;
    return std::all_of(text, text + size, [](char c) {
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
    });
}

bool valid_code(const char *code) {
    if (code == nullptr || std::strlen(code) != REALMS_EOS_CODE_LENGTH)
        return false;
    for (const char *p = code; *p; ++p)
        if (std::strchr(kCodeAlphabet, *p) == nullptr)
            return false;
    return true;
}

std::string generate_code() {
    std::random_device random;
    std::uniform_int_distribution<size_t> pick(0, std::strlen(kCodeAlphabet) - 1);
    std::string code;
    for (int i = 0; i < REALMS_EOS_CODE_LENGTH; ++i)
        code.push_back(kCodeAlphabet[pick(random)]);
    return code;
}

std::string truncate_utf8(const std::string &text, size_t limit) {
    if (text.size() <= limit)
        return text;
    size_t size = limit;
    while (size > 0 && (static_cast<uint8_t>(text[size]) & 0xc0) == 0x80)
        --size;
    return text.substr(0, size);
}

// Requires the bridge mutex.
void event(RealmsEosEventType type, const std::string &remote = {}, const std::string &text = {},
           const std::string &message = {}, int code = 0) {
    BridgeEvent value{};
    value.type = static_cast<BridgeEventType>(type);
    value.code = code;
    value.remote = remote;
    value.text = text;
    value.message = message;
    g_bridge.push_event(std::move(value));
}

void locked_event(RealmsEosEventType type, const std::string &remote = {}, const std::string &text = {},
                  const std::string &message = {}, int code = 0) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    event(type, remote, text, message, code);
}

void set_state(RealmsEosState state, eos::Result result = 0) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_snapshot.state = state;
    g_snapshot.last_result = result;
}

void login_failed(const char *message, eos::Result result) {
    set_state(REALMS_EOS_STATE_FAILED, result);
    locked_event(REALMS_EOS_EVENT_LOGIN_FAILED, {}, {}, std::string(message) + ": " + result_text(result), result);
}

// Sign-in is retried periodically. A failed refresh keeps the signed-in state, so connected peers and
// the invite lobby stay up while the retry runs.
void sign_in_failed(const char *message, eos::Result result) {
    g_sign_in_retry_at = GetTickCount64() + kSignInRetryMs;
    bool refreshing = false;
    {
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        refreshing = g_snapshot.state == REALMS_EOS_STATE_READY;
    }
    if (refreshing)
        locked_event(REALMS_EOS_EVENT_LOG, {}, "Realms", std::string(message) + ": " + result_text(result));
    else
        login_failed(message, result);
}

uint64_t link_for(const std::string &remote) {
    for (const auto &[link, value] : g_links)
        if (value == remote)
            return link;
    const uint64_t link = g_next_link++;
    g_links.emplace(link, remote);
    return link;
}

eos::P2PConnectionOptions connection_options(const std::string &remote) {
    eos::P2PConnectionOptions options{};
    options.ApiVersion = eos::P2PConnectionOptions::kApiVersion;
    options.LocalUserId = g_local_user;
    options.RemoteUserId = g_api.product_user_id_from_string(remote.c_str());
    options.SocketId = &g_socket;
    return options;
}

void close_connection(const std::string &remote) {
    if (g_p2p == nullptr || g_local_user == nullptr)
        return;
    const eos::P2PConnectionOptions options = connection_options(remote);
    g_api.p2p_close_connection(g_p2p, &options);
}

BridgeSendResult EosTransport::send(uint64_t link, const void *data, uint32_t size, bool reliable, int *code) {
    const auto found = g_links.find(link);
    if (!on_worker() || found == g_links.end() || g_p2p == nullptr || g_local_user == nullptr) {
        *code = eos::kNoConnection;
        return BridgeSendResult::Failed;
    }
    eos::P2PSendPacketOptions options{};
    options.ApiVersion = eos::P2PSendPacketOptions::kApiVersion;
    options.LocalUserId = g_local_user;
    options.RemoteUserId = g_api.product_user_id_from_string(found->second.c_str());
    options.SocketId = &g_socket;
    options.Channel = 0;
    options.DataLengthBytes = size;
    options.Data = data;
    // Control messages may wait for the connection to open, while game datagrams keep UDP semantics.
    options.bAllowDelayedDelivery = reliable ? eos::kTrue : eos::kFalse;
    options.Reliability = reliable ? eos::kPacketReliableOrdered : eos::kPacketUnreliableUnordered;
    options.bDisableAutoAcceptConnection = eos::kFalse;
    const eos::Result result = g_api.p2p_send_packet(g_p2p, &options);
    *code = result;
    if (result == eos::kSuccess)
        return BridgeSendResult::Sent;
    return result == eos::kLimitExceeded || result == eos::kNoConnection ? BridgeSendResult::Dropped
                                                                         : BridgeSendResult::Failed;
}

void EosTransport::close(uint64_t link, const char *) {
    const auto found = g_links.find(link);
    if (found == g_links.end())
        return;
    const std::string remote = found->second;
    g_links.erase(found);
    if (on_worker())
        close_connection(remote);
    else
        g_pending_closes.push_back(remote);
}

void create_lobby();
void destroy_lobby();

// Requires the bridge mutex. A lobby operation that finished for an outdated generation hands the
// lobby to the current generation, or removes it when invites were closed in the meantime.
void reconcile_lobby() {
    g_commands.push_back(g_accepting ? Command(create_lobby) : Command(destroy_lobby));
}

void EosTransport::host_stopped() {
    g_accepting = false;
    g_commands.push_back(destroy_lobby);
}

// ---- Lobby invite codes ----------------------------------------------------------------------

void add_string_attribute(eos::HLobbyModification modification, const char *key, const std::string &value,
                          eos::Result *result) {
    if (*result != eos::kSuccess)
        return;
    eos::LobbyAttributeData data{};
    data.ApiVersion = eos::LobbyAttributeData::kApiVersion;
    data.Key = key;
    data.Value.AsUtf8 = value.c_str();
    data.ValueType = eos::kAttributeString;
    eos::LobbyModificationAddAttributeOptions options{};
    options.ApiVersion = eos::LobbyModificationAddAttributeOptions::kApiVersion;
    options.Attribute = &data;
    options.Visibility = eos::kLobbyAttributePublic;
    *result = g_api.lobby_modification_add_attribute(modification, &options);
}

void host_code_failed(const char *message, eos::Result result) {
    g_lobby_pending = false;
    locked_event(REALMS_EOS_EVENT_HOST_CODE_FAILED, {}, {}, std::string(message) + ": " + result_text(result), result);
}

void publish_lobby_code(uint64_t generation) {
    {
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        if (!g_accepting || generation != g_lobby_generation) {
            g_lobby_pending = false;
            reconcile_lobby();
            return;
        }
    }
    const std::string code = generate_code();
    eos::LobbyUpdateLobbyModificationOptions options{};
    options.ApiVersion = eos::LobbyUpdateLobbyModificationOptions::kApiVersion;
    options.LocalUserId = g_local_user;
    options.LobbyId = g_lobby_id.c_str();
    eos::HLobbyModification modification = nullptr;
    eos::Result result = g_api.lobby_update_lobby_modification(g_lobby, &options, &modification);
    add_string_attribute(modification, kCodeAttribute, code, &result);
    if (result != eos::kSuccess) {
        if (modification)
            g_api.lobby_modification_release(modification);
        host_code_failed("Could not prepare the EOS invite code", result);
        return;
    }
    eos::LobbyUpdateLobbyOptions update{};
    update.ApiVersion = eos::LobbyUpdateLobbyOptions::kApiVersion;
    update.LobbyModificationHandle = modification;
    auto *context = new std::pair<uint64_t, std::string>(generation, code);
    g_api.lobby_update_lobby(g_lobby, &update, context, [](const eos::LobbyUpdateLobbyCallbackInfo *info) {
        std::unique_ptr<std::pair<uint64_t, std::string>> context(
            static_cast<std::pair<uint64_t, std::string> *>(info->ClientData));
        g_lobby_pending = false;
        if (info->ResultCode != eos::kSuccess) {
            host_code_failed("Could not publish the EOS invite code", info->ResultCode);
            return;
        }
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        if (!g_accepting || context->first != g_lobby_generation) {
            reconcile_lobby();
            return;
        }
        // The lobby id travels in the message so test runs can be matched against the portal.
        event(REALMS_EOS_EVENT_HOST_CODE, {}, context->second, g_lobby_id);
    });
    g_api.lobby_modification_release(modification);
}

void create_lobby() {
    uint64_t generation = 0;
    {
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        if (!g_accepting)
            return;
        generation = g_lobby_generation;
    }
    if (g_lobby_pending || g_local_user == nullptr)
        return;
    if (!g_lobby_id.empty()) {
        g_lobby_pending = true;
        publish_lobby_code(generation);
        return;
    }
    eos::LobbyCreateLobbyOptions options{};
    options.ApiVersion = eos::LobbyCreateLobbyOptions::kApiVersion;
    options.LocalUserId = g_local_user;
    // The lobby only advertises the host, and Realms manages membership itself. A full lobby is not
    // searchable, so leave room beyond the owner.
    options.MaxLobbyMembers = 2;
    options.PermissionLevel = eos::kLobbyPermissionPublicAdvertised;
    options.bPresenceEnabled = eos::kFalse;
    options.bAllowInvites = eos::kFalse;
    options.BucketId = kLobbyBucket;
    options.bDisableHostMigration = eos::kTrue;
    options.bEnableRTCRoom = eos::kFalse;
    options.bEnableJoinById = eos::kFalse;
    options.bRejoinAfterKickRequiresInvite = eos::kFalse;
    options.bCrossplayOptOut = eos::kFalse;
    g_lobby_pending = true;
    g_api.lobby_create_lobby(g_lobby, &options, reinterpret_cast<void *>(generation),
                             [](const eos::LobbyCreateLobbyCallbackInfo *info) {
                                 if (info->ResultCode != eos::kSuccess) {
                                     host_code_failed("Could not create the EOS invite lobby", info->ResultCode);
                                     return;
                                 }
                                 g_lobby_id = info->LobbyId ? info->LobbyId : "";
                                 bool stale = false;
                                 {
                                     std::lock_guard<std::mutex> lock(g_bridge.mutex());
                                     stale = !g_accepting;
                                 }
                                 if (stale) {
                                     g_lobby_pending = false;
                                     destroy_lobby();
                                     return;
                                 }
                                 publish_lobby_code(reinterpret_cast<uint64_t>(info->ClientData));
                             });
}

void destroy_lobby() {
    if (g_lobby_id.empty() || g_lobby_destroy_pending || g_local_user == nullptr)
        return;
    eos::LobbyDestroyLobbyOptions options{};
    options.ApiVersion = eos::LobbyDestroyLobbyOptions::kApiVersion;
    options.LocalUserId = g_local_user;
    options.LobbyId = g_lobby_id.c_str();
    g_lobby_destroy_pending = true;
    locked_event(REALMS_EOS_EVENT_LOG, {}, "Realms", "Destroying invite lobby " + g_lobby_id);
    g_api.lobby_destroy_lobby(g_lobby, &options, nullptr, [](const eos::LobbyDestroyLobbyCallbackInfo *) {
        g_lobby_destroy_pending = false;
    });
    g_lobby_id.clear();
}

void resolve_code(const std::string &code) {
    auto fail = [&](const std::string &message) {
        locked_event(REALMS_EOS_EVENT_CODE_FAILED, {}, code, message, REALMS_EOS_CODE_ERROR_SERVICE);
    };
    if (g_local_user == nullptr) {
        fail("EOS is not signed in");
        return;
    }
    eos::LobbyCreateLobbySearchOptions options{};
    options.ApiVersion = eos::LobbyCreateLobbySearchOptions::kApiVersion;
    options.MaxResults = 1;
    eos::HLobbySearch search = nullptr;
    eos::Result result = g_api.lobby_create_lobby_search(g_lobby, &options, &search);
    auto parameter = [&](const char *key, const char *value) {
        if (result != eos::kSuccess)
            return;
        eos::LobbyAttributeData data{};
        data.ApiVersion = eos::LobbyAttributeData::kApiVersion;
        data.Key = key;
        data.Value.AsUtf8 = value;
        data.ValueType = eos::kAttributeString;
        eos::LobbySearchSetParameterOptions parameter_options{};
        parameter_options.ApiVersion = eos::LobbySearchSetParameterOptions::kApiVersion;
        parameter_options.Parameter = &data;
        parameter_options.ComparisonOp = eos::kComparisonEqual;
        result = g_api.lobby_search_set_parameter(search, &parameter_options);
    };
    parameter(eos::kLobbySearchBucketId, kLobbyBucket);
    parameter(kCodeAttribute, code.c_str());
    if (result != eos::kSuccess) {
        if (search)
            g_api.lobby_search_release(search);
        fail("Could not prepare the EOS invite search: " + result_text(result));
        return;
    }
    eos::LobbySearchFindOptions find{};
    find.ApiVersion = eos::LobbySearchFindOptions::kApiVersion;
    find.LocalUserId = g_local_user;
    auto *context = new std::pair<eos::HLobbySearch, std::string>(search, code);
    g_api.lobby_search_find(search, &find, context, [](const eos::LobbySearchFindCallbackInfo *info) {
        std::unique_ptr<std::pair<eos::HLobbySearch, std::string>> context(
            static_cast<std::pair<eos::HLobbySearch, std::string> *>(info->ClientData));
        eos::HLobbySearch search = context->first;
        const std::string &code = context->second;
        std::string owner;
        eos::Result result = info->ResultCode;
        if (result == eos::kSuccess) {
            eos::LobbySearchGetSearchResultCountOptions count_options{};
            count_options.ApiVersion = eos::LobbySearchGetSearchResultCountOptions::kApiVersion;
            if (g_api.lobby_search_get_search_result_count(search, &count_options) == 0)
                result = eos::kNotFound;
        }
        if (result == eos::kSuccess) {
            eos::LobbySearchCopySearchResultByIndexOptions copy{};
            copy.ApiVersion = eos::LobbySearchCopySearchResultByIndexOptions::kApiVersion;
            copy.LobbyIndex = 0;
            eos::HLobbyDetails details = nullptr;
            result = g_api.lobby_search_copy_search_result_by_index(search, &copy, &details);
            if (result == eos::kSuccess) {
                eos::LobbyDetailsGetLobbyOwnerOptions owner_options{};
                owner_options.ApiVersion = eos::LobbyDetailsGetLobbyOwnerOptions::kApiVersion;
                owner = user_text(g_api.lobby_details_get_lobby_owner(details, &owner_options));
                g_api.lobby_details_release(details);
                if (owner.empty())
                    result = eos::kNotFound;
            }
        }
        g_api.lobby_search_release(search);
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        if (result == eos::kSuccess)
            event(REALMS_EOS_EVENT_CODE_RESOLVED, owner, code);
        else if (result == eos::kNotFound)
            event(REALMS_EOS_EVENT_CODE_FAILED, {}, code, "No host uses this invite code",
                  REALMS_EOS_CODE_ERROR_NOT_FOUND);
        else
            event(REALMS_EOS_EVENT_CODE_FAILED, {}, code, "EOS invite search failed: " + result_text(result),
                  REALMS_EOS_CODE_ERROR_SERVICE);
    });
}

// ---- P2P -------------------------------------------------------------------------------------

void register_p2p_notifications() {
    eos::P2PAddNotifyOptions options{};
    options.ApiVersion = eos::P2PAddNotifyOptions::kApiVersion;
    options.LocalUserId = g_local_user;
    options.SocketId = &g_socket;
    if (g_connection_request == eos::kInvalidNotificationId)
        g_connection_request = g_api.p2p_add_notify_peer_connection_request(
            g_p2p, &options, nullptr, [](const eos::P2PIncomingConnectionRequestInfo *info) {
                const std::string remote = user_text(info->RemoteUserId);
                std::lock_guard<std::mutex> lock(g_bridge.mutex());
                BridgePeer *peer = remote.empty() ? nullptr : g_bridge.find_remote(remote, false);
                if (peer == nullptr && g_accepting && !remote.empty())
                    peer = g_bridge.add_incoming(link_for(remote), remote);
                if (peer == nullptr) {
                    if (!remote.empty())
                        close_connection(remote);
                    return;
                }
                const eos::P2PConnectionOptions accept = connection_options(remote);
                const eos::Result result = g_api.p2p_accept_connection(g_p2p, &accept);
                if (result != eos::kSuccess) {
                    g_bridge.fail(*peer, "Could not accept the EOS connection", result);
                    return;
                }
                g_bridge.connected(*peer);
            });
    if (g_connection_established == eos::kInvalidNotificationId)
        g_connection_established = g_api.p2p_add_notify_peer_connection_established(
            g_p2p, &options, nullptr, [](const eos::P2PPeerConnectionEstablishedInfo *info) {
                const std::string remote = user_text(info->RemoteUserId);
                std::lock_guard<std::mutex> lock(g_bridge.mutex());
                if (const BridgePeer *peer = g_bridge.client_peer(); peer && peer->remote == remote)
                    g_snapshot.client_network_type = info->NetworkType;
            });
    if (g_connection_closed == eos::kInvalidNotificationId)
        g_connection_closed = g_api.p2p_add_notify_peer_connection_closed(
            g_p2p, &options, nullptr, [](const eos::P2PRemoteConnectionClosedInfo *info) {
                static constexpr const char *kReasons[] = {
                    "unknown",          "closed locally",    "closed by peer",       "timed out",
                    "too many connections", "invalid message", "invalid data",        "connection failed",
                    "connection closed", "negotiation failed", "unexpected error",   "connection ignored",
                };
                const std::string remote = user_text(info->RemoteUserId);
                const char *reason = info->Reason >= 0 && info->Reason < static_cast<int32_t>(std::size(kReasons))
                                         ? kReasons[info->Reason]
                                         : "unknown";
                const std::string message = std::string("EOS connection ") + reason;
                std::lock_guard<std::mutex> lock(g_bridge.mutex());
                for (bool client : {true, false})
                    if (BridgePeer *peer = g_bridge.find_remote(remote, client)) {
                        g_links.erase(peer->link);
                        g_bridge.closed(*peer, message.c_str(), info->Reason);
                    }
            });
}

void unregister_p2p_notifications() {
    if (g_p2p == nullptr)
        return;
    if (g_connection_request != eos::kInvalidNotificationId)
        g_api.p2p_remove_notify_peer_connection_request(g_p2p, g_connection_request);
    if (g_connection_established != eos::kInvalidNotificationId)
        g_api.p2p_remove_notify_peer_connection_established(g_p2p, g_connection_established);
    if (g_connection_closed != eos::kInvalidNotificationId)
        g_api.p2p_remove_notify_peer_connection_closed(g_p2p, g_connection_closed);
    g_connection_request = g_connection_established = g_connection_closed = eos::kInvalidNotificationId;
}

// Requires the bridge mutex.
void receive_packets() {
    eos::P2PReceivePacketOptions options{};
    options.ApiVersion = eos::P2PReceivePacketOptions::kApiVersion;
    options.LocalUserId = g_local_user;
    options.MaxDataSizeBytes = eos::kP2PMaxPacketSize;
    options.RequestedChannel = nullptr;
    for (int i = 0; i < kReceiveBatch; ++i) {
        eos::ProductUserId sender = nullptr;
        eos::P2PSocketId socket{};
        uint8_t channel = 0;
        uint32_t size = 0;
        const eos::Result result = g_api.p2p_receive_packet(g_p2p, &options, &sender, &socket, &channel,
                                                            g_receive_buffer.data(), &size);
        if (result != eos::kSuccess)
            return;
        if (std::strcmp(socket.SocketName, kSocketName) != 0)
            continue;
        const std::string remote = user_text(sender);
        BridgePeer *peer = g_bridge.client_peer();
        if (peer == nullptr || peer->remote != remote)
            peer = g_bridge.find_remote(remote, false);
        if (peer != nullptr)
            g_bridge.receive(*peer, g_receive_buffer.data(), size);
    }
}

// ---- Login -----------------------------------------------------------------------------------

void logged_in(eos::ProductUserId user) {
    g_local_user = user;
    const std::string id = user_text(user);
    register_p2p_notifications();
    eos::P2PSetRelayControlOptions relay{};
    relay.ApiVersion = eos::P2PSetRelayControlOptions::kApiVersion;
    relay.RelayControl = eos::kRelayAllowRelays;
    g_api.p2p_set_relay_control(g_p2p, &relay);
    eos::P2PQueryNATTypeOptions nat{};
    nat.ApiVersion = eos::P2PQueryNATTypeOptions::kApiVersion;
    g_api.p2p_query_nat_type(g_p2p, &nat, nullptr, [](const eos::P2PQueryNATTypeCompleteInfo *info) {
        if (info->ResultCode != eos::kSuccess)
            return;
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        g_snapshot.nat_type = info->NATType;
    });
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    const bool refreshed = g_snapshot.state == REALMS_EOS_STATE_READY;
    g_snapshot.state = REALMS_EOS_STATE_READY;
    g_snapshot.last_result = eos::kSuccess;
    g_snapshot.local_id = id;
    if (!refreshed)
        event(REALMS_EOS_EVENT_LOGIN_SUCCEEDED, id);
}

void login() {
    eos::ConnectCredentials credentials{};
    credentials.ApiVersion = eos::ConnectCredentials::kApiVersion;
    credentials.Token = nullptr;
    credentials.Type = eos::kExternalCredentialDeviceIdAccessToken;
    eos::ConnectUserLoginInfo info{};
    info.ApiVersion = eos::ConnectUserLoginInfo::kApiVersion;
    info.DisplayName = g_display_name.c_str();
    eos::ConnectLoginOptions options{};
    options.ApiVersion = eos::ConnectLoginOptions::kApiVersion;
    options.Credentials = &credentials;
    options.UserLoginInfo = &info;
    g_api.connect_login(g_connect, &options, nullptr, [](const eos::ConnectLoginCallbackInfo *result) {
        if (result->ResultCode == eos::kSuccess) {
            logged_in(result->LocalUserId);
            return;
        }
        if (result->ResultCode != eos::kInvalidUser) {
            sign_in_failed("EOS sign-in failed", result->ResultCode);
            return;
        }
        // First sign-in from this device: create the product user bound to the device credential.
        eos::ConnectCreateUserOptions create{};
        create.ApiVersion = eos::ConnectCreateUserOptions::kApiVersion;
        create.ContinuanceToken = result->ContinuanceToken;
        g_api.connect_create_user(g_connect, &create, nullptr, [](const eos::ConnectCreateUserCallbackInfo *created) {
            if (created->ResultCode == eos::kSuccess)
                logged_in(created->LocalUserId);
            else
                sign_in_failed("Could not create the EOS user", created->ResultCode);
        });
    });
}

void begin_login() {
    set_state(REALMS_EOS_STATE_LOGGING_IN);
    eos::ConnectCreateDeviceIdOptions options{};
    options.ApiVersion = eos::ConnectCreateDeviceIdOptions::kApiVersion;
    options.DeviceModel = "PC Windows";
    g_api.connect_create_device_id(g_connect, &options, nullptr,
                                   [](const eos::ConnectCreateDeviceIdCallbackInfo *info) {
                                       if (info->ResultCode == eos::kSuccess ||
                                           info->ResultCode == eos::kDuplicateNotAllowed)
                                           login();
                                       else
                                           sign_in_failed("Could not create the EOS device identity", info->ResultCode);
                                   });
}

// ---- Platform lifecycle ----------------------------------------------------------------------

std::wstring runtime_directory() {
    HMODULE module = nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            reinterpret_cast<LPCWSTR>(&runtime_directory), &module))
        return {};
    std::wstring path(MAX_PATH, L'\0');
    for (;;) {
        const DWORD size = GetModuleFileNameW(module, path.data(), static_cast<DWORD>(path.size()));
        if (size == 0)
            return {};
        if (size < path.size()) {
            path.resize(size);
            break;
        }
        path.resize(path.size() * 2);
    }
    const size_t slash = path.find_last_of(L"\\/");
    return slash == std::wstring::npos ? std::wstring() : path.substr(0, slash + 1);
}

std::string cache_directory() {
    PWSTR base = nullptr;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &base)))
        return {};
    std::wstring path = std::wstring(base) + L"\\DarktideRealms\\EOS";
    CoTaskMemFree(base);
    SHCreateDirectoryExW(nullptr, path.c_str(), nullptr);
    const int size = WideCharToMultiByte(CP_UTF8, 0, path.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string utf8(static_cast<size_t>(size > 0 ? size : 1), '\0');
    WideCharToMultiByte(CP_UTF8, 0, path.c_str(), -1, utf8.data(), size, nullptr, nullptr);
    utf8.resize(std::strlen(utf8.c_str()));
    return utf8;
}

bool configured() { return std::strlen(REALMS_EOS_PRODUCT_ID) != 0 && std::strlen(REALMS_EOS_CLIENT_ID) != 0; }

bool load_library(char *error, int capacity) {
    if (g_library != nullptr)
        return true;
    const std::wstring directory = runtime_directory();
    if (directory.empty())
        return write_error(error, capacity, "Could not locate the Realms runtime directory");
    HMODULE library = LoadLibraryExW((directory + kSdkLibrary).c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (library == nullptr)
        return write_formatted_error(error, capacity, "EOS SDK library could not be loaded: %lu", GetLastError());
    eos::Api api{};
#define REALMS_EOS_RESOLVE(member, symbol, signature)                                                                  \
    api.member = reinterpret_cast<eos::Api::member##_function>(GetProcAddress(library, #symbol));                     \
    if (api.member == nullptr) {                                                                                       \
        FreeLibrary(library);                                                                                          \
        std::snprintf(error, static_cast<size_t>(capacity), "EOS SDK export is missing: %s", #symbol);                \
        return false;                                                                                                  \
    }
    REALMS_EOS_FUNCTIONS(REALMS_EOS_RESOLVE)
#undef REALMS_EOS_RESOLVE
    g_api = api;
    g_library = library;
    return true;
}

void log_message(const eos::LogMessage *message) {
    if (message == nullptr || message->Level > eos::kLogLevelWarning)
        return;
    std::lock_guard<std::mutex> lock(g_log_mutex);
    if (g_log.size() >= kMaximumLogEvents)
        g_log.pop_front();
    BridgeEvent value{};
    value.type = static_cast<BridgeEventType>(REALMS_EOS_EVENT_LOG);
    value.code = message->Level;
    value.text = message->Category ? message->Category : "";
    value.message = message->Message ? message->Message : "";
    g_log.push_back(std::move(value));
}

bool start_platform() {
    if (!g_sdk_initialized) {
        eos::InitializeOptions options{};
        options.ApiVersion = eos::InitializeOptions::kApiVersion;
        options.ProductName = "Darktide Realms";
        options.ProductVersion = "1";
        const eos::Result result = g_api.initialize(&options);
        if (result != eos::kSuccess && result != eos::kAlreadyConfigured) {
            login_failed("EOS SDK initialization failed", result);
            return false;
        }
        g_sdk_initialized = true;
        g_api.logging_set_callback(log_message);
        g_api.logging_set_log_level(eos::kLogCategoryAll, eos::kLogLevelWarning);
    }
    const std::string cache = cache_directory();
    eos::PlatformOptions options{};
    options.ApiVersion = eos::PlatformOptions::kApiVersion;
    options.ProductId = REALMS_EOS_PRODUCT_ID;
    options.SandboxId = REALMS_EOS_SANDBOX_ID;
    options.DeploymentId = REALMS_EOS_DEPLOYMENT_ID;
    options.ClientCredentials.ClientId = REALMS_EOS_CLIENT_ID;
    options.ClientCredentials.ClientSecret = REALMS_EOS_CLIENT_SECRET;
    options.bIsServer = eos::kFalse;
    // The overlay would hook the game's renderer, and Realms never needs it.
    options.Flags = eos::kPlatformFlagDisableOverlay | eos::kPlatformFlagDisableSocialOverlay;
    options.CacheDirectory = cache.empty() ? nullptr : cache.c_str();
    g_platform = g_api.platform_create(&options);
    if (g_platform == nullptr) {
        login_failed("EOS platform could not be created", eos::kInvalidParameters);
        return false;
    }
    g_api.platform_set_application_status(g_platform, eos::kApplicationForeground);
    g_api.platform_set_network_status(g_platform, eos::kNetworkOnline);
    g_connect = g_api.platform_get_connect_interface(g_platform);
    g_p2p = g_api.platform_get_p2p_interface(g_platform);
    g_lobby = g_api.platform_get_lobby_interface(g_platform);
    eos::ConnectAddNotifyAuthExpirationOptions expiration{};
    expiration.ApiVersion = eos::ConnectAddNotifyAuthExpirationOptions::kApiVersion;
    g_auth_expiration = g_api.connect_add_notify_auth_expiration(
        g_connect, &expiration, nullptr, [](const eos::ConnectAuthExpirationCallbackInfo *) { login(); });
    begin_login();
    return true;
}

void stop_platform() {
    if (g_platform == nullptr)
        return;
    destroy_lobby();
    const uint64_t deadline = GetTickCount64() + kStopTimeoutMs;
    while (g_lobby_destroy_pending && GetTickCount64() < deadline) {
        g_api.platform_tick(g_platform);
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    if (g_local_user != nullptr && g_p2p != nullptr) {
        eos::P2PCloseConnectionsOptions close{};
        close.ApiVersion = eos::P2PCloseConnectionsOptions::kApiVersion;
        close.LocalUserId = g_local_user;
        close.SocketId = &g_socket;
        g_api.p2p_close_connections(g_p2p, &close);
    }
    unregister_p2p_notifications();
    if (g_auth_expiration != eos::kInvalidNotificationId)
        g_api.connect_remove_notify_auth_expiration(g_connect, g_auth_expiration);
    g_auth_expiration = eos::kInvalidNotificationId;
    g_api.platform_release(g_platform);
    g_platform = nullptr;
    g_connect = nullptr;
    g_p2p = nullptr;
    g_lobby = nullptr;
    g_local_user = nullptr;
    g_lobby_id.clear();
    g_lobby_pending = false;
    g_lobby_destroy_pending = false;
    g_sign_in_retry_at = 0;
}

void worker_main() {
    g_worker_thread.store(GetCurrentThreadId(), std::memory_order_release);
    start_platform();
    while (g_running.load(std::memory_order_acquire)) {
        std::vector<Command> commands;
        std::vector<std::string> closes;
        {
            std::lock_guard<std::mutex> lock(g_bridge.mutex());
            commands.swap(g_commands);
            closes.swap(g_pending_closes);
        }
        for (const std::string &remote : closes)
            close_connection(remote);
        for (const Command &command : commands)
            command();
        if (g_platform != nullptr && g_sign_in_retry_at != 0 && GetTickCount64() >= g_sign_in_retry_at) {
            g_sign_in_retry_at = 0;
            bool signed_in = false;
            {
                std::lock_guard<std::mutex> lock(g_bridge.mutex());
                signed_in = g_snapshot.state == REALMS_EOS_STATE_READY;
            }
            if (signed_in)
                login();
            else
                begin_login();
        }
        if (g_platform != nullptr)
            g_api.platform_tick(g_platform);
        std::unique_lock<std::mutex> lock(g_bridge.mutex());
        if (g_local_user != nullptr && g_p2p != nullptr)
            receive_packets();
        g_bridge.pump(nullptr);
        g_bridge.wake().wait_for(lock, g_bridge.has_peers() ? kActiveWait : kIdleWait, [] {
            return !g_running.load(std::memory_order_acquire) || !g_commands.empty();
        });
    }
    {
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        g_bridge.close_all("Realms EOS stopped");
        g_commands.clear();
        g_pending_closes.clear();
        g_links.clear();
    }
    stop_platform();
    if (g_exiting && g_sdk_initialized) {
        g_api.shutdown();
        g_sdk_initialized = false;
    }
    g_worker_thread.store(0, std::memory_order_release);
}

void queue(Command command) {
    g_commands.push_back(std::move(command));
    g_bridge.wake().notify_one();
}

} // namespace
} // namespace realms

using namespace realms;

int RealmsRuntime_EosAvailable(char *error, int error_capacity) {
    if (!configured()) {
        write_error(error, error_capacity, "This build has no EOS configuration");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    return load_library(error, error_capacity) ? 1 : 0;
}

int RealmsRuntime_EosStart(const char *display_name, char *error, int error_capacity) {
    if (!configured()) {
        write_error(error, error_capacity, "This build has no EOS configuration");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (g_running.load(std::memory_order_acquire))
        return 1;
    if (g_exiting) {
        write_error(error, error_capacity, "EOS has already been shut down");
        return 0;
    }
    if (!load_library(error, error_capacity))
        return 0;
    if (!g_winsock) {
        WSADATA data{};
        const int result = WSAStartup(MAKEWORD(2, 2), &data);
        if (result != 0) {
            write_formatted_error(error, error_capacity, "EOS bridge WSAStartup failed: %lu", result);
            return 0;
        }
        g_winsock = true;
    }
    std::string name = truncate_utf8(display_name ? display_name : "", kDisplayNameLimit);
    g_display_name = name.empty() ? "Realms" : name;
    g_snapshot = {};
    g_snapshot.state = REALMS_EOS_STATE_STARTING;
    g_bridge.clear_events();
    std::snprintf(g_socket.SocketName, sizeof(g_socket.SocketName), "%s", kSocketName);
    g_socket.ApiVersion = eos::P2PSocketId::kApiVersion;
    g_running.store(true, std::memory_order_release);
    try {
        g_worker = std::thread(worker_main);
    } catch (const std::system_error &) {
        g_running.store(false, std::memory_order_release);
        g_snapshot.state = REALMS_EOS_STATE_STOPPED;
        write_error(error, error_capacity, "Could not start the EOS thread");
        return 0;
    }
    return 1;
}

void RealmsRuntime_EosStop(int exiting) {
    {
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        g_exiting = g_exiting || exiting != 0;
        if (!g_running.load(std::memory_order_acquire) && !g_worker.joinable())
            return;
        g_running.store(false, std::memory_order_release);
        g_bridge.wake().notify_all();
    }
    if (g_worker.joinable())
        g_worker.join();
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_snapshot = {};
    g_accepting = false;
    g_bridge.clear_events();
    if (g_winsock)
        WSACleanup();
    g_winsock = false;
}

int RealmsRuntime_EosStartHost(int password_required, char *error, int error_capacity) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (g_snapshot.state != REALMS_EOS_STATE_READY || !g_local_session_active.load(std::memory_order_acquire)) {
        write_error(error, error_capacity, "A Realms host and EOS sign-in must be active first");
        return 0;
    }
    if (g_accepting)
        return 1;
    if (!g_bridge.start_host(password_required != 0, error, error_capacity))
        return 0;
    g_accepting = true;
    ++g_lobby_generation;
    queue(create_lobby);
    return 1;
}

void RealmsRuntime_EosStopHost() {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_bridge.stop_host("Realms host closed");
    g_accepting = false;
}

void RealmsRuntime_EosSetInvitesOpen(int open) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (open != 0) {
        if (g_accepting || !g_bridge.hosting() || g_snapshot.state != REALMS_EOS_STATE_READY)
            return;
        g_accepting = true;
        ++g_lobby_generation;
        queue(create_lobby);
        return;
    }
    if (!g_accepting)
        return;
    // Only new players are turned away. Peers that already joined keep their connections.
    g_accepting = false;
    queue(destroy_lobby);
}

void RealmsRuntime_EosSetPasswordRequired(int required) {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_bridge.set_password_required(required != 0);
}

int RealmsRuntime_EosResolveCode(const char *code, char *error, int error_capacity) {
    if (!valid_code(code)) {
        write_error(error, error_capacity, "EOS invite code is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (g_snapshot.state != REALMS_EOS_STATE_READY) {
        write_error(error, error_capacity, "EOS is not signed in");
        return 0;
    }
    queue([value = std::string(code)] { resolve_code(value); });
    return 1;
}

int RealmsRuntime_EosConnect(const char *remote_id, const char *game_peer_id, int password_supplied, char *error,
                             int error_capacity) {
    uint64_t game_peer = 0;
    if (!valid_user_text(remote_id)) {
        write_error(error, error_capacity, "EOS target identity is invalid");
        return 0;
    }
    if (!parse_hex_id(game_peer_id, &game_peer, "EOS bridge engine peer", error, error_capacity))
        return 0;
    if (game_peer == 0) {
        write_error(error, error_capacity, "EOS bridge engine peer identity is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    if (g_snapshot.state != REALMS_EOS_STATE_READY) {
        write_error(error, error_capacity, "EOS is not signed in");
        return 0;
    }
    const std::string remote = remote_id;
    if (remote == g_snapshot.local_id) {
        write_error(error, error_capacity, "Cannot connect to the local EOS user");
        return 0;
    }
    if (g_bridge.client_peer() != nullptr) {
        write_error(error, error_capacity, "An EOS client connection is already active");
        return 0;
    }
    g_bridge.clear_client_events();
    g_snapshot.client_network_type = -1;
    BridgePeer *peer = g_bridge.add_outgoing(link_for(remote), remote, game_peer, password_supplied != 0);
    // Reliable control messages queue until EOS opens the connection, so the peer counts as connected.
    g_bridge.connected(*peer);
    queue([remote] {
        if (g_p2p == nullptr || g_local_user == nullptr)
            return;
        const eos::P2PConnectionOptions options = connection_options(remote);
        g_api.p2p_accept_connection(g_p2p, &options);
    });
    return 1;
}

void RealmsRuntime_EosDisconnect() {
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    g_bridge.disconnect_client("Realms client closed");
}

int RealmsRuntime_EosPollEvent(RealmsEosEvent *output, char *error, int error_capacity) {
    if (!output || output->struct_size != sizeof(*output)) {
        write_error(error, error_capacity, "EOS event structure size is invalid");
        return -1;
    }
    BridgeEvent event{};
    int result = 0;
    {
        std::lock_guard<std::mutex> lock(g_bridge.mutex());
        result = g_bridge.poll_event(&event);
    }
    if (result < 0) {
        write_error(error, error_capacity, "EOS event queue overflowed");
        return -1;
    }
    if (result == 0 && !pop_log(&event))
        return 0;
    *output = {};
    output->struct_size = sizeof(*output);
    output->type = static_cast<uint32_t>(event.type);
    output->code = event.code;
    output->local_port = event.port;
    std::snprintf(output->remote, sizeof(output->remote), "%s", event.remote.c_str());
    std::snprintf(output->text, sizeof(output->text), "%s", event.text.c_str());
    std::snprintf(output->message, sizeof(output->message), "%s", event.message.c_str());
    return 1;
}

int RealmsRuntime_EosStatus(RealmsEosStatus *output, char *error, int error_capacity) {
    if (!output || output->struct_size != sizeof(*output)) {
        write_error(error, error_capacity, "EOS status structure size is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(g_bridge.mutex());
    const BridgeStats &stats = g_bridge.stats();
    *output = {};
    output->struct_size = sizeof(*output);
    output->state = g_snapshot.state;
    output->last_result = g_snapshot.last_result;
    output->nat_type = g_snapshot.nat_type;
    output->hosting = g_accepting ? 1 : 0;
    output->connections = g_bridge.connection_count();
    output->client_port = g_bridge.client_port();
    output->client_network_type = g_snapshot.client_network_type;
    output->sent_bytes = stats.sent_bytes;
    output->received_bytes = stats.received_bytes;
    output->dropped_datagrams = stats.dropped_datagrams;
    output->fragmented_datagrams = stats.fragmented_datagrams;
    return 1;
}
