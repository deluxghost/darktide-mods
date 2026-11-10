// Compile-time verification of eos_api.h against the official EOS SDK headers.
// Built only when build.ps1 receives -EosSdkRoot, and it produces no code.
// Official structs may gain trailing fields in newer SDKs, so each pinned struct must match the
// official field offsets, fit inside the official size, and use an ApiVersion the SDK still knows.

#include "eos_api.h"

#include <eos_connect.h>
#include <eos_lobby.h>
#include <eos_logging.h>
#include <eos_p2p.h>
#include <eos_sdk.h>

#include <cstddef>

namespace realms::eos {
namespace {

#define CHECK_FIELD(ours, theirs, field)                                                                               \
    static_assert(offsetof(ours, field) == offsetof(theirs, field), #ours "::" #field " offset differs");              \
    static_assert(sizeof(ours::field) == sizeof(theirs::field), #ours "::" #field " size differs")

#define CHECK_SIZE(ours, theirs)                                                                                       \
    static_assert(sizeof(ours) <= sizeof(theirs), #ours " is larger than the official struct");                       \
    static_assert(alignof(ours) == alignof(theirs), #ours " alignment differs")

#define CHECK_VERSION(ours, latest)                                                                                    \
    static_assert(ours::kApiVersion >= 1 && ours::kApiVersion <= (latest), #ours " ApiVersion is unknown to the SDK")

#define CHECK_EXACT_SIZE(ours, theirs) static_assert(sizeof(ours) == sizeof(theirs), #ours " size differs")

#define CHECK_CONSTANT(ours, theirs) static_assert(static_cast<long long>(ours) == static_cast<long long>(theirs), #ours)

CHECK_CONSTANT(kSuccess, EOS_EResult::EOS_Success);
CHECK_CONSTANT(kNoConnection, EOS_EResult::EOS_NoConnection);
CHECK_CONSTANT(kInvalidUser, EOS_EResult::EOS_InvalidUser);
CHECK_CONSTANT(kInvalidAuth, EOS_EResult::EOS_InvalidAuth);
CHECK_CONSTANT(kAccessDenied, EOS_EResult::EOS_AccessDenied);
CHECK_CONSTANT(kTooManyRequests, EOS_EResult::EOS_TooManyRequests);
CHECK_CONSTANT(kInvalidParameters, EOS_EResult::EOS_InvalidParameters);
CHECK_CONSTANT(kNotConfigured, EOS_EResult::EOS_NotConfigured);
CHECK_CONSTANT(kAlreadyConfigured, EOS_EResult::EOS_AlreadyConfigured);
CHECK_CONSTANT(kCanceled, EOS_EResult::EOS_Canceled);
CHECK_CONSTANT(kNotFound, EOS_EResult::EOS_NotFound);
CHECK_CONSTANT(kOperationWillRetry, EOS_EResult::EOS_OperationWillRetry);
CHECK_CONSTANT(kLimitExceeded, EOS_EResult::EOS_LimitExceeded);
CHECK_CONSTANT(kDuplicateNotAllowed, EOS_EResult::EOS_DuplicateNotAllowed);
CHECK_CONSTANT(kTrue, EOS_TRUE);
CHECK_CONSTANT(kFalse, EOS_FALSE);
CHECK_CONSTANT(kInvalidNotificationId, EOS_INVALID_NOTIFICATIONID);
CHECK_CONSTANT(kProductUserIdMaxLength, EOS_PRODUCTUSERID_MAX_LENGTH);
CHECK_CONSTANT(kP2PMaxPacketSize, EOS_P2P_MAX_PACKET_SIZE);
CHECK_CONSTANT(kPlatformFlagDisableOverlay, EOS_PF_DISABLE_OVERLAY);
CHECK_CONSTANT(kPlatformFlagDisableSocialOverlay, EOS_PF_DISABLE_SOCIAL_OVERLAY);
CHECK_CONSTANT(kExternalCredentialDeviceIdAccessToken, EOS_EExternalCredentialType::EOS_ECT_DEVICEID_ACCESS_TOKEN);
CHECK_CONSTANT(kPacketUnreliableUnordered, EOS_EPacketReliability::EOS_PR_UnreliableUnordered);
CHECK_CONSTANT(kPacketReliableOrdered, EOS_EPacketReliability::EOS_PR_ReliableOrdered);
CHECK_CONSTANT(kRelayAllowRelays, EOS_ERelayControl::EOS_RC_AllowRelays);
CHECK_CONSTANT(kLobbyPermissionPublicAdvertised, EOS_ELobbyPermissionLevel::EOS_LPL_PUBLICADVERTISED);
CHECK_CONSTANT(kAttributeString, EOS_EAttributeType::EOS_AT_STRING);
CHECK_CONSTANT(kLobbyAttributePublic, EOS_ELobbyAttributeVisibility::EOS_LAT_PUBLIC);
CHECK_CONSTANT(kComparisonEqual, EOS_EComparisonOp::EOS_CO_EQUAL);
CHECK_CONSTANT(kApplicationForeground, EOS_EApplicationStatus::EOS_AS_Foreground);
CHECK_CONSTANT(kNetworkOnline, EOS_ENetworkStatus::EOS_NS_Online);
CHECK_CONSTANT(kLogCategoryAll, EOS_ELogCategory::EOS_LC_ALL_CATEGORIES);
CHECK_CONSTANT(kLogLevelWarning, EOS_ELogLevel::EOS_LOG_Warning);

CHECK_VERSION(InitializeOptions, EOS_INITIALIZE_API_LATEST);
CHECK_SIZE(InitializeOptions, EOS_InitializeOptions);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, ApiVersion);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, AllocateMemoryFunction);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, ReallocateMemoryFunction);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, ReleaseMemoryFunction);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, ProductName);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, ProductVersion);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, Reserved);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, SystemInitializeOptions);
CHECK_FIELD(InitializeOptions, EOS_InitializeOptions, OverrideThreadAffinity);

CHECK_EXACT_SIZE(PlatformClientCredentials, EOS_Platform_ClientCredentials);
CHECK_FIELD(PlatformClientCredentials, EOS_Platform_ClientCredentials, ClientId);
CHECK_FIELD(PlatformClientCredentials, EOS_Platform_ClientCredentials, ClientSecret);

CHECK_VERSION(PlatformOptions, EOS_PLATFORM_OPTIONS_API_LATEST);
CHECK_SIZE(PlatformOptions, EOS_Platform_Options);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, ApiVersion);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, Reserved);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, ProductId);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, SandboxId);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, ClientCredentials);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, bIsServer);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, EncryptionKey);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, OverrideCountryCode);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, OverrideLocaleCode);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, DeploymentId);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, Flags);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, CacheDirectory);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, TickBudgetInMilliseconds);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, RTCOptions);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, IntegratedPlatformOptionsContainerHandle);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, SystemSpecificOptions);
CHECK_FIELD(PlatformOptions, EOS_Platform_Options, TaskNetworkTimeoutSeconds);

CHECK_EXACT_SIZE(LogMessage, EOS_LogMessage);
CHECK_FIELD(LogMessage, EOS_LogMessage, Category);
CHECK_FIELD(LogMessage, EOS_LogMessage, Message);
CHECK_FIELD(LogMessage, EOS_LogMessage, Level);

CHECK_VERSION(ConnectCredentials, EOS_CONNECT_CREDENTIALS_API_LATEST);
CHECK_SIZE(ConnectCredentials, EOS_Connect_Credentials);
CHECK_FIELD(ConnectCredentials, EOS_Connect_Credentials, ApiVersion);
CHECK_FIELD(ConnectCredentials, EOS_Connect_Credentials, Token);
CHECK_FIELD(ConnectCredentials, EOS_Connect_Credentials, Type);

CHECK_VERSION(ConnectUserLoginInfo, EOS_CONNECT_USERLOGININFO_API_LATEST);
CHECK_SIZE(ConnectUserLoginInfo, EOS_Connect_UserLoginInfo);
CHECK_FIELD(ConnectUserLoginInfo, EOS_Connect_UserLoginInfo, ApiVersion);
CHECK_FIELD(ConnectUserLoginInfo, EOS_Connect_UserLoginInfo, DisplayName);
CHECK_FIELD(ConnectUserLoginInfo, EOS_Connect_UserLoginInfo, NsaIdToken);

CHECK_VERSION(ConnectLoginOptions, EOS_CONNECT_LOGIN_API_LATEST);
CHECK_SIZE(ConnectLoginOptions, EOS_Connect_LoginOptions);
CHECK_FIELD(ConnectLoginOptions, EOS_Connect_LoginOptions, ApiVersion);
CHECK_FIELD(ConnectLoginOptions, EOS_Connect_LoginOptions, Credentials);
CHECK_FIELD(ConnectLoginOptions, EOS_Connect_LoginOptions, UserLoginInfo);

CHECK_SIZE(ConnectLoginCallbackInfo, EOS_Connect_LoginCallbackInfo);
CHECK_FIELD(ConnectLoginCallbackInfo, EOS_Connect_LoginCallbackInfo, ResultCode);
CHECK_FIELD(ConnectLoginCallbackInfo, EOS_Connect_LoginCallbackInfo, ClientData);
CHECK_FIELD(ConnectLoginCallbackInfo, EOS_Connect_LoginCallbackInfo, LocalUserId);
CHECK_FIELD(ConnectLoginCallbackInfo, EOS_Connect_LoginCallbackInfo, ContinuanceToken);

CHECK_VERSION(ConnectCreateUserOptions, EOS_CONNECT_CREATEUSER_API_LATEST);
CHECK_SIZE(ConnectCreateUserOptions, EOS_Connect_CreateUserOptions);
CHECK_FIELD(ConnectCreateUserOptions, EOS_Connect_CreateUserOptions, ApiVersion);
CHECK_FIELD(ConnectCreateUserOptions, EOS_Connect_CreateUserOptions, ContinuanceToken);

CHECK_SIZE(ConnectCreateUserCallbackInfo, EOS_Connect_CreateUserCallbackInfo);
CHECK_FIELD(ConnectCreateUserCallbackInfo, EOS_Connect_CreateUserCallbackInfo, ResultCode);
CHECK_FIELD(ConnectCreateUserCallbackInfo, EOS_Connect_CreateUserCallbackInfo, ClientData);
CHECK_FIELD(ConnectCreateUserCallbackInfo, EOS_Connect_CreateUserCallbackInfo, LocalUserId);

CHECK_VERSION(ConnectCreateDeviceIdOptions, EOS_CONNECT_CREATEDEVICEID_API_LATEST);
CHECK_SIZE(ConnectCreateDeviceIdOptions, EOS_Connect_CreateDeviceIdOptions);
CHECK_FIELD(ConnectCreateDeviceIdOptions, EOS_Connect_CreateDeviceIdOptions, ApiVersion);
CHECK_FIELD(ConnectCreateDeviceIdOptions, EOS_Connect_CreateDeviceIdOptions, DeviceModel);

CHECK_SIZE(ConnectCreateDeviceIdCallbackInfo, EOS_Connect_CreateDeviceIdCallbackInfo);
CHECK_FIELD(ConnectCreateDeviceIdCallbackInfo, EOS_Connect_CreateDeviceIdCallbackInfo, ResultCode);
CHECK_FIELD(ConnectCreateDeviceIdCallbackInfo, EOS_Connect_CreateDeviceIdCallbackInfo, ClientData);

CHECK_VERSION(ConnectAddNotifyAuthExpirationOptions, EOS_CONNECT_ADDNOTIFYAUTHEXPIRATION_API_LATEST);
CHECK_SIZE(ConnectAddNotifyAuthExpirationOptions, EOS_Connect_AddNotifyAuthExpirationOptions);
CHECK_FIELD(ConnectAddNotifyAuthExpirationOptions, EOS_Connect_AddNotifyAuthExpirationOptions, ApiVersion);

CHECK_SIZE(ConnectAuthExpirationCallbackInfo, EOS_Connect_AuthExpirationCallbackInfo);
CHECK_FIELD(ConnectAuthExpirationCallbackInfo, EOS_Connect_AuthExpirationCallbackInfo, ClientData);
CHECK_FIELD(ConnectAuthExpirationCallbackInfo, EOS_Connect_AuthExpirationCallbackInfo, LocalUserId);

CHECK_VERSION(P2PSocketId, EOS_P2P_SOCKETID_API_LATEST);
CHECK_SIZE(P2PSocketId, EOS_P2P_SocketId);
CHECK_FIELD(P2PSocketId, EOS_P2P_SocketId, ApiVersion);
CHECK_FIELD(P2PSocketId, EOS_P2P_SocketId, SocketName);

CHECK_VERSION(P2PSendPacketOptions, EOS_P2P_SENDPACKET_API_LATEST);
CHECK_SIZE(P2PSendPacketOptions, EOS_P2P_SendPacketOptions);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, ApiVersion);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, LocalUserId);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, RemoteUserId);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, SocketId);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, Channel);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, DataLengthBytes);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, Data);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, bAllowDelayedDelivery);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, Reliability);
CHECK_FIELD(P2PSendPacketOptions, EOS_P2P_SendPacketOptions, bDisableAutoAcceptConnection);

CHECK_VERSION(P2PReceivePacketOptions, EOS_P2P_RECEIVEPACKET_API_LATEST);
CHECK_SIZE(P2PReceivePacketOptions, EOS_P2P_ReceivePacketOptions);
CHECK_FIELD(P2PReceivePacketOptions, EOS_P2P_ReceivePacketOptions, ApiVersion);
CHECK_FIELD(P2PReceivePacketOptions, EOS_P2P_ReceivePacketOptions, LocalUserId);
CHECK_FIELD(P2PReceivePacketOptions, EOS_P2P_ReceivePacketOptions, MaxDataSizeBytes);
CHECK_FIELD(P2PReceivePacketOptions, EOS_P2P_ReceivePacketOptions, RequestedChannel);

CHECK_VERSION(P2PAddNotifyOptions, EOS_P2P_ADDNOTIFYPEERCONNECTIONREQUEST_API_LATEST);
CHECK_VERSION(P2PAddNotifyOptions, EOS_P2P_ADDNOTIFYPEERCONNECTIONESTABLISHED_API_LATEST);
CHECK_VERSION(P2PAddNotifyOptions, EOS_P2P_ADDNOTIFYPEERCONNECTIONCLOSED_API_LATEST);
CHECK_SIZE(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionRequestOptions);
CHECK_FIELD(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionRequestOptions, ApiVersion);
CHECK_FIELD(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionRequestOptions, LocalUserId);
CHECK_FIELD(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionRequestOptions, SocketId);
CHECK_SIZE(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionEstablishedOptions);
CHECK_FIELD(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionEstablishedOptions, LocalUserId);
CHECK_FIELD(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionEstablishedOptions, SocketId);
CHECK_SIZE(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionClosedOptions);
CHECK_FIELD(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionClosedOptions, LocalUserId);
CHECK_FIELD(P2PAddNotifyOptions, EOS_P2P_AddNotifyPeerConnectionClosedOptions, SocketId);

CHECK_SIZE(P2PIncomingConnectionRequestInfo, EOS_P2P_OnIncomingConnectionRequestInfo);
CHECK_FIELD(P2PIncomingConnectionRequestInfo, EOS_P2P_OnIncomingConnectionRequestInfo, ClientData);
CHECK_FIELD(P2PIncomingConnectionRequestInfo, EOS_P2P_OnIncomingConnectionRequestInfo, LocalUserId);
CHECK_FIELD(P2PIncomingConnectionRequestInfo, EOS_P2P_OnIncomingConnectionRequestInfo, RemoteUserId);
CHECK_FIELD(P2PIncomingConnectionRequestInfo, EOS_P2P_OnIncomingConnectionRequestInfo, SocketId);

CHECK_SIZE(P2PPeerConnectionEstablishedInfo, EOS_P2P_OnPeerConnectionEstablishedInfo);
CHECK_FIELD(P2PPeerConnectionEstablishedInfo, EOS_P2P_OnPeerConnectionEstablishedInfo, ClientData);
CHECK_FIELD(P2PPeerConnectionEstablishedInfo, EOS_P2P_OnPeerConnectionEstablishedInfo, LocalUserId);
CHECK_FIELD(P2PPeerConnectionEstablishedInfo, EOS_P2P_OnPeerConnectionEstablishedInfo, RemoteUserId);
CHECK_FIELD(P2PPeerConnectionEstablishedInfo, EOS_P2P_OnPeerConnectionEstablishedInfo, SocketId);
CHECK_FIELD(P2PPeerConnectionEstablishedInfo, EOS_P2P_OnPeerConnectionEstablishedInfo, ConnectionType);
CHECK_FIELD(P2PPeerConnectionEstablishedInfo, EOS_P2P_OnPeerConnectionEstablishedInfo, NetworkType);

CHECK_SIZE(P2PRemoteConnectionClosedInfo, EOS_P2P_OnRemoteConnectionClosedInfo);
CHECK_FIELD(P2PRemoteConnectionClosedInfo, EOS_P2P_OnRemoteConnectionClosedInfo, ClientData);
CHECK_FIELD(P2PRemoteConnectionClosedInfo, EOS_P2P_OnRemoteConnectionClosedInfo, LocalUserId);
CHECK_FIELD(P2PRemoteConnectionClosedInfo, EOS_P2P_OnRemoteConnectionClosedInfo, RemoteUserId);
CHECK_FIELD(P2PRemoteConnectionClosedInfo, EOS_P2P_OnRemoteConnectionClosedInfo, SocketId);
CHECK_FIELD(P2PRemoteConnectionClosedInfo, EOS_P2P_OnRemoteConnectionClosedInfo, Reason);

CHECK_VERSION(P2PConnectionOptions, EOS_P2P_ACCEPTCONNECTION_API_LATEST);
CHECK_VERSION(P2PConnectionOptions, EOS_P2P_CLOSECONNECTION_API_LATEST);
CHECK_SIZE(P2PConnectionOptions, EOS_P2P_AcceptConnectionOptions);
CHECK_FIELD(P2PConnectionOptions, EOS_P2P_AcceptConnectionOptions, ApiVersion);
CHECK_FIELD(P2PConnectionOptions, EOS_P2P_AcceptConnectionOptions, LocalUserId);
CHECK_FIELD(P2PConnectionOptions, EOS_P2P_AcceptConnectionOptions, RemoteUserId);
CHECK_FIELD(P2PConnectionOptions, EOS_P2P_AcceptConnectionOptions, SocketId);
CHECK_SIZE(P2PConnectionOptions, EOS_P2P_CloseConnectionOptions);
CHECK_FIELD(P2PConnectionOptions, EOS_P2P_CloseConnectionOptions, LocalUserId);
CHECK_FIELD(P2PConnectionOptions, EOS_P2P_CloseConnectionOptions, RemoteUserId);
CHECK_FIELD(P2PConnectionOptions, EOS_P2P_CloseConnectionOptions, SocketId);

CHECK_VERSION(P2PCloseConnectionsOptions, EOS_P2P_CLOSECONNECTIONS_API_LATEST);
CHECK_SIZE(P2PCloseConnectionsOptions, EOS_P2P_CloseConnectionsOptions);
CHECK_FIELD(P2PCloseConnectionsOptions, EOS_P2P_CloseConnectionsOptions, LocalUserId);
CHECK_FIELD(P2PCloseConnectionsOptions, EOS_P2P_CloseConnectionsOptions, SocketId);

CHECK_VERSION(P2PSetRelayControlOptions, EOS_P2P_SETRELAYCONTROL_API_LATEST);
CHECK_SIZE(P2PSetRelayControlOptions, EOS_P2P_SetRelayControlOptions);
CHECK_FIELD(P2PSetRelayControlOptions, EOS_P2P_SetRelayControlOptions, RelayControl);

CHECK_VERSION(P2PSetPacketQueueSizeOptions, EOS_P2P_SETPACKETQUEUESIZE_API_LATEST);
CHECK_SIZE(P2PSetPacketQueueSizeOptions, EOS_P2P_SetPacketQueueSizeOptions);
CHECK_FIELD(P2PSetPacketQueueSizeOptions, EOS_P2P_SetPacketQueueSizeOptions, IncomingPacketQueueMaxSizeBytes);
CHECK_FIELD(P2PSetPacketQueueSizeOptions, EOS_P2P_SetPacketQueueSizeOptions, OutgoingPacketQueueMaxSizeBytes);

CHECK_VERSION(P2PQueryNATTypeOptions, EOS_P2P_QUERYNATTYPE_API_LATEST);
CHECK_SIZE(P2PQueryNATTypeOptions, EOS_P2P_QueryNATTypeOptions);

CHECK_SIZE(P2PQueryNATTypeCompleteInfo, EOS_P2P_OnQueryNATTypeCompleteInfo);
CHECK_FIELD(P2PQueryNATTypeCompleteInfo, EOS_P2P_OnQueryNATTypeCompleteInfo, ResultCode);
CHECK_FIELD(P2PQueryNATTypeCompleteInfo, EOS_P2P_OnQueryNATTypeCompleteInfo, ClientData);
CHECK_FIELD(P2PQueryNATTypeCompleteInfo, EOS_P2P_OnQueryNATTypeCompleteInfo, NATType);

CHECK_VERSION(LobbyCreateLobbyOptions, EOS_LOBBY_CREATELOBBY_API_LATEST);
CHECK_SIZE(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, ApiVersion);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, LocalUserId);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, MaxLobbyMembers);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, PermissionLevel);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, bPresenceEnabled);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, bAllowInvites);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, BucketId);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, bDisableHostMigration);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, bEnableRTCRoom);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, LocalRTCOptions);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, LobbyId);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, bEnableJoinById);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, bRejoinAfterKickRequiresInvite);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, AllowedPlatformIds);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, AllowedPlatformIdsCount);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, bCrossplayOptOut);
CHECK_FIELD(LobbyCreateLobbyOptions, EOS_Lobby_CreateLobbyOptions, RTCRoomJoinActionType);

CHECK_SIZE(LobbyCreateLobbyCallbackInfo, EOS_Lobby_CreateLobbyCallbackInfo);
CHECK_FIELD(LobbyCreateLobbyCallbackInfo, EOS_Lobby_CreateLobbyCallbackInfo, ResultCode);
CHECK_FIELD(LobbyCreateLobbyCallbackInfo, EOS_Lobby_CreateLobbyCallbackInfo, ClientData);
CHECK_FIELD(LobbyCreateLobbyCallbackInfo, EOS_Lobby_CreateLobbyCallbackInfo, LobbyId);

CHECK_VERSION(LobbyDestroyLobbyOptions, EOS_LOBBY_DESTROYLOBBY_API_LATEST);
CHECK_SIZE(LobbyDestroyLobbyOptions, EOS_Lobby_DestroyLobbyOptions);
CHECK_FIELD(LobbyDestroyLobbyOptions, EOS_Lobby_DestroyLobbyOptions, LocalUserId);
CHECK_FIELD(LobbyDestroyLobbyOptions, EOS_Lobby_DestroyLobbyOptions, LobbyId);

CHECK_SIZE(LobbyDestroyLobbyCallbackInfo, EOS_Lobby_DestroyLobbyCallbackInfo);
CHECK_FIELD(LobbyDestroyLobbyCallbackInfo, EOS_Lobby_DestroyLobbyCallbackInfo, ResultCode);
CHECK_FIELD(LobbyDestroyLobbyCallbackInfo, EOS_Lobby_DestroyLobbyCallbackInfo, ClientData);
CHECK_FIELD(LobbyDestroyLobbyCallbackInfo, EOS_Lobby_DestroyLobbyCallbackInfo, LobbyId);

CHECK_VERSION(LobbyUpdateLobbyModificationOptions, EOS_LOBBY_UPDATELOBBYMODIFICATION_API_LATEST);
CHECK_SIZE(LobbyUpdateLobbyModificationOptions, EOS_Lobby_UpdateLobbyModificationOptions);
CHECK_FIELD(LobbyUpdateLobbyModificationOptions, EOS_Lobby_UpdateLobbyModificationOptions, LocalUserId);
CHECK_FIELD(LobbyUpdateLobbyModificationOptions, EOS_Lobby_UpdateLobbyModificationOptions, LobbyId);

CHECK_VERSION(LobbyUpdateLobbyOptions, EOS_LOBBY_UPDATELOBBY_API_LATEST);
CHECK_SIZE(LobbyUpdateLobbyOptions, EOS_Lobby_UpdateLobbyOptions);
CHECK_FIELD(LobbyUpdateLobbyOptions, EOS_Lobby_UpdateLobbyOptions, LobbyModificationHandle);

CHECK_SIZE(LobbyUpdateLobbyCallbackInfo, EOS_Lobby_UpdateLobbyCallbackInfo);
CHECK_FIELD(LobbyUpdateLobbyCallbackInfo, EOS_Lobby_UpdateLobbyCallbackInfo, ResultCode);
CHECK_FIELD(LobbyUpdateLobbyCallbackInfo, EOS_Lobby_UpdateLobbyCallbackInfo, ClientData);
CHECK_FIELD(LobbyUpdateLobbyCallbackInfo, EOS_Lobby_UpdateLobbyCallbackInfo, LobbyId);

CHECK_VERSION(LobbyCreateLobbySearchOptions, EOS_LOBBY_CREATELOBBYSEARCH_API_LATEST);
CHECK_SIZE(LobbyCreateLobbySearchOptions, EOS_Lobby_CreateLobbySearchOptions);
CHECK_FIELD(LobbyCreateLobbySearchOptions, EOS_Lobby_CreateLobbySearchOptions, MaxResults);

CHECK_VERSION(LobbyAttributeData, EOS_LOBBY_ATTRIBUTEDATA_API_LATEST);
CHECK_SIZE(LobbyAttributeData, EOS_Lobby_AttributeData);
CHECK_FIELD(LobbyAttributeData, EOS_Lobby_AttributeData, ApiVersion);
CHECK_FIELD(LobbyAttributeData, EOS_Lobby_AttributeData, Key);
CHECK_FIELD(LobbyAttributeData, EOS_Lobby_AttributeData, Value);
CHECK_FIELD(LobbyAttributeData, EOS_Lobby_AttributeData, ValueType);

CHECK_VERSION(LobbyModificationAddAttributeOptions, EOS_LOBBYMODIFICATION_ADDATTRIBUTE_API_LATEST);
CHECK_SIZE(LobbyModificationAddAttributeOptions, EOS_LobbyModification_AddAttributeOptions);
CHECK_FIELD(LobbyModificationAddAttributeOptions, EOS_LobbyModification_AddAttributeOptions, Attribute);
CHECK_FIELD(LobbyModificationAddAttributeOptions, EOS_LobbyModification_AddAttributeOptions, Visibility);

CHECK_VERSION(LobbySearchSetParameterOptions, EOS_LOBBYSEARCH_SETPARAMETER_API_LATEST);
CHECK_SIZE(LobbySearchSetParameterOptions, EOS_LobbySearch_SetParameterOptions);
CHECK_FIELD(LobbySearchSetParameterOptions, EOS_LobbySearch_SetParameterOptions, Parameter);
CHECK_FIELD(LobbySearchSetParameterOptions, EOS_LobbySearch_SetParameterOptions, ComparisonOp);

CHECK_VERSION(LobbySearchFindOptions, EOS_LOBBYSEARCH_FIND_API_LATEST);
CHECK_SIZE(LobbySearchFindOptions, EOS_LobbySearch_FindOptions);
CHECK_FIELD(LobbySearchFindOptions, EOS_LobbySearch_FindOptions, LocalUserId);

CHECK_SIZE(LobbySearchFindCallbackInfo, EOS_LobbySearch_FindCallbackInfo);
CHECK_FIELD(LobbySearchFindCallbackInfo, EOS_LobbySearch_FindCallbackInfo, ResultCode);
CHECK_FIELD(LobbySearchFindCallbackInfo, EOS_LobbySearch_FindCallbackInfo, ClientData);

CHECK_VERSION(LobbySearchGetSearchResultCountOptions, EOS_LOBBYSEARCH_GETSEARCHRESULTCOUNT_API_LATEST);
CHECK_SIZE(LobbySearchGetSearchResultCountOptions, EOS_LobbySearch_GetSearchResultCountOptions);

CHECK_VERSION(LobbySearchCopySearchResultByIndexOptions, EOS_LOBBYSEARCH_COPYSEARCHRESULTBYINDEX_API_LATEST);
CHECK_SIZE(LobbySearchCopySearchResultByIndexOptions, EOS_LobbySearch_CopySearchResultByIndexOptions);
CHECK_FIELD(LobbySearchCopySearchResultByIndexOptions, EOS_LobbySearch_CopySearchResultByIndexOptions, LobbyIndex);

CHECK_VERSION(LobbyDetailsGetLobbyOwnerOptions, EOS_LOBBYDETAILS_GETLOBBYOWNER_API_LATEST);
CHECK_SIZE(LobbyDetailsGetLobbyOwnerOptions, EOS_LobbyDetails_GetLobbyOwnerOptions);

// Every symbol the runtime resolves must exist in the official headers.
#define CHECK_SYMBOL(member, symbol, signature) [[maybe_unused]] constexpr auto *member##_symbol = &::symbol;
REALMS_EOS_FUNCTIONS(CHECK_SYMBOL)
#undef CHECK_SYMBOL

} // namespace
} // namespace realms::eos
