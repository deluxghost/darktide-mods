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

// All functions except native callbacks must be called from the game thread.
// Command functions return 1 on success and 0 on failure.
REALMS_RUNTIME_API int RealmsRuntime_Initialize(char *error, int error_capacity);

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

// Releases only the Realms listeners associated with this peer.
// Higher layers remain responsible for closing channels and removing lobby/session members.
REALMS_RUNTIME_API int RealmsRuntime_ReleasePeerTransportState(const char *peer_id, char *error, int error_capacity);

// Marks a handshake peer slot as owned by the higher-level RemoteConnection lifecycle.
REALMS_RUNTIME_API int RealmsRuntime_AdoptPeerTransportState(const char *peer_id, char *error, int error_capacity);

// Releases handshake peer slots that were never adopted by a RemoteConnection.
REALMS_RUNTIME_API int RealmsRuntime_ReapAbandonedPeerTransportState(uint32_t idle_timeout_ms, int *reaped_count,
                                                                    char *error, int error_capacity);

// Returns 1 when an event was written, 0 when the queue is empty, and -1 on API failure.
// The caller must initialize event->struct_size to sizeof(RealmsRuntimeEvent).
REALMS_RUNTIME_API int RealmsRuntime_PollEvent(RealmsRuntimeEvent *event, char *error, int error_capacity);

// Must run before Darktide destroys the Connection and local-session lobby objects.
REALMS_RUNTIME_API int RealmsRuntime_CloseLocalSession(char *error, int error_capacity);

#ifdef __cplusplus
}
#endif

#endif
