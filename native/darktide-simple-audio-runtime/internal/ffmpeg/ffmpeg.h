#ifndef SIMPLE_AUDIO_FFMPEG_H
#define SIMPLE_AUDIO_FFMPEG_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SA_Decoder SA_Decoder;
typedef struct SA_RawAudio SA_RawAudio;
typedef struct SA_RawFilterDecoder SA_RawFilterDecoder;
typedef struct SA_CancelToken SA_CancelToken;

int sa_ffmpeg_initialize(char* error, int error_size);
int sa_decoder_open(const char* path, const char* filters, int output_channels, SA_CancelToken* cancel_token, SA_Decoder** out_decoder, char* error, int error_size);
int sa_decoder_read(SA_Decoder* decoder, int16_t* out, int max_frames, int* frames_written, int* finished, char* error, int error_size);
void sa_decoder_set_cancel_token(SA_Decoder* decoder, SA_CancelToken* cancel_token);
void sa_decoder_close(SA_Decoder* decoder);
int sa_decoder_sample_rate(SA_Decoder* decoder);
int sa_decoder_channels(SA_Decoder* decoder);
int sa_decoder_bytes_per_sample(SA_Decoder* decoder);
int64_t sa_decoder_bit_rate(SA_Decoder* decoder);
double sa_decoder_duration(SA_Decoder* decoder);
int sa_decoder_tag(SA_Decoder* decoder, int index, const char** key, const char** value);
SA_CancelToken* sa_cancel_token_create(void);
void sa_cancel_token_cancel(SA_CancelToken* token);
void sa_cancel_token_close(SA_CancelToken* token);
int sa_raw_audio_decode(const char* path, int max_bytes, SA_CancelToken* cancel_token, SA_RawAudio** out_audio, int* too_large, char* error, int error_size);
void sa_raw_audio_close(SA_RawAudio* audio);
int sa_raw_audio_byte_count(SA_RawAudio* audio);
int sa_raw_filter_decoder_open(SA_RawAudio* audio, const char* filters, int output_channels, SA_RawFilterDecoder** out_decoder, char* error, int error_size);
int sa_raw_filter_decoder_read(SA_RawFilterDecoder* decoder, int16_t* out, int max_frames, int* frames_written, int* finished, char* error, int error_size);
void sa_raw_filter_decoder_set_cancel_token(SA_RawFilterDecoder* decoder, SA_CancelToken* cancel_token);
int sa_raw_filter_decoder_sample_rate(SA_RawFilterDecoder* decoder);
void sa_raw_filter_decoder_close(SA_RawFilterDecoder* decoder);

#ifdef __cplusplus
}
#endif

#endif
