#ifndef DARKTIDE_REALMS_H
#define DARKTIDE_REALMS_H

#include <stdint.h>

#if defined(DARKTIDE_REALMS_BUILD)
#define REALMS_RUNTIME_API __declspec(dllexport)
#else
#define REALMS_RUNTIME_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define REALMS_RUNTIME_EVENT_MESSAGE_CAPACITY 160
#define REALMS_RUNTIME_PEER_ID_CAPACITY 17
#define REALMS_RUNTIME_ADDRESS_CAPACITY 46
#define REALMS_RUNTIME_MAX_RESOLVED_ADDRESSES 8

typedef enum RealmsRuntimeEventType {
    REALMS_RUNTIME_EVENT_ERROR = 1,
    REALMS_RUNTIME_EVENT_PEER_DISCOVERED = 2,
    REALMS_RUNTIME_EVENT_PEER_JOINED = 3,
    REALMS_RUNTIME_EVENT_PEER_REJECTED = 4
} RealmsRuntimeEventType;

typedef enum RealmsRuntimeEventCode {
    REALMS_RUNTIME_EVENT_CODE_NONE = 0,
    REALMS_RUNTIME_ERROR_INVALID_CALLBACK_STATE = 1001,
    REALMS_RUNTIME_ERROR_PACKET_DECODE = 1002,
    REALMS_RUNTIME_ERROR_MEMBER_ADD = 1003,
    REALMS_RUNTIME_ERROR_CHANNEL_ACCEPT = 1004,
    REALMS_RUNTIME_ERROR_LISTENER_REGISTRATION = 1005,
    REALMS_RUNTIME_ERROR_SEND = 1006,
    REALMS_RUNTIME_ERROR_PEER_CAPACITY = 1007,
    REALMS_RUNTIME_ERROR_EVENT_OVERFLOW = 1008,
    REALMS_RUNTIME_ERROR_RELAY = 1009,
    REALMS_RUNTIME_ERROR_RELAY_FATAL = 1010,
    REALMS_RUNTIME_REJECT_CAPACITY = 2002,
    REALMS_RUNTIME_REJECT_LOBBY = 2003
} RealmsRuntimeEventCode;

typedef enum RealmsRuntimeStartError {
    REALMS_RUNTIME_START_ERROR_NONE = 0,
    REALMS_RUNTIME_START_ERROR_LISTEN_PORT_UNAVAILABLE = 1
} RealmsRuntimeStartError;

typedef struct RealmsRuntimeEvent {
    uint32_t struct_size;
    uint32_t type;
    char peer_id[REALMS_RUNTIME_PEER_ID_CAPACITY];
    uint32_t channel_id;
    int32_t code;
    char message[REALMS_RUNTIME_EVENT_MESSAGE_CAPACITY];
} RealmsRuntimeEvent;

typedef struct RealmsResolvedAddresses {
    uint32_t struct_size;
    uint32_t count;
    char addresses[REALMS_RUNTIME_MAX_RESOLVED_ADDRESSES][REALMS_RUNTIME_ADDRESS_CAPACITY];
} RealmsResolvedAddresses;

typedef struct RealmsBinaryMessage {
    uint32_t struct_size;
    uint32_t channel_id;
    uint32_t message_type;
    uint32_t message_id;
    uint32_t reliable;
    uint32_t payload_size;
    char sender_peer_id[REALMS_RUNTIME_PEER_ID_CAPACITY];
    char recipient_peer_id[REALMS_RUNTIME_PEER_ID_CAPACITY];
} RealmsBinaryMessage;

typedef struct RealmsBinaryStats {
    uint32_t struct_size;
    uint32_t queued_messages;
    uint64_t queued_bytes;
    uint64_t sent_messages;
    uint64_t received_messages;
    uint64_t expired_messages;
} RealmsBinaryStats;

// All functions except native callbacks must be called from the game thread.
// Command functions return 1 on success and 0 on failure.
REALMS_RUNTIME_API int RealmsRuntime_Initialize(char *error, int error_capacity);

// Returns the native host capacity, including the host. Does not initialize or patch the engine.
REALMS_RUNTIME_API uint32_t RealmsRuntime_MaximumHostMembers(void);

// Resolves a host name or numeric address through the Windows system resolver.
// Writes unique numeric IPv4 and IPv6 candidates in Windows resolver order.
REALMS_RUNTIME_API int RealmsRuntime_ResolveAddresses(const char *address, RealmsResolvedAddresses *resolved,
                                                      char *error, int error_capacity);

// Extends Darktide's LAN lobby member-list validation for a Realms client session.
// The installed call-site patch is behavior-neutral while disabled.
REALMS_RUNTIME_API int RealmsRuntime_SetClientIpv6MemberAddressSupport(int enabled, char *error,
                                                                       int error_capacity);

// Starts native listening for the one officially constructed local-session lobby.
// requested_listen_port is 0 to expose Darktide's existing random port directly.
// A non-zero value starts the fixed-port relay and returns that public UDP port.
REALMS_RUNTIME_API int RealmsRuntime_StartLocalSession(const char *local_account_id, const char *local_peer_id,
                                                       int requested_listen_port, int *listen_udp_port,
                                                       int *start_error_code, char *error, int error_capacity);

REALMS_RUNTIME_API int RealmsRuntime_IsPeerConnected(const char *peer_id, int *connected, char *error,
                                                     int error_capacity);

// Ends RemoteConnection ownership without interrupting the reusable engine connection.
// Higher layers remain responsible for closing channels and removing lobby/session members.
REALMS_RUNTIME_API int RealmsRuntime_ReleasePeerTransportState(const char *peer_id, char *error, int error_capacity);

// Marks a handshake peer slot as owned by the higher-level RemoteConnection lifecycle.
REALMS_RUNTIME_API int RealmsRuntime_AdoptPeerTransportState(const char *peer_id, char *error, int error_capacity);

// Reaps released peers once disconnected, and unadopted peers after disconnection and the idle timeout.
REALMS_RUNTIME_API int RealmsRuntime_ReapAbandonedPeerTransportState(uint32_t idle_timeout_ms, int *reaped_count,
                                                                    char *error, int error_capacity);

// Returns 1 when an event was written, 0 when the queue is empty, and -1 on API failure.
// The caller must initialize event->struct_size to sizeof(RealmsRuntimeEvent).
// Non-null output buffers are inspected only when an event is available; API failure does not consume the event.
REALMS_RUNTIME_API int RealmsRuntime_PollEvent(RealmsRuntimeEvent *event, char *error, int error_capacity);

// Private Realms transport. Attach only channels admitted by the Realms session handshake.
REALMS_RUNTIME_API int RealmsRuntime_AttachBinaryChannel(uint32_t channel_id, const char *peer_id, int is_host,
                                                        char *error, int error_capacity);
REALMS_RUNTIME_API int RealmsRuntime_DetachBinaryChannel(uint32_t channel_id, char *error, int error_capacity);

// Copies payload before returning. Success means accepted locally, not acknowledged by the recipient.
// Type 0 is reserved for reliable JSON control. Recipient 0 means host; UINT64_MAX means others.
// Control enters the engine reliable queue synchronously; other types use the rate-limited local queue.
// lifetime_ms applies only to the local unreliable send queue; reliable messages use 0.
REALMS_RUNTIME_API int RealmsRuntime_SendBinary(uint32_t channel_id, const char *sender_peer_id,
                                               const char *recipient_peer_id, uint32_t message_type, int reliable,
                                               const void *payload, uint32_t payload_size, uint32_t lifetime_ms,
                                               uint32_t *message_id, char *error, int error_capacity);

// Advances all attached channels. On failure, identifies the channel that must be closed.
REALMS_RUNTIME_API int RealmsRuntime_UpdateBinary(uint32_t *failed_channel, char *error, int error_capacity);

// Returns 1 for a message, 0 when empty, -1 on failure, -2 for an undersized buffer, without consuming it;
// message->payload_size reports the required size. The caller owns the output buffer.
// Pass 0/0 for ordinary data; control requires the channel and ID from its ordered Lua RPC wakeup.
REALMS_RUNTIME_API int RealmsRuntime_PollBinary(uint32_t control_channel, uint32_t message_id, RealmsBinaryMessage *message, void *payload, uint32_t capacity,
                                               char *error, int error_capacity);
REALMS_RUNTIME_API int RealmsRuntime_BinaryStats(uint32_t channel_id, RealmsBinaryStats *stats,
                                                char *error, int error_capacity);

// Must run before Darktide destroys the Connection and local-session lobby objects.
REALMS_RUNTIME_API int RealmsRuntime_CloseLocalSession(char *error, int error_capacity);

#ifdef __cplusplus
}
#endif

#endif
