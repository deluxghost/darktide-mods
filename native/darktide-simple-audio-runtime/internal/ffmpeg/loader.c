#include "ffmpeg_internal.h"

SA_FFmpeg sa_ffmpeg;
static int sa_ffmpeg_initialized = 0;

void sa_set_error(char* buffer, int buffer_size, const char* message) {
	if (buffer == NULL || buffer_size <= 0) {
		return;
	}

	if (message == NULL) {
		message = "unknown error";
	}

	strncpy(buffer, message, (size_t)buffer_size - 1);
	buffer[buffer_size - 1] = '\0';
}

char* sa_duplicate_string(const char* value) {
	if (value == NULL || value[0] == '\0') {
		return NULL;
	}

	size_t length = strlen(value) + 1;
	char* copy = (char*)malloc(length);
	if (copy == NULL) {
		return NULL;
	}

	memcpy(copy, value, length);
	return copy;
}

static void sa_windows_error(char* buffer, int buffer_size, const char* action) {
	char message[256];
	snprintf(message, sizeof(message), "%s failed: Windows error %lu", action, GetLastError());
	sa_set_error(buffer, buffer_size, message);
}

static void sa_marker(void) {}

static int sa_module_directory(wchar_t* buffer, DWORD buffer_count, char* error, int error_size) {
	HMODULE module = NULL;

	if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCWSTR)(void*)&sa_marker, &module)) {
		sa_windows_error(error, error_size, "GetModuleHandleExW");
		return 0;
	}

	DWORD length = GetModuleFileNameW(module, buffer, buffer_count);
	if (length == 0 || length >= buffer_count) {
		sa_windows_error(error, error_size, "GetModuleFileNameW");
		return 0;
	}

	wchar_t* last_slash = wcsrchr(buffer, L'\\');
	if (last_slash == NULL) {
		sa_set_error(error, error_size, "Failed to locate runtime DLL directory");
		return 0;
	}

	*last_slash = L'\0';
	return 1;
}

static HMODULE sa_load_library_from_runtime_dir(const wchar_t* directory, const wchar_t* name, char* error, int error_size) {
	wchar_t path[MAX_PATH];
	int written = swprintf(path, MAX_PATH, L"%ls\\%ls", directory, name);

	if (written <= 0 || written >= MAX_PATH) {
		sa_set_error(error, error_size, "FFmpeg DLL path is too long");
		return NULL;
	}

	HMODULE library = LoadLibraryW(path);
	if (library == NULL) {
		char name_utf8[128];
		WideCharToMultiByte(CP_UTF8, 0, name, -1, name_utf8, sizeof(name_utf8), NULL, NULL);

		char message[256];
		snprintf(message, sizeof(message), "Failed to load %s from runtime directory: Windows error %lu", name_utf8, GetLastError());
		sa_set_error(error, error_size, message);
		return NULL;
	}

	return library;
}

static FARPROC sa_symbol(HMODULE library, const char* name, char* error, int error_size) {
	FARPROC symbol = GetProcAddress(library, name);

	if (symbol == NULL) {
		char message[256];
		snprintf(message, sizeof(message), "Missing FFmpeg symbol %s", name);
		sa_set_error(error, error_size, message);
	}

	return symbol;
}

#define SA_LOAD_SYMBOL(field, type_name, library, name) do { \
	sa_ffmpeg.field = (type_name)sa_symbol(library, name, error, error_size); \
	if (sa_ffmpeg.field == NULL) { return 0; } \
} while (0)

int sa_ffmpeg_initialize(char* error, int error_size) {
	if (sa_ffmpeg_initialized) {
		return 1;
	}

	wchar_t directory[MAX_PATH];
	if (!sa_module_directory(directory, MAX_PATH, error, error_size)) {
		return 0;
	}

	sa_ffmpeg.avutil = sa_load_library_from_runtime_dir(directory, L"avutil-60.dll", error, error_size);
	if (sa_ffmpeg.avutil == NULL) {
		return 0;
	}

	sa_ffmpeg.swresample = sa_load_library_from_runtime_dir(directory, L"swresample-6.dll", error, error_size);
	if (sa_ffmpeg.swresample == NULL) {
		return 0;
	}

	sa_ffmpeg.swscale = sa_load_library_from_runtime_dir(directory, L"swscale-9.dll", error, error_size);
	if (sa_ffmpeg.swscale == NULL) {
		return 0;
	}

	sa_ffmpeg.avcodec = sa_load_library_from_runtime_dir(directory, L"avcodec-62.dll", error, error_size);
	if (sa_ffmpeg.avcodec == NULL) {
		return 0;
	}

	sa_ffmpeg.avformat = sa_load_library_from_runtime_dir(directory, L"avformat-62.dll", error, error_size);
	if (sa_ffmpeg.avformat == NULL) {
		return 0;
	}

	sa_ffmpeg.avfilter = sa_load_library_from_runtime_dir(directory, L"avfilter-11.dll", error, error_size);
	if (sa_ffmpeg.avfilter == NULL) {
		return 0;
	}

	SA_LOAD_SYMBOL(av_log_set_level, sa_av_log_set_level_fn, sa_ffmpeg.avutil, "av_log_set_level");
	SA_LOAD_SYMBOL(av_strerror, sa_av_strerror_fn, sa_ffmpeg.avutil, "av_strerror");
	SA_LOAD_SYMBOL(av_strdup, sa_av_strdup_fn, sa_ffmpeg.avutil, "av_strdup");
	SA_LOAD_SYMBOL(av_dict_iterate, sa_av_dict_iterate_fn, sa_ffmpeg.avutil, "av_dict_iterate");
	SA_LOAD_SYMBOL(av_get_sample_fmt_name, sa_av_get_sample_fmt_name_fn, sa_ffmpeg.avutil, "av_get_sample_fmt_name");
	SA_LOAD_SYMBOL(av_get_bytes_per_sample, sa_av_get_bytes_per_sample_fn, sa_ffmpeg.avutil, "av_get_bytes_per_sample");
	SA_LOAD_SYMBOL(av_channel_layout_default, sa_av_channel_layout_default_fn, sa_ffmpeg.avutil, "av_channel_layout_default");
	SA_LOAD_SYMBOL(av_channel_layout_describe, sa_av_channel_layout_describe_fn, sa_ffmpeg.avutil, "av_channel_layout_describe");
	SA_LOAD_SYMBOL(avformat_alloc_context, sa_avformat_alloc_context_fn, sa_ffmpeg.avformat, "avformat_alloc_context");
	SA_LOAD_SYMBOL(avformat_open_input, sa_avformat_open_input_fn, sa_ffmpeg.avformat, "avformat_open_input");
	SA_LOAD_SYMBOL(avformat_find_stream_info, sa_avformat_find_stream_info_fn, sa_ffmpeg.avformat, "avformat_find_stream_info");
	SA_LOAD_SYMBOL(av_find_best_stream, sa_av_find_best_stream_fn, sa_ffmpeg.avformat, "av_find_best_stream");
	SA_LOAD_SYMBOL(av_read_frame, sa_av_read_frame_fn, sa_ffmpeg.avformat, "av_read_frame");
	SA_LOAD_SYMBOL(avformat_close_input, sa_avformat_close_input_fn, sa_ffmpeg.avformat, "avformat_close_input");
	SA_LOAD_SYMBOL(avcodec_alloc_context3, sa_avcodec_alloc_context3_fn, sa_ffmpeg.avcodec, "avcodec_alloc_context3");
	SA_LOAD_SYMBOL(avcodec_parameters_to_context, sa_avcodec_parameters_to_context_fn, sa_ffmpeg.avcodec, "avcodec_parameters_to_context");
	SA_LOAD_SYMBOL(avcodec_open2, sa_avcodec_open2_fn, sa_ffmpeg.avcodec, "avcodec_open2");
	SA_LOAD_SYMBOL(avcodec_send_packet, sa_avcodec_send_packet_fn, sa_ffmpeg.avcodec, "avcodec_send_packet");
	SA_LOAD_SYMBOL(avcodec_receive_frame, sa_avcodec_receive_frame_fn, sa_ffmpeg.avcodec, "avcodec_receive_frame");
	SA_LOAD_SYMBOL(avcodec_free_context, sa_avcodec_free_context_fn, sa_ffmpeg.avcodec, "avcodec_free_context");
	SA_LOAD_SYMBOL(avcodec_parameters_alloc, sa_avcodec_parameters_alloc_fn, sa_ffmpeg.avcodec, "avcodec_parameters_alloc");
	SA_LOAD_SYMBOL(avcodec_parameters_copy, sa_avcodec_parameters_copy_fn, sa_ffmpeg.avcodec, "avcodec_parameters_copy");
	SA_LOAD_SYMBOL(avcodec_parameters_free, sa_avcodec_parameters_free_fn, sa_ffmpeg.avcodec, "avcodec_parameters_free");
	SA_LOAD_SYMBOL(av_packet_alloc, sa_av_packet_alloc_fn, sa_ffmpeg.avcodec, "av_packet_alloc");
	SA_LOAD_SYMBOL(av_packet_free, sa_av_packet_free_fn, sa_ffmpeg.avcodec, "av_packet_free");
	SA_LOAD_SYMBOL(av_packet_unref, sa_av_packet_unref_fn, sa_ffmpeg.avcodec, "av_packet_unref");
	SA_LOAD_SYMBOL(av_frame_alloc, sa_av_frame_alloc_fn, sa_ffmpeg.avutil, "av_frame_alloc");
	SA_LOAD_SYMBOL(av_frame_free, sa_av_frame_free_fn, sa_ffmpeg.avutil, "av_frame_free");
	SA_LOAD_SYMBOL(av_frame_unref, sa_av_frame_unref_fn, sa_ffmpeg.avutil, "av_frame_unref");
	SA_LOAD_SYMBOL(av_frame_clone, sa_av_frame_clone_fn, sa_ffmpeg.avutil, "av_frame_clone");
	SA_LOAD_SYMBOL(av_samples_get_buffer_size, sa_av_samples_get_buffer_size_fn, sa_ffmpeg.avutil, "av_samples_get_buffer_size");
	SA_LOAD_SYMBOL(swr_alloc_set_opts2, sa_swr_alloc_set_opts2_fn, sa_ffmpeg.swresample, "swr_alloc_set_opts2");
	SA_LOAD_SYMBOL(swr_init, sa_swr_init_fn, sa_ffmpeg.swresample, "swr_init");
	SA_LOAD_SYMBOL(swr_convert, sa_swr_convert_fn, sa_ffmpeg.swresample, "swr_convert");
	SA_LOAD_SYMBOL(swr_free, sa_swr_free_fn, sa_ffmpeg.swresample, "swr_free");
	SA_LOAD_SYMBOL(avfilter_get_by_name, sa_avfilter_get_by_name_fn, sa_ffmpeg.avfilter, "avfilter_get_by_name");
	SA_LOAD_SYMBOL(avfilter_graph_alloc, sa_avfilter_graph_alloc_fn, sa_ffmpeg.avfilter, "avfilter_graph_alloc");
	SA_LOAD_SYMBOL(avfilter_graph_create_filter, sa_avfilter_graph_create_filter_fn, sa_ffmpeg.avfilter, "avfilter_graph_create_filter");
	SA_LOAD_SYMBOL(avfilter_graph_parse_ptr, sa_avfilter_graph_parse_ptr_fn, sa_ffmpeg.avfilter, "avfilter_graph_parse_ptr");
	SA_LOAD_SYMBOL(avfilter_graph_config, sa_avfilter_graph_config_fn, sa_ffmpeg.avfilter, "avfilter_graph_config");
	SA_LOAD_SYMBOL(avfilter_graph_free, sa_avfilter_graph_free_fn, sa_ffmpeg.avfilter, "avfilter_graph_free");
	SA_LOAD_SYMBOL(avfilter_inout_alloc, sa_avfilter_inout_alloc_fn, sa_ffmpeg.avfilter, "avfilter_inout_alloc");
	SA_LOAD_SYMBOL(avfilter_inout_free, sa_avfilter_inout_free_fn, sa_ffmpeg.avfilter, "avfilter_inout_free");
	SA_LOAD_SYMBOL(av_buffersrc_add_frame_flags, sa_av_buffersrc_add_frame_flags_fn, sa_ffmpeg.avfilter, "av_buffersrc_add_frame_flags");
	SA_LOAD_SYMBOL(av_buffersink_get_frame, sa_av_buffersink_get_frame_fn, sa_ffmpeg.avfilter, "av_buffersink_get_frame");

	sa_ffmpeg.av_log_set_level(SA_AV_LOG_QUIET);
	sa_ffmpeg_initialized = 1;

	return 1;
}

const char* sa_ffmpeg_error(int code) {
	static _Thread_local char buffer[256];

	if (sa_ffmpeg.av_strerror != NULL && sa_ffmpeg.av_strerror(code, buffer, sizeof(buffer)) == 0) {
		return buffer;
	}

	snprintf(buffer, sizeof(buffer), "FFmpeg error %d", code);
	return buffer;
}
