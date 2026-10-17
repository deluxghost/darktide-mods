#include "realms_audio_processing.h"

#pragma warning(push, 0)
#include "api/audio/audio_processing.h"
#pragma warning(pop)

#include <array>
#include <cstdio>

namespace {
bool check_result(int result, const char *operation, char *error, int capacity) {
    if (result == webrtc::AudioProcessing::kNoError) return true;
    if (error != nullptr && capacity > 0) std::snprintf(error, static_cast<size_t>(capacity), "WebRTC %s failed (%d)", operation, result);
    return false;
}
}

struct AudioProcessing::State {
    webrtc::scoped_refptr<webrtc::AudioProcessing> apm;
};

AudioProcessing::AudioProcessing() = default;
AudioProcessing::~AudioProcessing() = default;

bool AudioProcessing::configure(bool echo_cancellation, bool noise_suppression, char *error, int capacity) {
    webrtc::AudioProcessing::Config config;
    config.pipeline.multi_channel_render = true;
    config.echo_canceller.enabled = echo_cancellation;
    config.noise_suppression.enabled = noise_suppression;
    config.noise_suppression.level = webrtc::AudioProcessing::Config::NoiseSuppression::kModerate;
    if (!state_) {
        auto state = std::make_unique<State>();
        state->apm = webrtc::AudioProcessingBuilder().SetConfig(config).Create();
        if (!state->apm) {
            if (error != nullptr && capacity > 0) std::snprintf(error, static_cast<size_t>(capacity), "Could not create WebRTC audio processing");
            return false;
        }
        state_ = std::move(state);
    } else {
        state_->apm->ApplyConfig(config);
    }
    echo_ = echo_cancellation;
    noise_ = noise_suppression;
    return true;
}

bool AudioProcessing::reset(char *error, int capacity) {
    try {
        return !state_ || check_result(state_->apm->Initialize(), "reset", error, capacity);
    } catch (const std::bad_alloc &) {
        if (error != nullptr && capacity > 0) std::snprintf(error, static_cast<size_t>(capacity), "Could not reset WebRTC audio processing");
        return false;
    }
}

bool AudioProcessing::reference(const float *interleaved, char *error, int capacity) {
    if (!echo_) return true;
    std::array<float, FrameSamples> left{}, right{};
    for (uint32_t i = 0; i < FrameSamples; ++i) {
        left[i] = interleaved[i * ReferenceChannels];
        right[i] = interleaved[i * ReferenceChannels + 1];
    }
    float *channels[] = {left.data(), right.data()};
    const webrtc::StreamConfig stream(SampleRate, ReferenceChannels);
    return check_result(state_->apm->ProcessReverseStream(channels, stream, stream, channels), "render processing", error, capacity);
}

bool AudioProcessing::capture(float *pcm, int delay_ms, char *error, int capacity) {
    if (!echo_ && !noise_) return true;
    if (echo_ && !check_result(state_->apm->set_stream_delay_ms(delay_ms), "stream delay", error, capacity)) return false;
    float *channels[] = {pcm};
    const webrtc::StreamConfig stream(SampleRate, 1);
    return check_result(state_->apm->ProcessStream(channels, stream, stream, channels), "capture processing", error, capacity);
}
