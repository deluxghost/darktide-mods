#include <stdint.h>
#include <new>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <objbase.h>
#include <xaudio2.h>

extern "C" {
#include <x3daudio.h>
}

class SA_XAudioEngineCallback;

extern "C" {

struct SA_XAudioEngine {
	IXAudio2* engine;
	IXAudio2MasteringVoice* mastering_voice;
	X3DAUDIO_HANDLE x3d_handle;
	UINT32 output_channels;
	DWORD channel_mask;
	SA_XAudioEngineCallback* callback;
	LONG critical_error;
	LONG critical_error_set;
};

struct SA_XAudioVoice {
	IXAudio2SourceVoice* source_voice;
	SA_XAudioEngine* engine;
	UINT32 channels;
	float* matrix_coefficients;
	float* channel_azimuths;
};

struct SA_XAudioVector {
	float x;
	float y;
	float z;
};

}

class SA_XAudioEngineCallback final : public IXAudio2EngineCallback {
public:
	explicit SA_XAudioEngineCallback(SA_XAudioEngine* owner) : owner(owner) {}

	void STDMETHODCALLTYPE OnProcessingPassStart() override {}
	void STDMETHODCALLTYPE OnProcessingPassEnd() override {}

	void STDMETHODCALLTYPE OnCriticalError(HRESULT error) override {
		if (owner == NULL) {
			return;
		}

		owner->critical_error = (LONG)error;
		InterlockedExchange(&owner->critical_error_set, 1);
	}

private:
	SA_XAudioEngine* owner;
};

extern "C" {

enum SA_XAudioStage {
	SA_XAUDIO_STAGE_IDLE = 0,
	SA_XAUDIO_STAGE_INITIALIZING_COM,
	SA_XAUDIO_STAGE_CREATING_ENGINE,
	SA_XAUDIO_STAGE_CREATING_MASTERING_VOICE,
	SA_XAUDIO_STAGE_INITIALIZING_X3DAUDIO,
	SA_XAUDIO_STAGE_READY,
};

static volatile LONG sa_xaudio_stage = SA_XAUDIO_STAGE_IDLE;

static void sa_xaudio_set_stage(SA_XAudioStage stage) {
	InterlockedExchange(&sa_xaudio_stage, (LONG)stage);
}

const char* sa_xaudio_current_stage(void) {
	switch ((SA_XAudioStage)InterlockedCompareExchange(&sa_xaudio_stage, 0, 0)) {
	case SA_XAUDIO_STAGE_INITIALIZING_COM:
		return "initializing_com";
	case SA_XAUDIO_STAGE_CREATING_ENGINE:
		return "creating_xaudio_engine";
	case SA_XAUDIO_STAGE_CREATING_MASTERING_VOICE:
		return "creating_mastering_voice";
	case SA_XAUDIO_STAGE_INITIALIZING_X3DAUDIO:
		return "initializing_x3daudio";
	case SA_XAUDIO_STAGE_READY:
		return "ready";
	default:
		return "idle";
	}
}

static void sa_xaudio_set_error(char* buffer, int buffer_size, const char* message) {
	if (buffer == NULL || buffer_size <= 0) {
		return;
	}

	if (message == NULL) {
		message = "unknown error";
	}

	strncpy(buffer, message, (size_t)buffer_size - 1);
	buffer[buffer_size - 1] = '\0';
}

static void sa_xaudio_hresult_error(char* buffer, int buffer_size, const char* action, HRESULT result) {
	char message[256];
	snprintf(message, sizeof(message), "%s failed: HRESULT 0x%08lx", action, (unsigned long)result);
	sa_xaudio_set_error(buffer, buffer_size, message);
}

static DWORD sa_xaudio_fallback_channel_mask(UINT32 channels) {
	switch (channels) {
	case 1:
		return SPEAKER_MONO;
	case 2:
		return SPEAKER_STEREO;
	case 4:
		return SPEAKER_QUAD;
	case 6:
		return SPEAKER_5POINT1;
	case 8:
		return SPEAKER_7POINT1_SURROUND;
	default:
		return SPEAKER_STEREO;
	}
}

static X3DAUDIO_VECTOR sa_xaudio_vector(SA_XAudioVector value) {
	X3DAUDIO_VECTOR vector;
	vector.x = value.x;
	vector.y = value.y;
	vector.z = value.z;

	return vector;
}

int sa_xaudio_thread_initialize(char* error, int error_size) {
	sa_xaudio_set_stage(SA_XAUDIO_STAGE_INITIALIZING_COM);

	HRESULT result = CoInitializeEx(NULL, COINIT_MULTITHREADED);
	if (FAILED(result)) {
		sa_xaudio_hresult_error(error, error_size, "CoInitializeEx", result);
		return 0;
	}

	return 1;
}

void sa_xaudio_thread_uninitialize(void) {
	CoUninitialize();
	sa_xaudio_set_stage(SA_XAUDIO_STAGE_IDLE);
}

int sa_xaudio_engine_create(SA_XAudioEngine** out, char* error, int error_size) {
	if (out == NULL) {
		sa_xaudio_set_error(error, error_size, "XAudio2 engine output pointer is null");
		return 0;
	}

	*out = NULL;

	SA_XAudioEngine* engine = (SA_XAudioEngine*)calloc(1, sizeof(SA_XAudioEngine));
	if (engine == NULL) {
		sa_xaudio_set_error(error, error_size, "Failed to allocate XAudio2 engine");
		return 0;
	}

	sa_xaudio_set_stage(SA_XAUDIO_STAGE_CREATING_ENGINE);

	HRESULT result = XAudio2Create(&engine->engine, 0, XAUDIO2_DEFAULT_PROCESSOR);
	if (FAILED(result)) {
		free(engine);
		sa_xaudio_hresult_error(error, error_size, "XAudio2Create", result);
		return 0;
	}

	engine->callback = new (std::nothrow) SA_XAudioEngineCallback(engine);
	if (engine->callback == NULL) {
		engine->engine->Release();
		free(engine);
		sa_xaudio_set_error(error, error_size, "Failed to allocate XAudio2 engine callback");
		return 0;
	}

	result = engine->engine->RegisterForCallbacks(engine->callback);
	if (FAILED(result)) {
		engine->engine->Release();
		delete engine->callback;
		free(engine);
		sa_xaudio_hresult_error(error, error_size, "RegisterForCallbacks", result);
		return 0;
	}

	sa_xaudio_set_stage(SA_XAUDIO_STAGE_CREATING_MASTERING_VOICE);

	result = engine->engine->CreateMasteringVoice(&engine->mastering_voice);
	if (FAILED(result)) {
		engine->engine->UnregisterForCallbacks(engine->callback);
		engine->engine->Release();
		delete engine->callback;
		free(engine);
		sa_xaudio_hresult_error(error, error_size, "CreateMasteringVoice", result);
		return 0;
	}

	XAUDIO2_VOICE_DETAILS details;
	memset(&details, 0, sizeof(details));
	engine->mastering_voice->GetVoiceDetails(&details);
	engine->output_channels = details.InputChannels;
	if (engine->output_channels == 0) {
		engine->mastering_voice->DestroyVoice();
		engine->engine->UnregisterForCallbacks(engine->callback);
		engine->engine->Release();
		delete engine->callback;
		free(engine);
		sa_xaudio_set_error(error, error_size, "XAudio2 mastering voice has no output channels");
		return 0;
	}

	result = engine->mastering_voice->GetChannelMask(&engine->channel_mask);
	if (FAILED(result) || engine->channel_mask == 0) {
		engine->channel_mask = sa_xaudio_fallback_channel_mask(engine->output_channels);
	}

	sa_xaudio_set_stage(SA_XAUDIO_STAGE_INITIALIZING_X3DAUDIO);

	result = X3DAudioInitialize(engine->channel_mask, X3DAUDIO_SPEED_OF_SOUND, engine->x3d_handle);
	if (FAILED(result)) {
		engine->mastering_voice->DestroyVoice();
		engine->engine->UnregisterForCallbacks(engine->callback);
		engine->engine->Release();
		delete engine->callback;
		free(engine);
		sa_xaudio_hresult_error(error, error_size, "X3DAudioInitialize", result);
		return 0;
	}

	sa_xaudio_set_stage(SA_XAUDIO_STAGE_READY);
	*out = engine;
	return 1;
}

void sa_xaudio_engine_destroy(SA_XAudioEngine* engine) {
	if (engine == NULL) {
		return;
	}

	if (engine->mastering_voice != NULL) {
		engine->mastering_voice->DestroyVoice();
		engine->mastering_voice = NULL;
	}

	if (engine->engine != NULL && engine->callback != NULL) {
		engine->engine->UnregisterForCallbacks(engine->callback);
	}

	if (engine->engine != NULL) {
		engine->engine->Release();
		engine->engine = NULL;
	}

	if (engine->callback != NULL) {
		delete engine->callback;
		engine->callback = NULL;
	}

	free(engine);
}

int sa_xaudio_engine_critical_error(SA_XAudioEngine* engine, char* error, int error_size) {
	if (engine == NULL) {
		return 0;
	}

	if (InterlockedCompareExchange(&engine->critical_error_set, 0, 0) == 0) {
		return 0;
	}

	sa_xaudio_hresult_error(error, error_size, "XAudio2 critical error", (HRESULT)engine->critical_error);
	return 1;
}

int sa_xaudio_voice_create(SA_XAudioEngine* engine, int sample_rate, int channels, SA_XAudioVoice** out, char* error, int error_size) {
	if (engine == NULL || engine->engine == NULL) {
		sa_xaudio_set_error(error, error_size, "XAudio2 engine is not initialized");
		return 0;
	}
	if (out == NULL) {
		sa_xaudio_set_error(error, error_size, "XAudio2 voice output pointer is null");
		return 0;
	}
	if (sample_rate <= 0 || channels <= 0) {
		sa_xaudio_set_error(error, error_size, "Invalid XAudio2 source format");
		return 0;
	}

	*out = NULL;

	SA_XAudioVoice* voice = (SA_XAudioVoice*)calloc(1, sizeof(SA_XAudioVoice));
	if (voice == NULL) {
		sa_xaudio_set_error(error, error_size, "Failed to allocate XAudio2 source voice");
		return 0;
	}

	voice->matrix_coefficients = (float*)calloc((size_t)channels * engine->output_channels, sizeof(float));
	if (voice->matrix_coefficients == NULL) {
		free(voice);
		sa_xaudio_set_error(error, error_size, "Failed to allocate X3DAudio matrix");
		return 0;
	}
	if (channels > 1) {
		voice->channel_azimuths = (float*)calloc((size_t)channels, sizeof(float));
		if (voice->channel_azimuths == NULL) {
			free(voice->matrix_coefficients);
			free(voice);
			sa_xaudio_set_error(error, error_size, "Failed to allocate X3DAudio channel azimuths");
			return 0;
		}
	}

	WAVEFORMATEX format;
	memset(&format, 0, sizeof(format));
	format.wFormatTag = WAVE_FORMAT_PCM;
	format.nChannels = (WORD)channels;
	format.nSamplesPerSec = (DWORD)sample_rate;
	format.wBitsPerSample = 16;
	format.nBlockAlign = (WORD)(channels * sizeof(int16_t));
	format.nAvgBytesPerSec = format.nSamplesPerSec * format.nBlockAlign;

	HRESULT result = engine->engine->CreateSourceVoice(&voice->source_voice, &format);
	if (FAILED(result)) {
		free(voice->channel_azimuths);
		free(voice->matrix_coefficients);
		free(voice);
		sa_xaudio_hresult_error(error, error_size, "CreateSourceVoice", result);
		return 0;
	}

	result = voice->source_voice->Start(0);
	if (FAILED(result)) {
		voice->source_voice->DestroyVoice();
		free(voice->channel_azimuths);
		free(voice->matrix_coefficients);
		free(voice);
		sa_xaudio_hresult_error(error, error_size, "Start source voice", result);
		return 0;
	}

	voice->engine = engine;
	voice->channels = (UINT32)channels;
	*out = voice;
	return 1;
}

int sa_xaudio_voice_submit_loop(SA_XAudioVoice* voice, void* data, int byte_count, int loop_count, int end_of_stream, char* error, int error_size) {
	if (voice == NULL || voice->source_voice == NULL) {
		sa_xaudio_set_error(error, error_size, "XAudio2 voice is not initialized");
		return 0;
	}
	if (data == NULL || byte_count <= 0) {
		sa_xaudio_set_error(error, error_size, "Invalid XAudio2 buffer");
		return 0;
	}
	if (loop_count < -1 || loop_count > XAUDIO2_MAX_LOOP_COUNT) {
		sa_xaudio_set_error(error, error_size, "XAudio2 loop count is out of range");
		return 0;
	}

	XAUDIO2_BUFFER buffer;
	memset(&buffer, 0, sizeof(buffer));
	buffer.AudioBytes = (UINT32)byte_count;
	buffer.pAudioData = (const BYTE*)data;
	buffer.LoopCount = loop_count < 0 ? XAUDIO2_LOOP_INFINITE : (UINT32)loop_count;
	buffer.Flags = end_of_stream ? XAUDIO2_END_OF_STREAM : 0;

	HRESULT result = voice->source_voice->SubmitSourceBuffer(&buffer);
	if (FAILED(result)) {
		sa_xaudio_hresult_error(error, error_size, "SubmitSourceBuffer", result);
		return 0;
	}

	return 1;
}

int sa_xaudio_voice_discontinuity(SA_XAudioVoice* voice, char* error, int error_size) {
	if (voice == NULL || voice->source_voice == NULL) {
		sa_xaudio_set_error(error, error_size, "XAudio2 voice is not initialized");
		return 0;
	}

	HRESULT result = voice->source_voice->Discontinuity();
	if (FAILED(result)) {
		sa_xaudio_hresult_error(error, error_size, "Discontinuity", result);
		return 0;
	}

	return 1;
}

int sa_xaudio_voice_set_volume(SA_XAudioVoice* voice, float volume, char* error, int error_size) {
	if (voice == NULL || voice->source_voice == NULL) {
		sa_xaudio_set_error(error, error_size, "XAudio2 voice is not initialized");
		return 0;
	}

	HRESULT result = voice->source_voice->SetVolume(volume);
	if (FAILED(result)) {
		sa_xaudio_hresult_error(error, error_size, "SetVolume", result);
		return 0;
	}

	return 1;
}

int sa_xaudio_voice_set_spatial(
	SA_XAudioVoice* voice,
	float volume,
	SA_XAudioVector source_position,
	SA_XAudioVector listener_position,
	SA_XAudioVector listener_front,
	SA_XAudioVector listener_top,
	char* error,
	int error_size
) {
	if (voice == NULL || voice->source_voice == NULL || voice->engine == NULL || voice->engine->mastering_voice == NULL) {
		sa_xaudio_set_error(error, error_size, "XAudio2 voice is not initialized");
		return 0;
	}

	if (!sa_xaudio_voice_set_volume(voice, volume, error, error_size)) {
		return 0;
	}

	X3DAUDIO_LISTENER listener;
	memset(&listener, 0, sizeof(listener));
	listener.Position = sa_xaudio_vector(listener_position);
	listener.OrientFront = sa_xaudio_vector(listener_front);
	listener.OrientTop = sa_xaudio_vector(listener_top);

	X3DAUDIO_DISTANCE_CURVE_POINT volume_curve_points[2];
	volume_curve_points[0].Distance = 0.0f;
	volume_curve_points[0].DSPSetting = 1.0f;
	volume_curve_points[1].Distance = 1.0f;
	volume_curve_points[1].DSPSetting = 1.0f;

	X3DAUDIO_DISTANCE_CURVE volume_curve;
	volume_curve.pPoints = volume_curve_points;
	volume_curve.PointCount = 2;

	X3DAUDIO_EMITTER emitter;
	memset(&emitter, 0, sizeof(emitter));
	emitter.Position = sa_xaudio_vector(source_position);
	emitter.OrientFront = listener.OrientFront;
	emitter.OrientTop = listener.OrientTop;
	emitter.ChannelCount = voice->channels;
	emitter.ChannelRadius = 0.0f;
	emitter.pChannelAzimuths = voice->channel_azimuths;
	emitter.pVolumeCurve = &volume_curve;
	emitter.CurveDistanceScaler = 1.0f;

	X3DAUDIO_DSP_SETTINGS dsp_settings;
	memset(&dsp_settings, 0, sizeof(dsp_settings));
	dsp_settings.SrcChannelCount = voice->channels;
	dsp_settings.DstChannelCount = voice->engine->output_channels;
	dsp_settings.pMatrixCoefficients = voice->matrix_coefficients;

	X3DAudioCalculate(
		voice->engine->x3d_handle,
		&listener,
		&emitter,
		X3DAUDIO_CALCULATE_MATRIX,
		&dsp_settings
	);

	HRESULT result = voice->source_voice->SetOutputMatrix(
		voice->engine->mastering_voice,
		voice->channels,
		voice->engine->output_channels,
		voice->matrix_coefficients
	);
	if (FAILED(result)) {
		sa_xaudio_hresult_error(error, error_size, "SetOutputMatrix", result);
		return 0;
	}

	return 1;
}

int sa_xaudio_voice_queued(SA_XAudioVoice* voice) {
	if (voice == NULL || voice->source_voice == NULL) {
		return 0;
	}

	XAUDIO2_VOICE_STATE state;
	voice->source_voice->GetState(&state, XAUDIO2_VOICE_NOSAMPLESPLAYED);

	return (int)state.BuffersQueued;
}

void sa_xaudio_voice_destroy(SA_XAudioVoice* voice) {
	if (voice == NULL) {
		return;
	}

	if (voice->source_voice != NULL) {
		voice->source_voice->Stop(0);
		voice->source_voice->FlushSourceBuffers();
		voice->source_voice->DestroyVoice();
		voice->source_voice = NULL;
	}

	if (voice->matrix_coefficients != NULL) {
		free(voice->matrix_coefficients);
		voice->matrix_coefficients = NULL;
	}
	if (voice->channel_azimuths != NULL) {
		free(voice->channel_azimuths);
		voice->channel_azimuths = NULL;
	}

	free(voice);
}

}
