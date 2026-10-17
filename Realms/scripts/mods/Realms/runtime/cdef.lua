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

		typedef struct RealmsVoiceConfig {
			uint32_t struct_size;
			uint32_t frame_ms;
			uint32_t bitrate;
			uint32_t device_period_ms;
			uint32_t playback_device_id;
			uint32_t echo_cancellation;
			uint32_t noise_suppression;
		} RealmsVoiceConfig;

		typedef struct RealmsVoicePacket {
			uint32_t struct_size;
			uint32_t sequence;
			uint32_t payload_size;
			uint32_t age_ms;
			uint32_t speaking;
			uint32_t stream;
		} RealmsVoicePacket;

		typedef struct RealmsVoiceStats {
			uint32_t struct_size;
			uint32_t capture_enabled;
			uint32_t maximum_packet_bytes;
			uint32_t codec_lookahead_frames;
			uint32_t capture_pending_frames;
			uint32_t playback_pending_frames;
			uint32_t capture_device_buffer_us;
			uint32_t playback_device_buffer_us;
			uint64_t encoded_frames;
			uint64_t encoded_bytes;
			uint64_t decoded_frames;
			uint64_t expired_packets;
			uint64_t dropped_packets;
			uint64_t dropped_capture_frames;
			uint64_t dropped_playback_frames;
			uint64_t playback_underrun_frames;
			uint64_t encode_time_us;
			uint64_t maximum_encode_time_us;
			uint64_t decode_time_us;
			uint64_t maximum_decode_time_us;
			uint32_t echo_cancellation;
			uint32_t noise_suppression;
			uint32_t reference_enabled;
			uint64_t processed_frames;
			uint64_t processing_time_us;
			uint64_t maximum_processing_time_us;
			uint64_t dropped_reference_frames;
		} RealmsVoiceStats;

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
		int RealmsRuntime_StartVoice(const RealmsVoiceConfig* config, char* error, int error_capacity);
		int RealmsRuntime_StopVoice(char* error, int error_capacity);
		int RealmsRuntime_UpdateVoice(char* error, int error_capacity);
		int RealmsRuntime_SetVoiceVolume(float volume, char* error, int error_capacity);
		int RealmsRuntime_SetVoiceCapture(int enabled, const char* device_id, char* error, int error_capacity);
		int RealmsRuntime_SetVoiceTransmission(int enabled, char* error, int error_capacity);
		int RealmsRuntime_SetVoiceProcessing(int echo_cancellation, int noise_suppression, char* error, int error_capacity);
		int RealmsRuntime_SetVoicePlaybackDevice(uint32_t device_id, char* error, int error_capacity);
		int RealmsRuntime_PollVoicePacket(RealmsVoicePacket* packet, void* payload, uint32_t capacity,
			char* error, int error_capacity);
		int RealmsRuntime_SubmitVoicePacket(uint32_t speaker_id, const void* payload, uint32_t size,
			char* error, int error_capacity);
		int RealmsRuntime_RemoveVoiceSpeaker(uint32_t speaker_id, char* error, int error_capacity);
		int RealmsRuntime_VoiceStats(RealmsVoiceStats* stats, char* error, int error_capacity);

		typedef struct { int unused; } RealmsRuntime_CDEF;
	]])
end
