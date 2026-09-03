#pragma once

#include <winsock2.h>
#include <windows.h>

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <mutex>

#include "darktide_realms.h"
#include "dtintutils.h"

namespace realms {

inline constexpr size_t kTransportOffset = 0x60;
inline constexpr size_t kConnectionOffset = 0x68;
inline constexpr size_t kNetworkManagerLanClientOffset = 0x88;
inline constexpr size_t kTransportSocketOffset = 0x68;
inline constexpr size_t kIsPeerConnectedSlot = 0x70;
inline constexpr size_t kSendAddressSlot = 0x30;
inline constexpr size_t kRegisterSystemListenerSlot = 0x38;
inline constexpr size_t kRegisterChannelSystemListenerSlot = 0x50;
inline constexpr size_t kRegisterPeerSystemListenerSlot = 0x58;
inline constexpr size_t kRemoveListenerSlot = 0x68;
inline constexpr size_t kAcceptChannelSlot = 0x88;
inline constexpr size_t kSendChannelSlot = 0x118;
inline constexpr size_t kLocalPeerIdOffset = 0x428;
inline constexpr size_t kConnectionWanTransportOffset = 0x58;
inline constexpr size_t kPeerRouteCountOffset = 0x80;
inline constexpr size_t kPeerRouteCapacityOffset = 0x84;
inline constexpr size_t kPeerRouteEntriesOffset = 0x88;
inline constexpr size_t kPeerRouteEntrySize = 0x30;
inline constexpr size_t kPeerRouteAddressOffset = 0x08;
inline constexpr size_t kListenerTableSelectorOffset = 0x3f0;
inline constexpr uint32_t kLobbyConnectRequestSystem = 0;
inline constexpr uint32_t kLobbySystem = 1;
inline constexpr uint32_t kConnectRequestMessage = 16;
inline constexpr uint32_t kConnectReplyMessage = 17;
inline constexpr uint32_t kCreateChannelMessage = 0;
inline constexpr uint32_t kRequestJoinMessage = 22;
inline constexpr uint32_t kJoinReplyMessage = 23;
inline constexpr uint32_t kLobbyChannelType = 1;
inline constexpr uint32_t kWireProtocol = 0x3ee5;
inline constexpr size_t kWireAddressSize = 0x25;
inline constexpr size_t kMaximumWirePacketSize = 0x45;
inline constexpr size_t kMaximumApproveMessageSize = 16;
inline constexpr uint32_t kMaximumHostMembers = 8;
inline constexpr uint32_t kMaximumRemotePeers = kMaximumHostMembers - 1;
inline constexpr size_t kLanClientLobbyCountOffset = 0x80;
inline constexpr size_t kLanClientLobbyCapacityOffset = 0x84;
inline constexpr size_t kLanClientLobbyEntriesOffset = 0x88;
inline constexpr size_t kLanLobbySize = 0x668;
inline constexpr size_t kLanLobbyOwnerOffset = 0x50;
inline constexpr size_t kLanLobbyIdOffset = 0x58;
inline constexpr size_t kLanLobbyLocalPeerOffset = 0x60;
inline constexpr size_t kLanLobbyConnectionOffset = 0x68;
inline constexpr size_t kLanLobbyTransportOffset = 0x70;
inline constexpr size_t kLanLobbyMaxMembersOffset = 0x78;
inline constexpr size_t kLanLobbyStateOffset = 0x7c;
inline constexpr size_t kLanLobbyHostOffset = 0x80;
inline constexpr size_t kLanLobbyGuestChannelOffset = 0x88;
inline constexpr size_t kLanLobbyMemberCountOffset = 0x5a8;
inline constexpr size_t kLanLobbyMemberCapacityOffset = 0x5ac;
inline constexpr size_t kLanLobbyMembersOffset = 0x5b0;
inline constexpr size_t kLanLobbySystemListenerTokenOffset = 0x5dc;
inline constexpr size_t kLanLobbyMemberSize = 0x60;
inline constexpr size_t kLanLobbyMemberChannelOffset = 0x08;
inline constexpr size_t kLanLobbyMemberAllocatorOffset = 0x40;
inline constexpr size_t kLanLobbyMemberAllocatorMirrorOffset = 0x58;

struct HostPeerSlot {
    std::atomic<uint64_t> peer_id{0};
    std::atomic<uint64_t> last_activity_tick{0};
    std::atomic<uint32_t> peer_listener_token{0};
    std::atomic<uint32_t> channel_listener_token{0};
    std::atomic<uint32_t> channel_id{0};
    std::atomic<bool> adopted{false};
    std::atomic<bool> peer_listener_registered{false};
    std::atomic<bool> channel_listener_registered{false};
};

using IsPeerConnectedFunction = uint64_t(__fastcall *)(void *, uint64_t);
using SystemListenerCallback = uint64_t(__fastcall *)(void *, uint64_t, uint64_t, uint64_t, uint64_t, int32_t, void *);
using RoutedSystemListenerCallback = uint64_t(__fastcall *)(void *, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t,
                                                            int32_t, void *);
using RegisterSystemListenerFunction = uint32_t *(__fastcall *)(void *, uint32_t *, uint32_t, SystemListenerCallback,
                                                                void *);
using RegisterPeerSystemListenerFunction = uint32_t *(__fastcall *)(void *, uint32_t *, uint32_t, uint64_t,
                                                                    RoutedSystemListenerCallback, void *);
using RegisterChannelSystemListenerFunction = uint32_t *(__fastcall *)(void *, uint32_t *, uint32_t, uint32_t,
                                                                       RoutedSystemListenerCallback, void *);
using RemoveListenerFunction = void(__fastcall *)(void *, uint32_t);
using ReadBitsFunction = int32_t(__fastcall *)(int32_t *, uint32_t);
using SendAddressFunction = int32_t(__fastcall *)(void *, const sockaddr *, const void *, int32_t);
using AcceptChannelFunction = uint32_t *(__fastcall *)(void *, uint32_t *, uint32_t, uint64_t, uint32_t, uint64_t,
                                                       const void *, uint32_t);
using SendChannelFunction = uint64_t(__fastcall *)(void *, uint32_t, uint32_t, uint8_t, const void *, uint32_t,
                                                   uint32_t *);
using AddLobbyMemberFunction = uint64_t(__fastcall *)(void *, void *, uint16_t);
using DestroyLobbyMemberFunction = void(__fastcall *)(void *);

enum class EngineFunctionRole {
    RegisterSystemListener,
    RemoveListener,
    IsPeerConnected,
    AcceptChannel,
    SendChannel,
};

extern DtIntUtilsModule g_module;
extern const uint8_t *g_network_manager_slot;
extern bool g_initialized;
extern std::atomic<void *> g_host_listener_connection;
extern std::atomic<uint32_t> g_host_listener_token;
extern std::atomic<bool> g_host_listener_registered;
extern char g_local_account_id[kWireAddressSize];
extern std::atomic<void *> g_host_lobby;
extern std::atomic<uint64_t> g_host_lobby_id;
extern std::atomic<bool> g_local_session_active;
extern HostPeerSlot g_host_peer_slots[kMaximumRemotePeers];
extern std::mutex g_host_peer_slots_mutex;
extern void *g_expected_connection;
extern void *g_expected_connection_vtable;
extern RegisterPeerSystemListenerFunction g_register_peer_system_listener;
extern RegisterChannelSystemListenerFunction g_register_channel_system_listener;
extern RemoveListenerFunction g_remove_listener;
extern ReadBitsFunction g_read_bits;
extern SendAddressFunction g_send_address;
extern AcceptChannelFunction g_accept_channel;
extern SendChannelFunction g_send_channel;
extern AddLobbyMemberFunction g_add_lobby_member;
extern DestroyLobbyMemberFunction g_destroy_lobby_member;

HostPeerSlot *find_host_peer_slot(uint64_t peer_id);
void clear_host_peer_slot(HostPeerSlot &slot);
bool add_lobby_member(void *lobby, uint64_t peer_id, uint16_t port, uint32_t channel_id);
uint64_t __fastcall host_listener_callback(void *connection, uint64_t, uint64_t peer_id, uint64_t, uint64_t,
                                           int32_t message_id, void *);

void clear_runtime_events();
void push_runtime_event(RealmsRuntimeEventType type, RealmsRuntimeEventCode code, uint64_t peer_id, uint32_t channel_id,
                        const char *message);
int poll_runtime_event(RealmsRuntimeEvent *event, char *error, int error_capacity);

bool write_error(char *buffer, int capacity, const char *message);
bool write_formatted_error(char *buffer, int capacity, const char *format, unsigned long value);
bool decode_absolute_target(const uint8_t *address, DtIntUtilsMnemonic mnemonic, const uint8_t **target, char *error,
                            int error_capacity);
bool validate_engine_function(const void *target, EngineFunctionRole role, const char *description, char *error,
                              int error_capacity);
bool validate_routed_listener_methods(const void *register_channel, const void *register_peer, char *error,
                                      int error_capacity);
bool validate_send_address_method(const void *target, char *error, int error_capacity);
bool locate_lobby_member_helpers(AddLobbyMemberFunction *add_member, DestroyLobbyMemberFunction *destroy_member,
                                 char *error, int error_capacity);
bool locate_read_bits(ReadBitsFunction *read_bits, char *error, int error_capacity);
bool set_client_ipv6_member_address_support(bool enabled, char *error, int error_capacity);
bool ensure_initialized(char *error, int error_capacity);
bool read_pointer(const uint8_t *location, void **value, const char *description, char *error, int error_capacity);
bool current_network_manager(void **manager, char *error, int error_capacity);
bool current_connection(void **connection, IsPeerConnectedFunction *is_peer_connected,
                        RegisterSystemListenerFunction *register_system_listener,
                        RemoveListenerFunction *remove_listener, char *error, int error_capacity);
bool parse_hex_id(const char *text, uint64_t *value, const char *description, char *error, int error_capacity);

} // namespace realms
