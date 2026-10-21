#include "ffmpeg_internal.h"

#define SA_RAW_FRAME_OVERHEAD 512

static int sa_raw_audio_append_frame(SA_RawAudio* audio, const SA_AVFrame* frame, int max_bytes, int* too_large, char* error, int error_size) {
	int channels = audio->codec_parameters->ch_layout.nb_channels;
	int byte_count = sa_ffmpeg.av_samples_get_buffer_size(NULL, channels, frame->nb_samples, frame->format, 1);
	if (byte_count < 0) {
		sa_set_error(error, error_size, sa_ffmpeg_error(byte_count));
		return 0;
	}
	int accounted_bytes = byte_count + SA_RAW_FRAME_OVERHEAD;
	if (audio->byte_count > max_bytes - accounted_bytes) {
		*too_large = 1;
		return 0;
	}

	if (audio->frame_count == audio->frame_capacity) {
		int capacity = audio->frame_capacity == 0 ? 16 : audio->frame_capacity * 2;
		SA_AVFrame** frames = (SA_AVFrame**)realloc(audio->frames, (size_t)capacity * sizeof(SA_AVFrame*));
		if (frames == NULL) {
			sa_set_error(error, error_size, "Failed to grow raw frame cache");
			return 0;
		}
		audio->frames = frames;
		audio->frame_capacity = capacity;
	}

	SA_AVFrame* clone = sa_ffmpeg.av_frame_clone(frame);
	if (clone == NULL) {
		sa_set_error(error, error_size, "Failed to clone decoded audio frame");
		return 0;
	}
	audio->frames[audio->frame_count++] = clone;
	audio->byte_count += accounted_bytes;
	return 1;
}

static SA_RawAudio* sa_raw_audio_create(SA_Decoder* decoder, char* error, int error_size) {
	SA_RawAudio* audio = (SA_RawAudio*)calloc(1, sizeof(SA_RawAudio));
	if (audio == NULL) {
		sa_set_error(error, error_size, "Failed to allocate raw frame cache");
		return NULL;
	}
	audio->codec_parameters = sa_ffmpeg.avcodec_parameters_alloc();
	if (audio->codec_parameters == NULL) {
		sa_raw_audio_close(audio);
		sa_set_error(error, error_size, "Failed to allocate cached codec parameters");
		return NULL;
	}
	int result = sa_ffmpeg.avcodec_parameters_copy(audio->codec_parameters, decoder->codec_parameters);
	if (result < 0) {
		sa_raw_audio_close(audio);
		sa_set_error(error, error_size, sa_ffmpeg_error(result));
		return NULL;
	}
	return audio;
}

void sa_raw_audio_close(SA_RawAudio* audio) {
	if (audio == NULL) {
		return;
	}
	for (int index = 0; index < audio->frame_count; index++) {
		if (audio->frames[index] != NULL) {
			sa_ffmpeg.av_frame_free(&audio->frames[index]);
		}
	}
	free(audio->frames);
	if (audio->codec_parameters != NULL) {
		sa_ffmpeg.avcodec_parameters_free(&audio->codec_parameters);
	}
	free(audio);
}

SA_CancelToken* sa_cancel_token_create(void) {
	return (SA_CancelToken*)calloc(1, sizeof(SA_CancelToken));
}

void sa_cancel_token_cancel(SA_CancelToken* token) {
	if (token != NULL) {
		InterlockedExchange(&token->cancelled, 1);
	}
}

void sa_cancel_token_close(SA_CancelToken* token) {
	free(token);
}

int sa_cancel_token_is_cancelled(SA_CancelToken* token) {
	return token != NULL && InterlockedCompareExchange(&token->cancelled, 0, 0) != 0;
}

int sa_raw_audio_decode(const char* path, int max_bytes, SA_CancelToken* cancel_token, SA_RawAudio** out_audio, int* too_large, char* error, int error_size) {
	if (path == NULL || out_audio == NULL || too_large == NULL || max_bytes <= 0) {
		sa_set_error(error, error_size, "Invalid raw frame cache arguments");
		return 0;
	}
	*out_audio = NULL;
	*too_large = 0;
	if (sa_cancel_token_is_cancelled(cancel_token)) {
		sa_set_error(error, error_size, "Raw audio cache build cancelled");
		return 0;
	}

	SA_Decoder* decoder = NULL;
	if (!sa_decoder_open(path, NULL, 2, cancel_token, &decoder, error, error_size)) {
		return 0;
	}
	SA_RawAudio* audio = sa_raw_audio_create(decoder, error, error_size);
	if (audio == NULL) {
		sa_decoder_close(decoder);
		return 0;
	}

	int finished = 0;
	while (!finished) {
		if (!sa_decoder_next_frame(decoder, &finished, error, error_size)) {
			sa_decoder_close(decoder);
			sa_raw_audio_close(audio);
			return 0;
		}
		if (finished) {
			break;
		}

		int appended = sa_raw_audio_append_frame(audio, decoder->frame, max_bytes, too_large, error, error_size);
		sa_ffmpeg.av_frame_unref(decoder->frame);
		if (!appended) {
			sa_decoder_close(decoder);
			sa_raw_audio_close(audio);
			return 0;
		}
	}
	sa_decoder_close(decoder);

	if (audio->frame_count == 0) {
		sa_raw_audio_close(audio);
		sa_set_error(error, error_size, "Audio stream contains no decoded frames");
		return 0;
	}

	*out_audio = audio;
	return 1;
}

int sa_raw_audio_byte_count(SA_RawAudio* audio) {
	return audio == NULL ? 0 : audio->byte_count;
}

int sa_raw_filter_decoder_open(SA_RawAudio* audio, const char* filters, int output_channels, SA_RawFilterDecoder** out_decoder, char* error, int error_size) {
	if (audio == NULL || filters == NULL || filters[0] == '\0' || out_decoder == NULL) {
		sa_set_error(error, error_size, "Invalid cached filter decoder arguments");
		return 0;
	}
	if (output_channels != 1 && output_channels != 2) {
		sa_set_error(error, error_size, "Cached filter output channel count must be 1 or 2");
		return 0;
	}

	SA_RawFilterDecoder* decoder = (SA_RawFilterDecoder*)calloc(1, sizeof(SA_RawFilterDecoder));
	if (decoder == NULL) {
		sa_set_error(error, error_size, "Failed to allocate cached filter decoder");
		return 0;
	}
	decoder->audio = audio;
	decoder->filter_state.codec_parameters = audio->codec_parameters;
	decoder->filter_state.output_sample_rate = audio->codec_parameters->sample_rate;
	decoder->filter_state.output_channels = output_channels;
	decoder->filter_state.filter_description = sa_duplicate_string(filters);
	if (decoder->filter_state.filter_description == NULL) {
		free(decoder);
		sa_set_error(error, error_size, "Failed to allocate cached filter description");
		return 0;
	}

	*out_decoder = decoder;
	return 1;
}

int sa_raw_filter_decoder_read(SA_RawFilterDecoder* decoder, int16_t* out, int max_frames, int* frames_written, int* finished, char* error, int error_size) {
	if (decoder == NULL || out == NULL || frames_written == NULL || finished == NULL || max_frames <= 0) {
		sa_set_error(error, error_size, "Invalid cached filter read arguments");
		return 0;
	}
	*frames_written = 0;
	*finished = decoder->finished;
	if (decoder->finished) {
		return 1;
	}
	if (sa_cancel_token_is_cancelled(decoder->cancel_token)) {
		sa_set_error(error, error_size, "Audio cache build cancelled");
		return 0;
	}

	SA_Decoder* state = &decoder->filter_state;
	if (state->filter_graph != NULL && !state->filter_graph->finished) {
		if (!sa_filter_drain(state->filter_graph, out, max_frames, frames_written, error, error_size)) {
			return 0;
		}
	}

	while (*frames_written < max_frames && decoder->frame_index < decoder->audio->frame_count) {
		if (sa_cancel_token_is_cancelled(decoder->cancel_token)) {
			sa_set_error(error, error_size, "Audio cache build cancelled");
			return 0;
		}
		SA_AVFrame* frame = decoder->audio->frames[decoder->frame_index++];
		if (state->filter_graph == NULL && !sa_filter_graph_create(state, frame->format, error, error_size)) {
			return 0;
		}
		int result = sa_ffmpeg.av_buffersrc_add_frame_flags(state->filter_graph->buffer_source, frame, SA_AV_BUFFERSRC_FLAG_KEEP_REF);
		if (result < 0) {
			sa_set_error(error, error_size, sa_ffmpeg_error(result));
			return 0;
		}
		if (!sa_filter_drain(state->filter_graph, out, max_frames, frames_written, error, error_size)) {
			return 0;
		}
	}

	if (*frames_written < max_frames && decoder->frame_index >= decoder->audio->frame_count) {
		if (!sa_filter_flush(state->filter_graph, out, max_frames, frames_written, error, error_size)) {
			return 0;
		}
		if (state->filter_graph->finished) {
			decoder->finished = 1;
			*finished = 1;
		}
	}
	return 1;
}

void sa_raw_filter_decoder_set_cancel_token(SA_RawFilterDecoder* decoder, SA_CancelToken* cancel_token) {
	if (decoder != NULL) {
		decoder->cancel_token = cancel_token;
	}
}

int sa_raw_filter_decoder_sample_rate(SA_RawFilterDecoder* decoder) {
	return decoder == NULL ? 0 : decoder->filter_state.output_sample_rate;
}

void sa_raw_filter_decoder_close(SA_RawFilterDecoder* decoder) {
	if (decoder == NULL) {
		return;
	}
	if (decoder->filter_state.filter_graph != NULL) {
		sa_filter_graph_free(decoder->filter_state.filter_graph);
	}
	free(decoder->filter_state.filter_description);
	free(decoder);
}
