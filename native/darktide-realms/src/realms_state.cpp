#include "realms_internal.h"

namespace realms {

DtIntUtilsModule g_module{};
const uint8_t *g_network_manager_slot = nullptr;
bool g_initialized = false;
std::atomic<void *> g_host_listener_connection{nullptr};
std::atomic<uint32_t> g_host_listener_token{0};
std::atomic<bool> g_host_listener_registered{false};
char g_local_account_id[kWireAddressSize]{};
std::atomic<void *> g_host_lobby{nullptr};
std::atomic<uint64_t> g_host_lobby_id{0};
std::atomic<bool> g_local_session_active{false};
HostPeerSlot g_host_peer_slots[kMaximumRemotePeers]{};
std::mutex g_host_peer_slots_mutex;
void *g_expected_connection = nullptr;
void *g_expected_connection_vtable = nullptr;
RegisterPeerSystemListenerFunction g_register_peer_system_listener = nullptr;
RegisterChannelSystemListenerFunction g_register_channel_system_listener = nullptr;
RemoveListenerFunction g_remove_listener = nullptr;
ReadBitsFunction g_read_bits = nullptr;
SendAddressFunction g_send_address = nullptr;
AcceptChannelFunction g_accept_channel = nullptr;
SendChannelFunction g_send_channel = nullptr;
AddLobbyMemberFunction g_add_lobby_member = nullptr;
DestroyLobbyMemberFunction g_destroy_lobby_member = nullptr;

} // namespace realms
