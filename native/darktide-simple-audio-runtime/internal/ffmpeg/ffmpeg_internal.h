#ifndef SIMPLE_AUDIO_FFMPEG_INTERNAL_H
#define SIMPLE_AUDIO_FFMPEG_INTERNAL_H

#include "ffmpeg.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <wchar.h>

#define SA_BYTES_PER_SAMPLE 2
#define SA_AVMEDIA_TYPE_AUDIO 1
#define SA_AV_SAMPLE_FMT_S16 1
#define SA_AV_CHANNEL_ORDER_UNSPEC 0
#define SA_AV_LOG_QUIET -8
#define SA_AV_NOPTS_VALUE ((int64_t)0x8000000000000000ULL)
#define SA_AVERROR_EOF -541478725
#define SA_AVERROR_EAGAIN -11
#define SA_AV_BUFFERSRC_FLAG_KEEP_REF 8

typedef struct SA_AVPacketSideData SA_AVPacketSideData;
typedef struct SA_AVBufferRef SA_AVBufferRef;
typedef struct SA_AVCodec SA_AVCodec;
typedef struct SA_AVCodecContext SA_AVCodecContext;
typedef struct SA_AVDictionary SA_AVDictionary;
typedef struct SA_AVFilter SA_AVFilter;
typedef struct SA_AVFilterContext SA_AVFilterContext;
typedef struct SA_AVFilterGraph SA_AVFilterGraph;
typedef struct SA_AVInputFormat SA_AVInputFormat;
typedef struct SA_AVIOContext SA_AVIOContext;
typedef struct SA_SwrContext SA_SwrContext;

typedef struct {
	int (*callback)(void*);
	void* opaque;
} SA_AVIOInterruptCB;

typedef struct {
	char* key;
	char* value;
} SA_AVDictionaryEntry;

typedef struct {
	int num;
	int den;
} SA_AVRational;

typedef struct {
	int order;
	int nb_channels;
	union {
		uint64_t mask;
		void* map;
	} u;
	void* opaque;
} SA_AVChannelLayout;

typedef struct {
	int codec_type;
	int codec_id;
	uint32_t codec_tag;
	uint8_t* extradata;
	int extradata_size;
	SA_AVPacketSideData* coded_side_data;
	int nb_coded_side_data;
	int format;
	int64_t bit_rate;
	int bits_per_coded_sample;
	int bits_per_raw_sample;
	int profile;
	int level;
	int width;
	int height;
	SA_AVRational sample_aspect_ratio;
	SA_AVRational framerate;
	int field_order;
	int color_range;
	int color_primaries;
	int color_trc;
	int color_space;
	int chroma_location;
	int video_delay;
	SA_AVChannelLayout ch_layout;
	int sample_rate;
} SA_AVCodecParameters;

typedef struct {
	const void* av_class;
	int index;
	int id;
	SA_AVCodecParameters* codecpar;
	void* priv_data;
	SA_AVRational time_base;
	int64_t start_time;
	int64_t duration;
} SA_AVStream;

typedef struct {
	const void* av_class;
	const SA_AVInputFormat* iformat;
	const void* oformat;
	void* priv_data;
	SA_AVIOContext* pb;
	int ctx_flags;
	unsigned int nb_streams;
	SA_AVStream** streams;
	unsigned int nb_stream_groups;
	void* stream_groups;
	unsigned int nb_chapters;
	void* chapters;
	char* url;
	int64_t start_time;
	int64_t duration;
	int64_t bit_rate;
	unsigned int packet_size;
	int max_delay;
	int flags;
	int64_t probesize;
	int64_t max_analyze_duration;
	const uint8_t* key;
	int keylen;
	unsigned int nb_programs;
	void* programs;
	int video_codec_id;
	int audio_codec_id;
	int subtitle_codec_id;
	int data_codec_id;
	SA_AVDictionary* metadata;
	int64_t start_time_realtime;
	int fps_probe_size;
	int error_recognition;
	SA_AVIOInterruptCB interrupt_callback;
} SA_AVFormatContext;

typedef struct {
	uint8_t* data[8];
	int linesize[8];
	uint8_t** extended_data;
	int width;
	int height;
	int nb_samples;
	int format;
} SA_AVFrame;

typedef struct {
	SA_AVBufferRef* buf;
	int64_t pts;
	int64_t dts;
	uint8_t* data;
	int size;
	int stream_index;
	int flags;
	SA_AVPacketSideData* side_data;
	int side_data_elems;
	int64_t duration;
	int64_t pos;
	void* opaque;
	SA_AVBufferRef* opaque_ref;
	SA_AVRational time_base;
} SA_AVPacket;

typedef struct SA_AVFilterInOut {
	char* name;
	SA_AVFilterContext* filter_ctx;
	int pad_idx;
	struct SA_AVFilterInOut* next;
} SA_AVFilterInOut;

typedef void (*sa_av_log_set_level_fn)(int level);
typedef int (*sa_av_strerror_fn)(int errnum, char* errbuf, size_t errbuf_size);
typedef char* (*sa_av_strdup_fn)(const char* s);
typedef const SA_AVDictionaryEntry* (*sa_av_dict_iterate_fn)(const SA_AVDictionary* m, const SA_AVDictionaryEntry* prev);
typedef const char* (*sa_av_get_sample_fmt_name_fn)(int sample_fmt);
typedef int (*sa_av_get_bytes_per_sample_fn)(int sample_fmt);
typedef void (*sa_av_channel_layout_default_fn)(SA_AVChannelLayout* ch_layout, int nb_channels);
typedef int (*sa_av_channel_layout_describe_fn)(const SA_AVChannelLayout* channel_layout, char* buf, size_t buf_size);
typedef SA_AVFormatContext* (*sa_avformat_alloc_context_fn)(void);
typedef int (*sa_avformat_open_input_fn)(SA_AVFormatContext** ps, const char* url, const SA_AVInputFormat* fmt, SA_AVDictionary** options);
typedef int (*sa_avformat_find_stream_info_fn)(SA_AVFormatContext* ic, SA_AVDictionary** options);
typedef int (*sa_av_find_best_stream_fn)(SA_AVFormatContext* ic, int type, int wanted_stream_nb, int related_stream, const SA_AVCodec** decoder_ret, int flags);
typedef int (*sa_av_read_frame_fn)(SA_AVFormatContext* s, SA_AVPacket* pkt);
typedef void (*sa_avformat_close_input_fn)(SA_AVFormatContext** s);
typedef SA_AVCodecContext* (*sa_avcodec_alloc_context3_fn)(const SA_AVCodec* codec);
typedef int (*sa_avcodec_parameters_to_context_fn)(SA_AVCodecContext* codec, const SA_AVCodecParameters* par);
typedef int (*sa_avcodec_open2_fn)(SA_AVCodecContext* avctx, const SA_AVCodec* codec, SA_AVDictionary** options);
typedef int (*sa_avcodec_send_packet_fn)(SA_AVCodecContext* avctx, const SA_AVPacket* avpkt);
typedef int (*sa_avcodec_receive_frame_fn)(SA_AVCodecContext* avctx, SA_AVFrame* frame);
typedef void (*sa_avcodec_free_context_fn)(SA_AVCodecContext** avctx);
typedef SA_AVCodecParameters* (*sa_avcodec_parameters_alloc_fn)(void);
typedef int (*sa_avcodec_parameters_copy_fn)(SA_AVCodecParameters* dst, const SA_AVCodecParameters* src);
typedef void (*sa_avcodec_parameters_free_fn)(SA_AVCodecParameters** par);
typedef SA_AVPacket* (*sa_av_packet_alloc_fn)(void);
typedef void (*sa_av_packet_free_fn)(SA_AVPacket** pkt);
typedef void (*sa_av_packet_unref_fn)(SA_AVPacket* pkt);
typedef SA_AVFrame* (*sa_av_frame_alloc_fn)(void);
typedef void (*sa_av_frame_free_fn)(SA_AVFrame** frame);
typedef void (*sa_av_frame_unref_fn)(SA_AVFrame* frame);
typedef SA_AVFrame* (*sa_av_frame_clone_fn)(const SA_AVFrame* frame);
typedef int (*sa_av_samples_get_buffer_size_fn)(int* linesize, int nb_channels, int nb_samples, int sample_fmt, int align);
typedef int (*sa_swr_alloc_set_opts2_fn)(SA_SwrContext** ps, const SA_AVChannelLayout* out_ch_layout, int out_sample_fmt, int out_sample_rate, const SA_AVChannelLayout* in_ch_layout, int in_sample_fmt, int in_sample_rate, int log_offset, void* log_ctx);
typedef int (*sa_swr_init_fn)(SA_SwrContext* s);
typedef int (*sa_swr_convert_fn)(SA_SwrContext* s, uint8_t** out, int out_count, const uint8_t** in, int in_count);
typedef void (*sa_swr_free_fn)(SA_SwrContext** s);
typedef const SA_AVFilter* (*sa_avfilter_get_by_name_fn)(const char* name);
typedef SA_AVFilterGraph* (*sa_avfilter_graph_alloc_fn)(void);
typedef int (*sa_avfilter_graph_create_filter_fn)(SA_AVFilterContext** filt_ctx, const SA_AVFilter* filt, const char* name, const char* args, void* opaque, SA_AVFilterGraph* graph_ctx);
typedef int (*sa_avfilter_graph_parse_ptr_fn)(SA_AVFilterGraph* graph, const char* filters, SA_AVFilterInOut** inputs, SA_AVFilterInOut** outputs, void* log_ctx);
typedef int (*sa_avfilter_graph_config_fn)(SA_AVFilterGraph* graphctx, void* log_ctx);
typedef void (*sa_avfilter_graph_free_fn)(SA_AVFilterGraph** graph);
typedef SA_AVFilterInOut* (*sa_avfilter_inout_alloc_fn)(void);
typedef void (*sa_avfilter_inout_free_fn)(SA_AVFilterInOut** inout);
typedef int (*sa_av_buffersrc_add_frame_flags_fn)(SA_AVFilterContext* buffer_src, SA_AVFrame* frame, int flags);
typedef int (*sa_av_buffersink_get_frame_fn)(SA_AVFilterContext* ctx, SA_AVFrame* frame);

typedef struct {
	HMODULE avutil;
	HMODULE swresample;
	HMODULE swscale;
	HMODULE avcodec;
	HMODULE avformat;
	HMODULE avfilter;
	sa_av_log_set_level_fn av_log_set_level;
	sa_av_strerror_fn av_strerror;
	sa_av_strdup_fn av_strdup;
	sa_av_dict_iterate_fn av_dict_iterate;
	sa_av_get_sample_fmt_name_fn av_get_sample_fmt_name;
	sa_av_get_bytes_per_sample_fn av_get_bytes_per_sample;
	sa_av_channel_layout_default_fn av_channel_layout_default;
	sa_av_channel_layout_describe_fn av_channel_layout_describe;
	sa_avformat_alloc_context_fn avformat_alloc_context;
	sa_avformat_open_input_fn avformat_open_input;
	sa_avformat_find_stream_info_fn avformat_find_stream_info;
	sa_av_find_best_stream_fn av_find_best_stream;
	sa_av_read_frame_fn av_read_frame;
	sa_avformat_close_input_fn avformat_close_input;
	sa_avcodec_alloc_context3_fn avcodec_alloc_context3;
	sa_avcodec_parameters_to_context_fn avcodec_parameters_to_context;
	sa_avcodec_open2_fn avcodec_open2;
	sa_avcodec_send_packet_fn avcodec_send_packet;
	sa_avcodec_receive_frame_fn avcodec_receive_frame;
	sa_avcodec_free_context_fn avcodec_free_context;
	sa_avcodec_parameters_alloc_fn avcodec_parameters_alloc;
	sa_avcodec_parameters_copy_fn avcodec_parameters_copy;
	sa_avcodec_parameters_free_fn avcodec_parameters_free;
	sa_av_packet_alloc_fn av_packet_alloc;
	sa_av_packet_free_fn av_packet_free;
	sa_av_packet_unref_fn av_packet_unref;
	sa_av_frame_alloc_fn av_frame_alloc;
	sa_av_frame_free_fn av_frame_free;
	sa_av_frame_unref_fn av_frame_unref;
	sa_av_frame_clone_fn av_frame_clone;
	sa_av_samples_get_buffer_size_fn av_samples_get_buffer_size;
	sa_swr_alloc_set_opts2_fn swr_alloc_set_opts2;
	sa_swr_init_fn swr_init;
	sa_swr_convert_fn swr_convert;
	sa_swr_free_fn swr_free;
	sa_avfilter_get_by_name_fn avfilter_get_by_name;
	sa_avfilter_graph_alloc_fn avfilter_graph_alloc;
	sa_avfilter_graph_create_filter_fn avfilter_graph_create_filter;
	sa_avfilter_graph_parse_ptr_fn avfilter_graph_parse_ptr;
	sa_avfilter_graph_config_fn avfilter_graph_config;
	sa_avfilter_graph_free_fn avfilter_graph_free;
	sa_avfilter_inout_alloc_fn avfilter_inout_alloc;
	sa_avfilter_inout_free_fn avfilter_inout_free;
	sa_av_buffersrc_add_frame_flags_fn av_buffersrc_add_frame_flags;
	sa_av_buffersink_get_frame_fn av_buffersink_get_frame;
} SA_FFmpeg;

typedef struct {
	SA_AVFilterGraph* graph;
	SA_AVFilterContext* buffer_source;
	SA_AVFilterContext* buffer_sink;
	SA_AVFrame* frame;
	int sent_eof;
	int finished;
	int16_t* pending_samples;
	int pending_frames;
	int pending_offset;
	int output_channels;
} SA_FilterGraph;

struct SA_Decoder {
	SA_AVFormatContext* format_context;
	SA_AVCodecContext* codec_context;
	SA_AVCodecParameters* codec_parameters;
	SA_AVPacket* packet;
	SA_AVFrame* frame;
	SA_SwrContext* resampler;
	SA_FilterGraph* filter_graph;
	char* filter_description;
	int stream_index;
	int output_sample_rate;
	int output_channels;
	SA_CancelToken* cancel_token;
	int packet_pending;
	int input_eof;
	int sent_flush;
	int finished;
};

struct SA_RawAudio {
	SA_AVCodecParameters* codec_parameters;
	SA_AVFrame** frames;
	int frame_count;
	int frame_capacity;
	int byte_count;
};

struct SA_RawFilterDecoder {
	SA_RawAudio* audio;
	SA_Decoder filter_state;
	SA_CancelToken* cancel_token;
	int frame_index;
	int finished;
};

struct SA_CancelToken {
	volatile LONG cancelled;
};

extern SA_FFmpeg sa_ffmpeg;

void sa_set_error(char* buffer, int buffer_size, const char* message);
char* sa_duplicate_string(const char* value);
const char* sa_ffmpeg_error(int code);

void sa_filter_graph_free(SA_FilterGraph* filter_graph);
int sa_filter_drain(SA_FilterGraph* filter_graph, int16_t* out, int max_frames, int* written, char* error, int error_size);
int sa_filter_flush(SA_FilterGraph* filter_graph, int16_t* out, int max_frames, int* written, char* error, int error_size);
int sa_filter_graph_create(SA_Decoder* decoder, int input_sample_format, char* error, int error_size);
int sa_decoder_next_frame(SA_Decoder* decoder, int* finished, char* error, int error_size);
int sa_cancel_token_is_cancelled(SA_CancelToken* token);

#endif
