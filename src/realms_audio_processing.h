#pragma once

#include <cstdint>
#include <memory>

class AudioProcessing {
public:
    static constexpr uint32_t SampleRate = 48000;
    static constexpr uint32_t FrameSamples = SampleRate / 100;
    static constexpr uint32_t ReferenceChannels = 2;

    AudioProcessing();
    ~AudioProcessing();
    bool configure(bool echo_cancellation, bool noise_suppression, char *error, int capacity);
    bool reset(char *error, int capacity);
    bool reference(const float *interleaved, char *error, int capacity);
    bool capture(float *pcm, int delay_ms, char *error, int capacity);

private:
    struct State;
    std::unique_ptr<State> state_;
    bool echo_ = false;
    bool noise_ = false;
};
