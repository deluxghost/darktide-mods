local ffi = Mods.lua.ffi

if not pcall(ffi.typeof, "RealmsRuntime_CDEF") then
	ffi.cdef([[
		typedef struct RealmsRuntimeEvent {
			uint32_t struct_size;
			uint32_t type;
			char peer_id[17];
			uint32_t channel_id;
			int32_t code;
			char message[160];
		} RealmsRuntimeEvent;

		typedef struct RealmsResolvedAddresses {
			uint32_t struct_size;
			uint32_t count;
			char addresses[8][46];
		} RealmsResolvedAddresses;

		typedef struct RealmsBinaryMessage {
			uint32_t struct_size;
			uint32_t channel_id;
			uint32_t message_type;
			uint32_t message_id;
			uint32_t reliable;
			uint32_t payload_size;
			char sender_peer_id[17];
			char recipient_peer_id[17];
		} RealmsBinaryMessage;

		typedef struct RealmsBinaryStats {
			uint32_t struct_size;
			uint32_t queued_messages;
			uint64_t queued_bytes;
			uint64_t sent_messages;
			uint64_t received_messages;
			uint64_t expired_messages;
		} RealmsBinaryStats;

		int RealmsRuntime_Initialize(char* error, int error_capacity);
		uint32_t RealmsRuntime_MaximumHostMembers(void);
		int RealmsRuntime_ResolveAddresses(const char* address, RealmsResolvedAddresses* resolved,
			char* error, int error_capacity);
		int RealmsRuntime_SetClientIpv6MemberAddressSupport(int enabled, char* error, int error_capacity);
		int RealmsRuntime_StartLocalSession(const char* local_account_id, const char* local_peer_id,
			int requested_listen_port, int* listen_udp_port, int* start_error_code, char* error, int error_capacity);
		int RealmsRuntime_IsPeerConnected(const char* peer_id, int* connected, char* error, int error_capacity);
		int RealmsRuntime_ReleasePeerTransportState(const char* peer_id, char* error, int error_capacity);
		int RealmsRuntime_AdoptPeerTransportState(const char* peer_id, char* error, int error_capacity);
		int RealmsRuntime_ReapAbandonedPeerTransportState(uint32_t idle_timeout_ms, int* reaped_count,
			char* error, int error_capacity);
		int RealmsRuntime_PollEvent(RealmsRuntimeEvent* event, char* error, int error_capacity);
		int RealmsRuntime_CloseLocalSession(char* error, int error_capacity);
		int RealmsRuntime_AttachBinaryChannel(uint32_t channel_id, const char* peer_id, int is_host,
			char* error, int error_capacity);
		int RealmsRuntime_DetachBinaryChannel(uint32_t channel_id, char* error, int error_capacity);
		int RealmsRuntime_SendBinary(uint32_t channel_id, const char* sender_peer_id,
			const char* recipient_peer_id, uint32_t message_type, int reliable, const void* payload,
			uint32_t payload_size, uint32_t lifetime_ms, uint32_t* message_id, char* error, int error_capacity);
		int RealmsRuntime_UpdateBinary(uint32_t* failed_channel, char* error, int error_capacity);
		int RealmsRuntime_PollBinary(uint32_t control_channel, uint32_t message_id, RealmsBinaryMessage* message, void* payload, uint32_t capacity,
			char* error, int error_capacity);
		int RealmsRuntime_BinaryStats(uint32_t channel_id, RealmsBinaryStats* stats, char* error, int error_capacity);

		typedef struct { int unused; } RealmsRuntime_CDEF;
	]])
end
