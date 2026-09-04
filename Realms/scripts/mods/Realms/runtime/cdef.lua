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

		int RealmsRuntime_Initialize(char* error, int error_capacity);
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

		typedef struct { int unused; } RealmsRuntime_CDEF;
	]])
end
