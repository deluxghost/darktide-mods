#pragma once

// Minimal declarations of the EOS C SDK surface used by Realms.
// The SDK DLL is loaded at runtime, so neither headers nor import libraries are needed to build.
// Each Options struct is pinned to the ApiVersion it was written against. Newer SDK DLLs accept
// older ApiVersions, so these declarations stay valid across SDK upgrades.
// eos_layout_check.cpp verifies every declaration against official headers when EosSdkRoot is set.

#include <cstdint>

namespace realms::eos {

using Bool = int32_t;
using Result = int32_t;
using NotificationId = uint64_t;
using LobbyId = const char *;

struct PlatformHandle;
struct ConnectHandle;
struct P2PHandle;
struct LobbyHandle;
struct LobbyModificationHandle;
struct LobbySearchHandle;
struct LobbyDetailsHandle;
struct ProductUserIdDetails;
struct ContinuanceTokenDetails;

using HPlatform = PlatformHandle *;
using HConnect = ConnectHandle *;
using HP2P = P2PHandle *;
using HLobby = LobbyHandle *;
using HLobbyModification = LobbyModificationHandle *;
using HLobbySearch = LobbySearchHandle *;
using HLobbyDetails = LobbyDetailsHandle *;
using ProductUserId = ProductUserIdDetails *;
using ContinuanceToken = ContinuanceTokenDetails *;

inline constexpr Bool kTrue = 1;
inline constexpr Bool kFalse = 0;
inline constexpr NotificationId kInvalidNotificationId = 0;
inline constexpr uint32_t kProductUserIdMaxLength = 32;
inline constexpr uint32_t kP2PMaxPacketSize = 1170;
inline constexpr const char *kLobbySearchBucketId = "bucket";

enum : Result {
    kSuccess = 0,
    kNoConnection = 1,
    kInvalidUser = 3,
    kInvalidAuth = 4,
    kAccessDenied = 5,
    kTooManyRequests = 8,
    kInvalidParameters = 10,
    kNotConfigured = 14,
    kAlreadyConfigured = 15,
    kCanceled = 17,
    kNotFound = 18,
    kOperationWillRetry = 19,
    kLimitExceeded = 22,
    kDuplicateNotAllowed = 24,
};

inline constexpr uint64_t kPlatformFlagDisableOverlay = 2;
inline constexpr uint64_t kPlatformFlagDisableSocialOverlay = 4;

inline constexpr int32_t kExternalCredentialDeviceIdAccessToken = 10;
inline constexpr int32_t kPacketUnreliableUnordered = 0;
inline constexpr int32_t kPacketReliableOrdered = 2;
inline constexpr int32_t kRelayAllowRelays = 1;
inline constexpr int32_t kLobbyPermissionPublicAdvertised = 0;
inline constexpr int32_t kAttributeString = 3;
inline constexpr int32_t kLobbyAttributePublic = 0;
inline constexpr int32_t kComparisonEqual = 0;
inline constexpr int32_t kApplicationForeground = 3;
inline constexpr int32_t kNetworkOnline = 2;
inline constexpr int32_t kLogCategoryAll = 0x7fffffff;
inline constexpr int32_t kLogLevelWarning = 300;

// ---- Platform --------------------------------------------------------------------------------

struct InitializeOptions {
    static constexpr int32_t kApiVersion = 5;
    int32_t ApiVersion;
    void *AllocateMemoryFunction;
    void *ReallocateMemoryFunction;
    void *ReleaseMemoryFunction;
    const char *ProductName;
    const char *ProductVersion;
    void *Reserved;
    void *SystemInitializeOptions;
    void *OverrideThreadAffinity;
};

struct PlatformClientCredentials {
    const char *ClientId;
    const char *ClientSecret;
};

struct PlatformOptions {
    static constexpr int32_t kApiVersion = 15;
    int32_t ApiVersion;
    void *Reserved;
    const char *ProductId;
    const char *SandboxId;
    PlatformClientCredentials ClientCredentials;
    Bool bIsServer;
    const char *EncryptionKey;
    const char *OverrideCountryCode;
    const char *OverrideLocaleCode;
    const char *DeploymentId;
    uint64_t Flags;
    const char *CacheDirectory;
    uint32_t TickBudgetInMilliseconds;
    const void *RTCOptions;
    void *IntegratedPlatformOptionsContainerHandle;
    const void *SystemSpecificOptions;
    double *TaskNetworkTimeoutSeconds;
};

struct LogMessage {
    const char *Category;
    const char *Message;
    int32_t Level;
};

// ---- Connect ---------------------------------------------------------------------------------

struct ConnectCredentials {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    const char *Token;
    int32_t Type;
};

struct ConnectUserLoginInfo {
    static constexpr int32_t kApiVersion = 2;
    int32_t ApiVersion;
    const char *DisplayName;
    const char *NsaIdToken;
};

struct ConnectLoginOptions {
    static constexpr int32_t kApiVersion = 2;
    int32_t ApiVersion;
    const ConnectCredentials *Credentials;
    const ConnectUserLoginInfo *UserLoginInfo;
};

struct ConnectLoginCallbackInfo {
    Result ResultCode;
    void *ClientData;
    ProductUserId LocalUserId;
    ContinuanceToken ContinuanceToken;
};

struct ConnectCreateUserOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    ContinuanceToken ContinuanceToken;
};

struct ConnectCreateUserCallbackInfo {
    Result ResultCode;
    void *ClientData;
    ProductUserId LocalUserId;
};

struct ConnectCreateDeviceIdOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    const char *DeviceModel;
};

struct ConnectCreateDeviceIdCallbackInfo {
    Result ResultCode;
    void *ClientData;
};

struct ConnectAddNotifyAuthExpirationOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
};

struct ConnectAuthExpirationCallbackInfo {
    void *ClientData;
    ProductUserId LocalUserId;
};

// ---- P2P -------------------------------------------------------------------------------------

struct P2PSocketId {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    char SocketName[33];
};

struct P2PSendPacketOptions {
    static constexpr int32_t kApiVersion = 3;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
    ProductUserId RemoteUserId;
    const P2PSocketId *SocketId;
    uint8_t Channel;
    uint32_t DataLengthBytes;
    const void *Data;
    Bool bAllowDelayedDelivery;
    int32_t Reliability;
    Bool bDisableAutoAcceptConnection;
};

struct P2PReceivePacketOptions {
    static constexpr int32_t kApiVersion = 2;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
    uint32_t MaxDataSizeBytes;
    const uint8_t *RequestedChannel;
};

struct P2PAddNotifyOptions {
    // Shared by PeerConnectionRequest, PeerConnectionEstablished and PeerConnectionClosed (all version 1).
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
    const P2PSocketId *SocketId;
};

struct P2PIncomingConnectionRequestInfo {
    void *ClientData;
    ProductUserId LocalUserId;
    ProductUserId RemoteUserId;
    const P2PSocketId *SocketId;
};

struct P2PPeerConnectionEstablishedInfo {
    void *ClientData;
    ProductUserId LocalUserId;
    ProductUserId RemoteUserId;
    const P2PSocketId *SocketId;
    int32_t ConnectionType;
    int32_t NetworkType;
};

struct P2PRemoteConnectionClosedInfo {
    void *ClientData;
    ProductUserId LocalUserId;
    ProductUserId RemoteUserId;
    const P2PSocketId *SocketId;
    int32_t Reason;
};

struct P2PConnectionOptions {
    // Shared by AcceptConnection and CloseConnection (both version 1).
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
    ProductUserId RemoteUserId;
    const P2PSocketId *SocketId;
};

struct P2PCloseConnectionsOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
    const P2PSocketId *SocketId;
};

struct P2PSetRelayControlOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    int32_t RelayControl;
};

struct P2PSetPacketQueueSizeOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    uint64_t IncomingPacketQueueMaxSizeBytes;
    uint64_t OutgoingPacketQueueMaxSizeBytes;
};

struct P2PQueryNATTypeOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
};

struct P2PQueryNATTypeCompleteInfo {
    Result ResultCode;
    void *ClientData;
    int32_t NATType;
};

// ---- Lobby -----------------------------------------------------------------------------------

struct LobbyCreateLobbyOptions {
    static constexpr int32_t kApiVersion = 10;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
    uint32_t MaxLobbyMembers;
    int32_t PermissionLevel;
    Bool bPresenceEnabled;
    Bool bAllowInvites;
    const char *BucketId;
    Bool bDisableHostMigration;
    Bool bEnableRTCRoom;
    const void *LocalRTCOptions;
    LobbyId LobbyId;
    Bool bEnableJoinById;
    Bool bRejoinAfterKickRequiresInvite;
    const uint32_t *AllowedPlatformIds;
    uint32_t AllowedPlatformIdsCount;
    Bool bCrossplayOptOut;
    int32_t RTCRoomJoinActionType;
};

struct LobbyCreateLobbyCallbackInfo {
    Result ResultCode;
    void *ClientData;
    LobbyId LobbyId;
};

struct LobbyDestroyLobbyOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
    LobbyId LobbyId;
};

struct LobbyDestroyLobbyCallbackInfo {
    Result ResultCode;
    void *ClientData;
    LobbyId LobbyId;
};

struct LobbyUpdateLobbyModificationOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
    LobbyId LobbyId;
};

struct LobbyUpdateLobbyOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    HLobbyModification LobbyModificationHandle;
};

struct LobbyUpdateLobbyCallbackInfo {
    Result ResultCode;
    void *ClientData;
    LobbyId LobbyId;
};

struct LobbyCreateLobbySearchOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    uint32_t MaxResults;
};

struct LobbyAttributeData {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    const char *Key;
    union {
        int64_t AsInt64;
        double AsDouble;
        Bool AsBool;
        const char *AsUtf8;
    } Value;
    int32_t ValueType;
};

struct LobbyModificationAddAttributeOptions {
    static constexpr int32_t kApiVersion = 2;
    int32_t ApiVersion;
    const LobbyAttributeData *Attribute;
    int32_t Visibility;
};

struct LobbySearchSetParameterOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    const LobbyAttributeData *Parameter;
    int32_t ComparisonOp;
};

struct LobbySearchFindOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    ProductUserId LocalUserId;
};

struct LobbySearchFindCallbackInfo {
    Result ResultCode;
    void *ClientData;
};

struct LobbySearchGetSearchResultCountOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
};

struct LobbySearchCopySearchResultByIndexOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
    uint32_t LobbyIndex;
};

struct LobbyDetailsGetLobbyOwnerOptions {
    static constexpr int32_t kApiVersion = 1;
    int32_t ApiVersion;
};

// ---- Function table --------------------------------------------------------------------------

#define REALMS_EOS_CALL __cdecl

using LogMessageFunction = void(REALMS_EOS_CALL *)(const LogMessage *);
using LoginCallback = void(REALMS_EOS_CALL *)(const ConnectLoginCallbackInfo *);
using CreateUserCallback = void(REALMS_EOS_CALL *)(const ConnectCreateUserCallbackInfo *);
using CreateDeviceIdCallback = void(REALMS_EOS_CALL *)(const ConnectCreateDeviceIdCallbackInfo *);
using AuthExpirationCallback = void(REALMS_EOS_CALL *)(const ConnectAuthExpirationCallbackInfo *);
using IncomingConnectionRequestCallback = void(REALMS_EOS_CALL *)(const P2PIncomingConnectionRequestInfo *);
using PeerConnectionEstablishedCallback = void(REALMS_EOS_CALL *)(const P2PPeerConnectionEstablishedInfo *);
using RemoteConnectionClosedCallback = void(REALMS_EOS_CALL *)(const P2PRemoteConnectionClosedInfo *);
using QueryNATTypeCallback = void(REALMS_EOS_CALL *)(const P2PQueryNATTypeCompleteInfo *);
using CreateLobbyCallback = void(REALMS_EOS_CALL *)(const LobbyCreateLobbyCallbackInfo *);
using DestroyLobbyCallback = void(REALMS_EOS_CALL *)(const LobbyDestroyLobbyCallbackInfo *);
using UpdateLobbyCallback = void(REALMS_EOS_CALL *)(const LobbyUpdateLobbyCallbackInfo *);
using LobbySearchFindCallback = void(REALMS_EOS_CALL *)(const LobbySearchFindCallbackInfo *);

// X(member, exported symbol, signature)
#define REALMS_EOS_FUNCTIONS(X)                                                                                       \
    X(initialize, EOS_Initialize, Result(REALMS_EOS_CALL *)(const InitializeOptions *))                              \
    X(shutdown, EOS_Shutdown, Result(REALMS_EOS_CALL *)())                                                           \
    X(result_to_string, EOS_EResult_ToString, const char *(REALMS_EOS_CALL *)(Result))                              \
    X(logging_set_callback, EOS_Logging_SetCallback, Result(REALMS_EOS_CALL *)(LogMessageFunction))                  \
    X(logging_set_log_level, EOS_Logging_SetLogLevel, Result(REALMS_EOS_CALL *)(int32_t, int32_t))                   \
    X(platform_create, EOS_Platform_Create, HPlatform(REALMS_EOS_CALL *)(const PlatformOptions *))                   \
    X(platform_release, EOS_Platform_Release, void(REALMS_EOS_CALL *)(HPlatform))                                    \
    X(platform_tick, EOS_Platform_Tick, void(REALMS_EOS_CALL *)(HPlatform))                                          \
    X(platform_set_application_status, EOS_Platform_SetApplicationStatus,                                          \
      Result(REALMS_EOS_CALL *)(HPlatform, int32_t))                                                                 \
    X(platform_set_network_status, EOS_Platform_SetNetworkStatus, Result(REALMS_EOS_CALL *)(HPlatform, int32_t))     \
    X(platform_get_connect_interface, EOS_Platform_GetConnectInterface, HConnect(REALMS_EOS_CALL *)(HPlatform))      \
    X(platform_get_p2p_interface, EOS_Platform_GetP2PInterface, HP2P(REALMS_EOS_CALL *)(HPlatform))                  \
    X(platform_get_lobby_interface, EOS_Platform_GetLobbyInterface, HLobby(REALMS_EOS_CALL *)(HPlatform))            \
    X(product_user_id_to_string, EOS_ProductUserId_ToString,                                                        \
      Result(REALMS_EOS_CALL *)(ProductUserId, char *, int32_t *))                                                   \
    X(product_user_id_from_string, EOS_ProductUserId_FromString, ProductUserId(REALMS_EOS_CALL *)(const char *))     \
    X(connect_login, EOS_Connect_Login,                                                                              \
      void(REALMS_EOS_CALL *)(HConnect, const ConnectLoginOptions *, void *, LoginCallback))                         \
    X(connect_create_user, EOS_Connect_CreateUser,                                                                   \
      void(REALMS_EOS_CALL *)(HConnect, const ConnectCreateUserOptions *, void *, CreateUserCallback))               \
    X(connect_create_device_id, EOS_Connect_CreateDeviceId,                                                          \
      void(REALMS_EOS_CALL *)(HConnect, const ConnectCreateDeviceIdOptions *, void *, CreateDeviceIdCallback))       \
    X(connect_add_notify_auth_expiration, EOS_Connect_AddNotifyAuthExpiration,                                       \
      NotificationId(REALMS_EOS_CALL *)(HConnect, const ConnectAddNotifyAuthExpirationOptions *, void *,             \
                                        AuthExpirationCallback))                                                     \
    X(connect_remove_notify_auth_expiration, EOS_Connect_RemoveNotifyAuthExpiration,                                 \
      void(REALMS_EOS_CALL *)(HConnect, NotificationId))                                                             \
    X(p2p_send_packet, EOS_P2P_SendPacket, Result(REALMS_EOS_CALL *)(HP2P, const P2PSendPacketOptions *))            \
    X(p2p_receive_packet, EOS_P2P_ReceivePacket,                                                                     \
      Result(REALMS_EOS_CALL *)(HP2P, const P2PReceivePacketOptions *, ProductUserId *, P2PSocketId *, uint8_t *,    \
                                void *, uint32_t *))                                                                 \
    X(p2p_add_notify_peer_connection_request, EOS_P2P_AddNotifyPeerConnectionRequest,                                \
      NotificationId(REALMS_EOS_CALL *)(HP2P, const P2PAddNotifyOptions *, void *,                                   \
                                        IncomingConnectionRequestCallback))                                          \
    X(p2p_remove_notify_peer_connection_request, EOS_P2P_RemoveNotifyPeerConnectionRequest,                          \
      void(REALMS_EOS_CALL *)(HP2P, NotificationId))                                                                 \
    X(p2p_add_notify_peer_connection_established, EOS_P2P_AddNotifyPeerConnectionEstablished,                        \
      NotificationId(REALMS_EOS_CALL *)(HP2P, const P2PAddNotifyOptions *, void *,                                   \
                                        PeerConnectionEstablishedCallback))                                          \
    X(p2p_remove_notify_peer_connection_established, EOS_P2P_RemoveNotifyPeerConnectionEstablished,                  \
      void(REALMS_EOS_CALL *)(HP2P, NotificationId))                                                                 \
    X(p2p_add_notify_peer_connection_closed, EOS_P2P_AddNotifyPeerConnectionClosed,                                  \
      NotificationId(REALMS_EOS_CALL *)(HP2P, const P2PAddNotifyOptions *, void *, RemoteConnectionClosedCallback))  \
    X(p2p_remove_notify_peer_connection_closed, EOS_P2P_RemoveNotifyPeerConnectionClosed,                            \
      void(REALMS_EOS_CALL *)(HP2P, NotificationId))                                                                 \
    X(p2p_accept_connection, EOS_P2P_AcceptConnection, Result(REALMS_EOS_CALL *)(HP2P, const P2PConnectionOptions *)) \
    X(p2p_close_connection, EOS_P2P_CloseConnection, Result(REALMS_EOS_CALL *)(HP2P, const P2PConnectionOptions *))   \
    X(p2p_close_connections, EOS_P2P_CloseConnections,                                                               \
      Result(REALMS_EOS_CALL *)(HP2P, const P2PCloseConnectionsOptions *))                                           \
    X(p2p_set_relay_control, EOS_P2P_SetRelayControl,                                                                \
      Result(REALMS_EOS_CALL *)(HP2P, const P2PSetRelayControlOptions *))                                            \
    X(p2p_set_packet_queue_size, EOS_P2P_SetPacketQueueSize,                                                         \
      Result(REALMS_EOS_CALL *)(HP2P, const P2PSetPacketQueueSizeOptions *))                                         \
    X(p2p_query_nat_type, EOS_P2P_QueryNATType,                                                                      \
      void(REALMS_EOS_CALL *)(HP2P, const P2PQueryNATTypeOptions *, void *, QueryNATTypeCallback))                   \
    X(lobby_create_lobby, EOS_Lobby_CreateLobby,                                                                     \
      void(REALMS_EOS_CALL *)(HLobby, const LobbyCreateLobbyOptions *, void *, CreateLobbyCallback))                 \
    X(lobby_destroy_lobby, EOS_Lobby_DestroyLobby,                                                                   \
      void(REALMS_EOS_CALL *)(HLobby, const LobbyDestroyLobbyOptions *, void *, DestroyLobbyCallback))               \
    X(lobby_update_lobby_modification, EOS_Lobby_UpdateLobbyModification,                                            \
      Result(REALMS_EOS_CALL *)(HLobby, const LobbyUpdateLobbyModificationOptions *, HLobbyModification *))          \
    X(lobby_update_lobby, EOS_Lobby_UpdateLobby,                                                                     \
      void(REALMS_EOS_CALL *)(HLobby, const LobbyUpdateLobbyOptions *, void *, UpdateLobbyCallback))                 \
    X(lobby_create_lobby_search, EOS_Lobby_CreateLobbySearch,                                                        \
      Result(REALMS_EOS_CALL *)(HLobby, const LobbyCreateLobbySearchOptions *, HLobbySearch *))                      \
    X(lobby_modification_add_attribute, EOS_LobbyModification_AddAttribute,                                          \
      Result(REALMS_EOS_CALL *)(HLobbyModification, const LobbyModificationAddAttributeOptions *))                   \
    X(lobby_modification_release, EOS_LobbyModification_Release, void(REALMS_EOS_CALL *)(HLobbyModification))        \
    X(lobby_search_set_parameter, EOS_LobbySearch_SetParameter,                                                      \
      Result(REALMS_EOS_CALL *)(HLobbySearch, const LobbySearchSetParameterOptions *))                               \
    X(lobby_search_find, EOS_LobbySearch_Find,                                                                       \
      void(REALMS_EOS_CALL *)(HLobbySearch, const LobbySearchFindOptions *, void *, LobbySearchFindCallback))        \
    X(lobby_search_get_search_result_count, EOS_LobbySearch_GetSearchResultCount,                                    \
      uint32_t(REALMS_EOS_CALL *)(HLobbySearch, const LobbySearchGetSearchResultCountOptions *))                     \
    X(lobby_search_copy_search_result_by_index, EOS_LobbySearch_CopySearchResultByIndex,                             \
      Result(REALMS_EOS_CALL *)(HLobbySearch, const LobbySearchCopySearchResultByIndexOptions *, HLobbyDetails *))   \
    X(lobby_search_release, EOS_LobbySearch_Release, void(REALMS_EOS_CALL *)(HLobbySearch))                          \
    X(lobby_details_get_lobby_owner, EOS_LobbyDetails_GetLobbyOwner,                                                 \
      ProductUserId(REALMS_EOS_CALL *)(HLobbyDetails, const LobbyDetailsGetLobbyOwnerOptions *))                     \
    X(lobby_details_release, EOS_LobbyDetails_Release, void(REALMS_EOS_CALL *)(HLobbyDetails))

struct Api {
#define REALMS_EOS_MEMBER(member, symbol, signature)                                                                  \
    using member##_function = signature;                                                                               \
    member##_function member = nullptr;
    REALMS_EOS_FUNCTIONS(REALMS_EOS_MEMBER)
#undef REALMS_EOS_MEMBER
};

} // namespace realms::eos
