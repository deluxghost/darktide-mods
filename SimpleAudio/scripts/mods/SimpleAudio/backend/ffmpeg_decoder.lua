local mod = get_mod("SimpleAudio")
local ffi = Mods.lua.ffi

local filesystem = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/filesystem")
local paths = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/paths")
local windows = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/windows")

local decoder = {}

local FFMPEG_BIN_PATH = "../mods/SimpleAudio/bin"
local OUTPUT_CHANNELS = 2
local OUTPUT_SAMPLE_RATE = 48000
local OUTPUT_BYTES_PER_FRAME = OUTPUT_CHANNELS * 2
local CACHE_DIR_NAME = "SimpleAudio"
local AVMEDIA_TYPE_AUDIO = 1
local AV_SAMPLE_FMT_S16 = 1
local AV_LOG_QUIET = -8
local AVERROR_EOF = -541478725
local AVERROR_EAGAIN = -11

local instances = mod:persistent_table("instances")
instances.simple_audio_decoder = instances.simple_audio_decoder or {}

local state = instances.simple_audio_decoder
state.cache = state.cache or {}

if not pcall(ffi.typeof, "SimpleAudio_AVFrame") then
	ffi.cdef([[
		typedef signed long long SimpleAudio_int64_t;
		typedef unsigned char SimpleAudio_uint8_t;
		typedef unsigned int SimpleAudio_uint32_t;
		typedef unsigned long long SimpleAudio_uint64_t;
		typedef unsigned long long SimpleAudio_size_t;

		typedef struct SimpleAudio_AVPacketSideData SimpleAudio_AVPacketSideData;
		typedef struct SimpleAudio_AVBufferRef SimpleAudio_AVBufferRef;
		typedef struct SimpleAudio_AVCodec SimpleAudio_AVCodec;
		typedef struct SimpleAudio_AVCodecContext SimpleAudio_AVCodecContext;
		typedef struct SimpleAudio_AVDictionary SimpleAudio_AVDictionary;
		typedef struct SimpleAudio_AVInputFormat SimpleAudio_AVInputFormat;
		typedef struct SimpleAudio_AVIOContext SimpleAudio_AVIOContext;
		typedef struct SimpleAudio_SwrContext SimpleAudio_SwrContext;

		typedef struct {
			int num;
			int den;
		} SimpleAudio_AVRational;

		typedef struct {
			int order;
			int nb_channels;
			union {
				SimpleAudio_uint64_t mask;
				void* map;
			} u;
			void* opaque;
		} SimpleAudio_AVChannelLayout;

		typedef struct {
			int codec_type;
			int codec_id;
			SimpleAudio_uint32_t codec_tag;
			SimpleAudio_uint8_t* extradata;
			int extradata_size;
			SimpleAudio_AVPacketSideData* coded_side_data;
			int nb_coded_side_data;
			int format;
			SimpleAudio_int64_t bit_rate;
			int bits_per_coded_sample;
			int bits_per_raw_sample;
			int profile;
			int level;
			int width;
			int height;
			SimpleAudio_AVRational sample_aspect_ratio;
			SimpleAudio_AVRational framerate;
			int field_order;
			int color_range;
			int color_primaries;
			int color_trc;
			int color_space;
			int chroma_location;
			int video_delay;
			SimpleAudio_AVChannelLayout ch_layout;
			int sample_rate;
		} SimpleAudio_AVCodecParameters;

		typedef struct {
			const void* av_class;
			int index;
			int id;
			SimpleAudio_AVCodecParameters* codecpar;
			void* priv_data;
			SimpleAudio_AVRational time_base;
		} SimpleAudio_AVStream;

		typedef struct {
			const void* av_class;
			const SimpleAudio_AVInputFormat* iformat;
			const void* oformat;
			void* priv_data;
			SimpleAudio_AVIOContext* pb;
			int ctx_flags;
			unsigned int nb_streams;
			SimpleAudio_AVStream** streams;
		} SimpleAudio_AVFormatContext;

		typedef struct {
			SimpleAudio_uint8_t* data[8];
			int linesize[8];
			SimpleAudio_uint8_t** extended_data;
			int width;
			int height;
			int nb_samples;
			int format;
		} SimpleAudio_AVFrame;

		typedef struct {
			SimpleAudio_AVBufferRef* buf;
			SimpleAudio_int64_t pts;
			SimpleAudio_int64_t dts;
			SimpleAudio_uint8_t* data;
			int size;
			int stream_index;
			int flags;
			SimpleAudio_AVPacketSideData* side_data;
			int side_data_elems;
			SimpleAudio_int64_t duration;
			SimpleAudio_int64_t pos;
			void* opaque;
			SimpleAudio_AVBufferRef* opaque_ref;
			SimpleAudio_AVRational time_base;
		} SimpleAudio_AVPacket;

		void av_log_set_level(int level);
		int av_strerror(int errnum, char* errbuf, SimpleAudio_size_t errbuf_size);
		void av_channel_layout_default(SimpleAudio_AVChannelLayout* ch_layout, int nb_channels);

		int avformat_open_input(SimpleAudio_AVFormatContext** ps, const char* url, const SimpleAudio_AVInputFormat* fmt, SimpleAudio_AVDictionary** options);
		int avformat_find_stream_info(SimpleAudio_AVFormatContext* ic, SimpleAudio_AVDictionary** options);
		int av_find_best_stream(SimpleAudio_AVFormatContext* ic, int type, int wanted_stream_nb, int related_stream, const SimpleAudio_AVCodec** decoder_ret, int flags);
		int av_read_frame(SimpleAudio_AVFormatContext* s, SimpleAudio_AVPacket* pkt);
		void avformat_close_input(SimpleAudio_AVFormatContext** s);

		SimpleAudio_AVCodecContext* avcodec_alloc_context3(const SimpleAudio_AVCodec* codec);
		int avcodec_parameters_to_context(SimpleAudio_AVCodecContext* codec, const SimpleAudio_AVCodecParameters* par);
		int avcodec_open2(SimpleAudio_AVCodecContext* avctx, const SimpleAudio_AVCodec* codec, SimpleAudio_AVDictionary** options);
		int avcodec_send_packet(SimpleAudio_AVCodecContext* avctx, const SimpleAudio_AVPacket* avpkt);
		int avcodec_receive_frame(SimpleAudio_AVCodecContext* avctx, SimpleAudio_AVFrame* frame);
		void avcodec_free_context(SimpleAudio_AVCodecContext** avctx);
		SimpleAudio_AVPacket* av_packet_alloc(void);
		void av_packet_free(SimpleAudio_AVPacket** pkt);
		void av_packet_unref(SimpleAudio_AVPacket* pkt);

		SimpleAudio_AVFrame* av_frame_alloc(void);
		void av_frame_free(SimpleAudio_AVFrame** frame);
		void av_frame_unref(SimpleAudio_AVFrame* frame);

		int swr_alloc_set_opts2(SimpleAudio_SwrContext** ps, const SimpleAudio_AVChannelLayout* out_ch_layout, int out_sample_fmt, int out_sample_rate, const SimpleAudio_AVChannelLayout* in_ch_layout, int in_sample_fmt, int in_sample_rate, int log_offset, void* log_ctx);
		int swr_init(SimpleAudio_SwrContext* s);
		int swr_get_out_samples(SimpleAudio_SwrContext* s, int in_samples);
		int swr_convert(SimpleAudio_SwrContext* s, SimpleAudio_uint8_t** out, int out_count, const SimpleAudio_uint8_t** in, int in_count);
		void swr_free(SimpleAudio_SwrContext** s);
	]])
end

local function ffmpeg_error(code)
	local buffer = ffi.new("char[256]")

	if state.avutil and state.avutil.av_strerror(code, buffer, ffi.sizeof(buffer)) == 0 then
		return ffi.string(buffer)
	end

	return string.format("FFmpeg error %d", tonumber(code))
end

local function find_library(pattern)
	local search_pattern = paths.join_audio_path(FFMPEG_BIN_PATH, pattern)
	local matches = filesystem.find_files(search_pattern, FFMPEG_BIN_PATH .. "/")

	if not matches or #matches == 0 then
		return nil
	end

	return matches[#matches]
end

local function load_library(field, pattern)
	if state[field] then
		return state[field]
	end

	local dll_path = find_library(pattern)

	if not dll_path then
		error(string.format("Missing FFmpeg DLL %s under %s", pattern, FFMPEG_BIN_PATH))
	end

	local library = ffi.load(windows.path(dll_path))
	state[field] = library

	return library
end

local function ensure_libraries()
	if state.ready then
		return
	end

	state.avutil = load_library("avutil", "avutil-60.dll")
	state.swresample = load_library("swresample", "swresample-6.dll")
	state.avcodec = load_library("avcodec", "avcodec-62.dll")
	state.avformat = load_library("avformat", "avformat-62.dll")
	state.avutil.av_log_set_level(AV_LOG_QUIET)
	state.ready = true
end

local function hash_path(path)
	local hash = 5381

	for i = 1, #path do
		hash = (hash * 33 + path:byte(i)) % 4294967296
	end

	return string.format("%08x", hash)
end

local function cache_directory()
	if not state.cache_directory then
		state.cache_directory = paths.join_audio_path(filesystem.temp_path(), CACHE_DIR_NAME)
	end

	filesystem.ensure_directory(state.cache_directory)

	return state.cache_directory
end

local function cache_path(path)
	return paths.join_audio_path(cache_directory(), hash_path(path) .. ".pcm")
end

local function stream_codec_parameters(format_context, stream_index)
	local stream = format_context[0].streams[stream_index]

	if stream == nil or stream.codecpar == nil then
		return nil, "Audio stream has no codec parameters"
	end

	return stream.codecpar
end

local function create_resampler(codec_parameters, sample_format)
	local in_layout = codec_parameters.ch_layout

	if in_layout.nb_channels <= 0 then
		return nil, "Audio stream has no channel layout"
	end

	local out_layout = ffi.new("SimpleAudio_AVChannelLayout[1]")
	state.avutil.av_channel_layout_default(out_layout, OUTPUT_CHANNELS)

	local in_layout_buffer = ffi.new("SimpleAudio_AVChannelLayout[1]")
	in_layout_buffer[0] = in_layout

	local resampler = ffi.new("SimpleAudio_SwrContext*[1]")
	local result = state.swresample.swr_alloc_set_opts2(
		resampler,
		out_layout,
		AV_SAMPLE_FMT_S16,
		OUTPUT_SAMPLE_RATE,
		in_layout_buffer,
		sample_format,
		codec_parameters.sample_rate,
		0,
		nil
	)

	if result < 0 then
		return nil, ffmpeg_error(result)
	end

	result = state.swresample.swr_init(resampler[0])

	if result < 0 then
		state.swresample.swr_free(resampler)

		return nil, ffmpeg_error(result)
	end

	return resampler
end

local function close_decode_state(decode_state)
	if decode_state.resampler then
		state.swresample.swr_free(decode_state.resampler)
	end
	if decode_state.frame then
		local frame = ffi.new("SimpleAudio_AVFrame*[1]", decode_state.frame)
		state.avutil.av_frame_free(frame)
	end
	if decode_state.packet then
		local packet = ffi.new("SimpleAudio_AVPacket*[1]", decode_state.packet)
		state.avcodec.av_packet_free(packet)
	end
	if decode_state.codec_context then
		state.avcodec.avcodec_free_context(decode_state.codec_context)
	end
	if decode_state.format_context then
		state.avformat.avformat_close_input(decode_state.format_context)
	end
end

local function write_resampled_frame(decode_state)
	local frame = decode_state.frame

	if frame.nb_samples <= 0 then
		return
	end

	if not decode_state.resampler then
		local resampler, error_message = create_resampler(decode_state.codec_parameters, frame.format)

		if not resampler then
			error(error_message)
		end

		decode_state.resampler = resampler
	end

	local out_samples = state.swresample.swr_get_out_samples(decode_state.resampler[0], frame.nb_samples)

	if out_samples <= 0 then
		return
	end

	local out_buffer = ffi.new("SimpleAudio_uint8_t[?]", out_samples * OUTPUT_BYTES_PER_FRAME)
	local out_data = ffi.new("SimpleAudio_uint8_t*[1]")
	out_data[0] = out_buffer

	local converted_samples = state.swresample.swr_convert(
		decode_state.resampler[0],
		out_data,
		out_samples,
		ffi.cast("const SimpleAudio_uint8_t**", frame.extended_data),
		frame.nb_samples
	)

	if converted_samples < 0 then
		error(ffmpeg_error(converted_samples))
	end

	local byte_count = converted_samples * OUTPUT_BYTES_PER_FRAME

	if byte_count > 0 then
		filesystem.write(decode_state.output_handle, out_buffer, byte_count)
		decode_state.total_bytes = decode_state.total_bytes + byte_count
	end
end

local function flush_resampler(decode_state)
	if not decode_state.resampler then
		return
	end

	while true do
		local out_samples = state.swresample.swr_get_out_samples(decode_state.resampler[0], 0)

		if out_samples <= 0 then
			break
		end

		local out_buffer = ffi.new("SimpleAudio_uint8_t[?]", out_samples * OUTPUT_BYTES_PER_FRAME)
		local out_data = ffi.new("SimpleAudio_uint8_t*[1]")
		out_data[0] = out_buffer

		local converted_samples = state.swresample.swr_convert(decode_state.resampler[0], out_data, out_samples, nil, 0)

		if converted_samples < 0 then
			error(ffmpeg_error(converted_samples))
		end

		if converted_samples == 0 then
			break
		end

		local byte_count = converted_samples * OUTPUT_BYTES_PER_FRAME
		filesystem.write(decode_state.output_handle, out_buffer, byte_count)
		decode_state.total_bytes = decode_state.total_bytes + byte_count
	end
end

local function drain_decoder(decode_state)
	while true do
		local result = state.avcodec.avcodec_receive_frame(decode_state.codec_context[0], decode_state.frame)

		if result == AVERROR_EAGAIN or result == AVERROR_EOF then
			break
		end
		if result < 0 then
			error(ffmpeg_error(result))
		end

		write_resampled_frame(decode_state)
		state.avutil.av_frame_unref(decode_state.frame)
	end
end

local function send_decode_packet(decode_state, packet)
	while true do
		local result = state.avcodec.avcodec_send_packet(decode_state.codec_context[0], packet)

		if result == AVERROR_EAGAIN then
			drain_decoder(decode_state)
		elseif result < 0 and result ~= AVERROR_EOF then
			error(ffmpeg_error(result))
		else
			break
		end
	end

	drain_decoder(decode_state)
end

local function open_decode_state(path)
	local format_context = ffi.new("SimpleAudio_AVFormatContext*[1]")
	local result = state.avformat.avformat_open_input(format_context, windows.path(path), nil, nil)

	if result < 0 then
		return nil, ffmpeg_error(result)
	end

	result = state.avformat.avformat_find_stream_info(format_context[0], nil)

	if result < 0 then
		state.avformat.avformat_close_input(format_context)

		return nil, ffmpeg_error(result)
	end

	local codec = ffi.new("const SimpleAudio_AVCodec*[1]")
	local stream_index = state.avformat.av_find_best_stream(format_context[0], AVMEDIA_TYPE_AUDIO, -1, -1, codec, 0)

	if stream_index < 0 then
		state.avformat.avformat_close_input(format_context)

		return nil, ffmpeg_error(stream_index)
	end

	local codec_parameters, codec_parameters_error = stream_codec_parameters(format_context, stream_index)

	if not codec_parameters then
		state.avformat.avformat_close_input(format_context)

		return nil, codec_parameters_error
	end

	if codec_parameters.sample_rate <= 0 then
		state.avformat.avformat_close_input(format_context)

		return nil, "Audio stream has no sample rate"
	end

	local codec_context = ffi.new("SimpleAudio_AVCodecContext*[1]")
	codec_context[0] = state.avcodec.avcodec_alloc_context3(codec[0])

	if codec_context[0] == nil then
		state.avformat.avformat_close_input(format_context)

		return nil, "Failed to allocate FFmpeg codec context"
	end

	result = state.avcodec.avcodec_parameters_to_context(codec_context[0], codec_parameters)

	if result < 0 then
		state.avcodec.avcodec_free_context(codec_context)
		state.avformat.avformat_close_input(format_context)

		return nil, ffmpeg_error(result)
	end

	result = state.avcodec.avcodec_open2(codec_context[0], codec[0], nil)

	if result < 0 then
		state.avcodec.avcodec_free_context(codec_context)
		state.avformat.avformat_close_input(format_context)

		return nil, ffmpeg_error(result)
	end

	local packet = state.avcodec.av_packet_alloc()
	local frame = state.avutil.av_frame_alloc()

	if packet == nil or frame == nil then
		local decode_state = {
			codec_context = codec_context,
			format_context = format_context,
			frame = frame,
			packet = packet,
		}

		close_decode_state(decode_state)

		return nil, "Failed to allocate FFmpeg decode buffers"
	end

	return {
		codec_context = codec_context,
		codec_parameters = codec_parameters[0],
		format_context = format_context,
		frame = frame,
		packet = packet,
		stream_index = stream_index,
	}
end

local function decode_file(path)
	ensure_libraries()

	local decode_state, open_error = open_decode_state(path)

	if not decode_state then
		return nil, open_error
	end

	local output_path = cache_path(path)
	local output_handle
	local ok, decode_error = pcall(function()
		output_handle = filesystem.open_write(output_path)
		decode_state.output_handle = output_handle
		decode_state.total_bytes = 0

		while true do
			local result = state.avformat.av_read_frame(decode_state.format_context[0], decode_state.packet)

			if result == AVERROR_EOF then
				break
			end
			if result < 0 then
				error(ffmpeg_error(result))
			end

			if decode_state.packet.stream_index == decode_state.stream_index then
				send_decode_packet(decode_state, decode_state.packet)
			end

			state.avcodec.av_packet_unref(decode_state.packet)
		end

		send_decode_packet(decode_state, nil)
		flush_resampler(decode_state)
	end)

	if output_handle then
		filesystem.close(output_handle)
	end

	close_decode_state(decode_state)

	if not ok then
		filesystem.delete(output_path)

		return nil, tostring(decode_error)
	end
	if decode_state.total_bytes == 0 then
		filesystem.delete(output_path)

		return nil, "Decoded audio is empty"
	end

	return {
		frame_count = decode_state.total_bytes / OUTPUT_BYTES_PER_FRAME,
		pcm_path = output_path,
	}
end

decoder.decode = function(path)
	local cached = state.cache[path]

	if cached then
		return cached
	end

	local ok, source, error_message = pcall(decode_file, path)

	if not ok then
		return nil, tostring(source)
	end

	if not source then
		return nil, error_message
	end

	state.cache[path] = source

	return source
end

decoder.preload = function(path)
	local source, error_message = decoder.decode(path)

	if not source then
		error(string.format("Failed to preload audio file %s: %s", path, error_message))
	end
end

decoder.shutdown = function()
	for _, source in pairs(state.cache) do
		if source.pcm_path then
			filesystem.delete(source.pcm_path)
		end
	end

	state.cache = {}
end

return decoder
