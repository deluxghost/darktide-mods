#include "ffmpeg_internal.h"

void sa_filter_graph_free(SA_FilterGraph* filter_graph) {
	if (filter_graph == NULL) {
		return;
	}

	if (filter_graph->pending_samples != NULL) {
		free(filter_graph->pending_samples);
	}
	if (filter_graph->frame != NULL) {
		sa_ffmpeg.av_frame_free(&filter_graph->frame);
	}
	if (filter_graph->graph != NULL) {
		sa_ffmpeg.avfilter_graph_free(&filter_graph->graph);
	}

	free(filter_graph);
}

static int sa_filter_copy_pending(SA_FilterGraph* filter_graph, int16_t* out, int max_frames, int* written) {
	if (filter_graph->pending_samples == NULL || filter_graph->pending_frames <= 0) {
		return 1;
	}

	int remaining = filter_graph->pending_frames - filter_graph->pending_offset;
	int capacity = max_frames - *written;
	int to_copy = remaining < capacity ? remaining : capacity;
	int channels = filter_graph->output_channels;

	if (to_copy > 0) {
		memcpy(
			out + (*written * channels),
			filter_graph->pending_samples + (filter_graph->pending_offset * channels),
			(size_t)to_copy * channels * SA_BYTES_PER_SAMPLE
		);
		filter_graph->pending_offset += to_copy;
		*written += to_copy;
	}

	if (filter_graph->pending_offset >= filter_graph->pending_frames) {
		free(filter_graph->pending_samples);
		filter_graph->pending_samples = NULL;
		filter_graph->pending_frames = 0;
		filter_graph->pending_offset = 0;
	}

	return 1;
}

static int sa_filter_store_pending(SA_FilterGraph* filter_graph, const int16_t* samples, int frames, char* error, int error_size) {
	if (frames <= 0) {
		return 1;
	}

	size_t byte_count = (size_t)frames * filter_graph->output_channels * SA_BYTES_PER_SAMPLE;
	filter_graph->pending_samples = (int16_t*)malloc(byte_count);
	if (filter_graph->pending_samples == NULL) {
		sa_set_error(error, error_size, "Failed to allocate filter output buffer");
		return 0;
	}

	memcpy(filter_graph->pending_samples, samples, byte_count);
	filter_graph->pending_frames = frames;
	filter_graph->pending_offset = 0;

	return 1;
}

static int sa_filter_copy_frame(SA_FilterGraph* filter_graph, int16_t* out, int max_frames, int* written, char* error, int error_size) {
	SA_AVFrame* frame = filter_graph->frame;
	if (frame->nb_samples <= 0) {
		return 1;
	}
	if (frame->format != SA_AV_SAMPLE_FMT_S16) {
		sa_set_error(error, error_size, "Audio filter output format is not s16");
		return 0;
	}
	if (frame->extended_data == NULL || frame->extended_data[0] == NULL) {
		sa_set_error(error, error_size, "Audio filter returned an empty output buffer");
		return 0;
	}

	const int16_t* samples = (const int16_t*)frame->extended_data[0];
	int capacity = max_frames - *written;
	int to_copy = frame->nb_samples < capacity ? frame->nb_samples : capacity;

	if (to_copy > 0) {
		memcpy(
			out + (*written * filter_graph->output_channels),
			samples,
			(size_t)to_copy * filter_graph->output_channels * SA_BYTES_PER_SAMPLE
		);
		*written += to_copy;
	}

	if (to_copy < frame->nb_samples) {
		const int16_t* remaining = samples + (to_copy * filter_graph->output_channels);
		return sa_filter_store_pending(filter_graph, remaining, frame->nb_samples - to_copy, error, error_size);
	}

	return 1;
}

int sa_filter_drain(SA_FilterGraph* filter_graph, int16_t* out, int max_frames, int* written, char* error, int error_size) {
	while (*written < max_frames) {
		if (!sa_filter_copy_pending(filter_graph, out, max_frames, written)) {
			return 0;
		}
		if (*written >= max_frames || filter_graph->finished) {
			return 1;
		}

		int result = sa_ffmpeg.av_buffersink_get_frame(filter_graph->buffer_sink, filter_graph->frame);
		if (result == SA_AVERROR_EAGAIN) {
			return 1;
		}
		if (result == SA_AVERROR_EOF) {
			filter_graph->finished = 1;
			return 1;
		}
		if (result < 0) {
			sa_set_error(error, error_size, sa_ffmpeg_error(result));
			return 0;
		}

		int ok = sa_filter_copy_frame(filter_graph, out, max_frames, written, error, error_size);
		sa_ffmpeg.av_frame_unref(filter_graph->frame);

		if (!ok) {
			return 0;
		}
	}

	return 1;
}

int sa_filter_flush(SA_FilterGraph* filter_graph, int16_t* out, int max_frames, int* written, char* error, int error_size) {
	if (!filter_graph->sent_eof) {
		int result = sa_ffmpeg.av_buffersrc_add_frame_flags(filter_graph->buffer_source, NULL, 0);
		if (result < 0) {
			sa_set_error(error, error_size, sa_ffmpeg_error(result));
			return 0;
		}

		filter_graph->sent_eof = 1;
	}

	return sa_filter_drain(filter_graph, out, max_frames, written, error, error_size);
}

int sa_filter_graph_create(SA_Decoder* decoder, int input_sample_format, char* error, int error_size) {
	if (!sa_ffmpeg_initialize(error, error_size)) {
		return 0;
	}

	const char* sample_format_name = sa_ffmpeg.av_get_sample_fmt_name(input_sample_format);
	if (sample_format_name == NULL) {
		sa_set_error(error, error_size, "Unknown audio filter input sample format");
		return 0;
	}

	char channel_layout[128];
	int layout_result = sa_ffmpeg.av_channel_layout_describe(&decoder->codec_parameters->ch_layout, channel_layout, sizeof(channel_layout));
	if (layout_result < 0) {
		sa_set_error(error, error_size, sa_ffmpeg_error(layout_result));
		return 0;
	}

	char buffer_source_args[512];
	int buffer_source_args_written = snprintf(
		buffer_source_args,
		sizeof(buffer_source_args),
		"time_base=1/%d:sample_rate=%d:sample_fmt=%s:channel_layout=%s",
		decoder->codec_parameters->sample_rate,
		decoder->codec_parameters->sample_rate,
		sample_format_name,
		channel_layout
	);
	if (buffer_source_args_written <= 0 || buffer_source_args_written >= (int)sizeof(buffer_source_args)) {
		sa_set_error(error, error_size, "Audio filter buffer source arguments are too long");
		return 0;
	}

	const char* output_channel_layout = decoder->output_channels == 1 ? "mono" : "stereo";
	const char* output_filter_template = ",aformat=sample_fmts=s16:sample_rates=%d:channel_layouts=%s";
	size_t graph_description_length = strlen(decoder->filter_description) + strlen(output_filter_template) + strlen(output_channel_layout) + 32;
	char* graph_description = (char*)malloc(graph_description_length);
	if (graph_description == NULL) {
		sa_set_error(error, error_size, "Failed to allocate audio filter description");
		return 0;
	}

	int graph_description_written = snprintf(graph_description, graph_description_length, "%s,aformat=sample_fmts=s16:sample_rates=%d:channel_layouts=%s", decoder->filter_description, decoder->codec_parameters->sample_rate, output_channel_layout);
	if (graph_description_written <= 0 || graph_description_written >= (int)graph_description_length) {
		free(graph_description);
		sa_set_error(error, error_size, "Audio filter description is too long");
		return 0;
	}

	SA_FilterGraph* filter_graph = (SA_FilterGraph*)calloc(1, sizeof(SA_FilterGraph));
	if (filter_graph == NULL) {
		free(graph_description);
		sa_set_error(error, error_size, "Failed to allocate audio filter graph state");
		return 0;
	}

	filter_graph->output_channels = decoder->output_channels;
	const SA_AVFilter* buffer_source_filter = sa_ffmpeg.avfilter_get_by_name("abuffer");
	const SA_AVFilter* buffer_sink_filter = sa_ffmpeg.avfilter_get_by_name("abuffersink");
	if (buffer_source_filter == NULL || buffer_sink_filter == NULL) {
		free(graph_description);
		sa_filter_graph_free(filter_graph);
		sa_set_error(error, error_size, "Required audio filter endpoints are unavailable");
		return 0;
	}

	filter_graph->graph = sa_ffmpeg.avfilter_graph_alloc();
	filter_graph->frame = sa_ffmpeg.av_frame_alloc();
	if (filter_graph->graph == NULL || filter_graph->frame == NULL) {
		free(graph_description);
		sa_filter_graph_free(filter_graph);
		sa_set_error(error, error_size, "Failed to allocate audio filter graph");
		return 0;
	}

	int result = sa_ffmpeg.avfilter_graph_create_filter(&filter_graph->buffer_source, buffer_source_filter, "in", buffer_source_args, NULL, filter_graph->graph);
	if (result < 0) {
		free(graph_description);
		sa_filter_graph_free(filter_graph);
		sa_set_error(error, error_size, sa_ffmpeg_error(result));
		return 0;
	}

	result = sa_ffmpeg.avfilter_graph_create_filter(&filter_graph->buffer_sink, buffer_sink_filter, "out", NULL, NULL, filter_graph->graph);
	if (result < 0) {
		free(graph_description);
		sa_filter_graph_free(filter_graph);
		sa_set_error(error, error_size, sa_ffmpeg_error(result));
		return 0;
	}

	SA_AVFilterInOut* inputs = sa_ffmpeg.avfilter_inout_alloc();
	SA_AVFilterInOut* outputs = sa_ffmpeg.avfilter_inout_alloc();
	if (inputs == NULL || outputs == NULL) {
		free(graph_description);
		if (inputs != NULL) {
			sa_ffmpeg.avfilter_inout_free(&inputs);
		}
		if (outputs != NULL) {
			sa_ffmpeg.avfilter_inout_free(&outputs);
		}
		sa_filter_graph_free(filter_graph);
		sa_set_error(error, error_size, "Failed to allocate audio filter endpoints");
		return 0;
	}

	outputs->name = sa_ffmpeg.av_strdup("in");
	outputs->filter_ctx = filter_graph->buffer_source;
	outputs->pad_idx = 0;
	outputs->next = NULL;

	inputs->name = sa_ffmpeg.av_strdup("out");
	inputs->filter_ctx = filter_graph->buffer_sink;
	inputs->pad_idx = 0;
	inputs->next = NULL;

	if (inputs->name == NULL || outputs->name == NULL) {
		free(graph_description);
		sa_ffmpeg.avfilter_inout_free(&inputs);
		sa_ffmpeg.avfilter_inout_free(&outputs);
		sa_filter_graph_free(filter_graph);
		sa_set_error(error, error_size, "Failed to allocate audio filter endpoint names");
		return 0;
	}

	result = sa_ffmpeg.avfilter_graph_parse_ptr(filter_graph->graph, graph_description, &inputs, &outputs, NULL);
	free(graph_description);
	if (result < 0) {
		sa_ffmpeg.avfilter_inout_free(&inputs);
		sa_ffmpeg.avfilter_inout_free(&outputs);
		sa_filter_graph_free(filter_graph);
		sa_set_error(error, error_size, sa_ffmpeg_error(result));
		return 0;
	}

	result = sa_ffmpeg.avfilter_graph_config(filter_graph->graph, NULL);
	sa_ffmpeg.avfilter_inout_free(&inputs);
	sa_ffmpeg.avfilter_inout_free(&outputs);
	if (result < 0) {
		sa_filter_graph_free(filter_graph);
		sa_set_error(error, error_size, sa_ffmpeg_error(result));
		return 0;
	}

	decoder->filter_graph = filter_graph;
	return 1;
}
