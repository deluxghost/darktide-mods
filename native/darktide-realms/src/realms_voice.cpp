#include "darktide_realms.h"
#include "realms_audio.h"
#include "realms_audio_devices.h"
#include "realms_audio_processing.h"
#include "opus.h"
#include <windows.h>
#include <mmdeviceapi.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <cwchar>
#include <deque>
#include <map>
#include <memory>
#include <iterator>
#include <mutex>
#include <thread>

namespace {

constexpr uint32_t kSampleRate = 48000;
constexpr uint32_t kMixFrames = kSampleRate / 100;
constexpr uint32_t kMaximumFrameSamples = kMixFrames * 2;
constexpr uint32_t kQueueLifetimeMs = 100;
constexpr uint32_t kPcmCapacity = kSampleRate * kQueueLifetimeMs / 1000;
constexpr size_t kPacketCapacity = 64;
using Clock = std::chrono::steady_clock;

bool voice_error(char *error, int capacity, const char *message) {
    if (error != nullptr && capacity > 0) {
        std::snprintf(error, static_cast<size_t>(capacity), "%s", message);
    }
    return false;
}

template <typename T, size_t Capacity>
struct Ring {
    std::array<T, Capacity> data{};
    std::atomic<uint64_t> read{0};
    std::atomic<uint64_t> write{0};

    uint32_t size() const {
        const uint64_t start = read.load(std::memory_order_acquire);
        return static_cast<uint32_t>(std::min(static_cast<uint64_t>(Capacity), write.load(std::memory_order_acquire) - start));
    }
    uint32_t push(const T *source, uint32_t count) {
        const uint64_t start = write.load(std::memory_order_relaxed);
        count = static_cast<uint32_t>(std::min(static_cast<uint64_t>(count), Capacity - (start - read.load(std::memory_order_acquire))));
        for (uint32_t i = 0; i < count; ++i) {
            data[(start + i) % Capacity] = source[i];
        }
        write.store(start + count, std::memory_order_release);
        return count;
    }
    uint32_t pop(T *target, uint32_t count) {
        const uint64_t start = read.load(std::memory_order_relaxed);
        count = static_cast<uint32_t>(std::min(static_cast<uint64_t>(count), write.load(std::memory_order_acquire) - start));
        for (uint32_t i = 0; i < count; ++i) {
            if (target != nullptr) {
                target[i] = data[(start + i) % Capacity];
            }
        }
        read.store(start + count, std::memory_order_release);
        return count;
    }
    // Only the consumer may inspect or discard the front element.
    const T *front() const {
        return size() == 0 ? nullptr : &data[read.load(std::memory_order_relaxed) % Capacity];
    }
};

struct Packet {
    std::array<unsigned char, REALMS_VOICE_MAX_PACKET_SIZE> data{};
    Clock::time_point created{};
    uint32_t size = 0;
    uint32_t sequence = 0;
    uint32_t speaking = 0;
    uint32_t stream = 0;
    uint32_t speaker = 0;
    bool remove = false;
};

struct Speaker {
    OpusDecoder *decoder = nullptr;
    Ring<float, kPcmCapacity> pcm;
    ~Speaker() { opus_decoder_destroy(decoder); }
};

bool resolve_playback_device(uint32_t selected, ma_device_id &device, char *error, int capacity) {
    const HMODULE plugin = GetModuleHandleW(L"wwise_pluginw64_release.dll");
    if (plugin == nullptr) return voice_error(error, capacity, "Game Wwise audio plugin is not loaded");
    using GetWindowsDevice = bool (*)(int, uint32_t &, IMMDevice **, uint32_t);
    const auto get_device = reinterpret_cast<GetWindowsDevice>(GetProcAddress(plugin,
        "?GetWindowsDevice@AK@@YA_NHAEAIPEAPEAUIMMDevice@@W4AkAudioDeviceState@@@Z"));
    if (get_device == nullptr) return voice_error(error, capacity, "Wwise Windows device interface is unavailable");
    for (int index = 0; ; ++index) {
        uint32_t id = 0;
        IMMDevice *endpoint = nullptr;
        if (!get_device(index, id, &endpoint, DEVICE_STATE_ACTIVE)) {
            return voice_error(error, capacity, "Game-selected playback device is unavailable");
        }
        if (id != selected) {
            endpoint->Release();
            continue;
        }
        wchar_t *endpoint_id = nullptr;
        const HRESULT result = endpoint->GetId(&endpoint_id);
        endpoint->Release();
        if (FAILED(result)) return voice_error(error, capacity, "Could not read the Wwise Windows endpoint ID");
        const size_t length = std::wcslen(endpoint_id) + 1;
        const bool fits = length <= std::size(device.wasapi);
        if (fits) std::copy_n(endpoint_id, length, device.wasapi);
        CoTaskMemFree(endpoint_id);
        return fits || voice_error(error, capacity, "Wwise Windows endpoint ID is too long");
    }
}

uint32_t buffer_us(const ma_device &device, bool input) {
    const uint32_t rate = input ? device.capture.internalSampleRate : device.playback.internalSampleRate;
    const uint32_t frames = input ? device.capture.internalPeriodSizeInFrames : device.playback.internalPeriodSizeInFrames;
    const uint32_t periods = input ? device.capture.internalPeriods : device.playback.internalPeriods;
    return rate == 0 ? 0 : static_cast<uint32_t>(static_cast<uint64_t>(frames) * periods * 1000000 / rate);
}

struct Voice {
    RealmsVoiceConfig config{};
    ma_context context{};
    ma_device playback{};
    ma_device capture{};
    ma_device loopback{};
    AudioDevices devices;
    AudioProcessing processing;
    bool playback_initialized = false;
    bool capture_initialized = false;
    bool reference_initialized = false;
    bool context_initialized = false;
    OpusEncoder *encoder = nullptr;
    std::thread worker;
    HANDLE wake = nullptr;
    std::atomic<bool> stopping{false};
    std::atomic<bool> capture_enabled{false};
    std::atomic<bool> transmitting{false};
    std::atomic<bool> reference_enabled{false};
    std::atomic<bool> processing_enabled{false};
    std::atomic<bool> changing_playback{false};
    std::atomic<bool> default_playback{true}, default_capture{true};
    std::atomic<bool> has_speakers{false};
    std::atomic<bool> failure{false};
    std::mutex failure_mutex;
    char failure_text[160]{};
    std::atomic<uint64_t> encoded_frames{0}, encoded_bytes{0}, decoded_frames{0}, expired_packets{0};
    std::atomic<uint64_t> dropped_packets{0}, dropped_capture_frames{0}, dropped_playback_frames{0}, playback_underrun_frames{0};
    std::atomic<uint64_t> encode_time_us{0}, maximum_encode_time_us{0}, decode_time_us{0}, maximum_decode_time_us{0};
    std::atomic<uint64_t> processed_frames{0}, processing_time_us{0}, maximum_processing_time_us{0}, dropped_reference_frames{0};
    std::atomic<uint32_t> maximum_packet_bytes{0};
    std::atomic<uint32_t> capture_buffer_us{0}, playback_buffer_us{0};
    uint32_t lookahead = 0;
    uint32_t sequence = 0;
    float volume = 1.0f;
    uint32_t capture_stream = 0;
    Ring<float, kPcmCapacity> captured;
    Ring<float, kPcmCapacity * AudioProcessing::ReferenceChannels> reference;
    Ring<float, kPcmCapacity> rendered;
    std::array<float, kMaximumFrameSamples> processed_pcm{};
    uint32_t processed_samples = 0;
    Ring<Packet, kPacketCapacity> outgoing;
    std::mutex input_mutex;
    std::mutex capture_mutex;
    std::deque<Packet> incoming;
    std::map<uint32_t, std::unique_ptr<Speaker>> speakers;

    ~Voice() {
        stopping.store(true, std::memory_order_release);
        if (capture_initialized) ma_device_uninit(&capture);
        if (reference_initialized) ma_device_uninit(&loopback);
        if (playback_initialized) ma_device_uninit(&playback);
        devices.uninitialize();
        if (context_initialized) ma_context_uninit(&context);
        if (wake != nullptr) SetEvent(wake);
        if (worker.joinable()) worker.join();
        if (wake != nullptr) CloseHandle(wake);
        opus_encoder_destroy(encoder);
    }

    static void audio_callback(ma_device *device, void *output, const void *input, ma_uint32 frames) {
        auto &self = *static_cast<Voice *>(device->pUserData);
        if (self.stopping.load(std::memory_order_acquire)) {
            if (output != nullptr) std::fill_n(static_cast<float *>(output), frames, 0.0f);
            return;
        }
        if (device == &self.loopback) {
            if (input != nullptr && self.reference_enabled.load(std::memory_order_acquire)) {
                const uint32_t count = frames * AudioProcessing::ReferenceChannels;
                const uint32_t pushed = self.reference.push(static_cast<const float *>(input), count);
                self.dropped_reference_frames.fetch_add((count - pushed) / AudioProcessing::ReferenceChannels);
            }
            SetEvent(self.wake);
            return;
        }
        if (input != nullptr && self.capture_enabled.load(std::memory_order_acquire) &&
            (self.transmitting.load(std::memory_order_acquire) || self.processing_enabled.load(std::memory_order_acquire))) {
            self.dropped_capture_frames.fetch_add(frames - self.captured.push(static_cast<const float *>(input), frames));
        }
        if (output != nullptr) {
            auto *pcm = static_cast<float *>(output);
            const uint32_t got = self.rendered.pop(pcm, frames);
            std::fill(pcm + got, pcm + frames, 0.0f);
            if (self.has_speakers.load(std::memory_order_relaxed)) self.playback_underrun_frames.fetch_add(frames - got);
        }
        SetEvent(self.wake);
    }

    static void notification(const ma_device_notification *notice) {
        auto &self = *static_cast<Voice *>(notice->pDevice->pUserData);
        if (notice->type == ma_device_notification_type_started || notice->type == ma_device_notification_type_rerouted) {
            if (notice->pDevice == &self.loopback) return;
            const bool input = notice->pDevice == &self.capture;
            (input ? self.capture_buffer_us : self.playback_buffer_us).store(buffer_us(*notice->pDevice, input));
            return;
        }
        if (notice->pDevice == &self.capture && !self.capture_enabled.load(std::memory_order_acquire)) return;
        if (notice->pDevice == &self.loopback && !self.reference_enabled.load(std::memory_order_acquire)) return;
        if (notice->pDevice == &self.playback && self.changing_playback.load(std::memory_order_acquire)) return;
        if (notice->type == ma_device_notification_type_stopped && !self.stopping.load(std::memory_order_acquire)) {
            const bool input = notice->pDevice == &self.capture;
            if ((input ? self.default_capture : self.default_playback).load()) {
                self.devices.request_change(input ? AudioDevices::Capture : AudioDevices::Playback);
                return;
            }
            self.fail("Voice audio device stopped unexpectedly");
        }
    }

    bool open_device(ma_device &device, ma_device_type type, const ma_device_id *selected, char *error, int capacity) {
        auto settings = ma_device_config_init(type);
        if (type == ma_device_type_playback) settings.playback.pDeviceID = selected;
        else settings.capture.pDeviceID = selected;
        settings.sampleRate = kSampleRate;
        settings.periodSizeInMilliseconds = config.device_period_ms;
        settings.periods = 2;
        settings.performanceProfile = ma_performance_profile_low_latency;
        settings.dataCallback = audio_callback;
        settings.notificationCallback = notification;
        settings.pUserData = this;
        settings.capture.format = settings.playback.format = ma_format_f32;
        settings.capture.channels = settings.playback.channels = 1;
        if (type == ma_device_type_loopback) settings.capture.channels = AudioProcessing::ReferenceChannels;
        settings.capture.shareMode = settings.playback.shareMode = ma_share_mode_shared;
        // Rebuild on the game thread: miniaudio's WASAPI reroute leaks clients and can restart a null client.
        settings.wasapi.noAutoStreamRouting = MA_TRUE;
        const ma_result result = ma_device_init(&context, &settings, &device);
        if (result == MA_SUCCESS) {
            if (type == ma_device_type_playback) ma_device_set_master_volume(&device, volume);
            return true;
        }
        return voice_error(error, capacity, type == ma_device_type_playback ? "Could not open the selected WASAPI playback device" :
            type == ma_device_type_loopback ? "Could not open the WASAPI echo reference" : "Could not open the selected WASAPI capture device");
    }

    bool set_reference(bool enabled, char *error, int capacity) {
        if (enabled == reference_initialized) return true;
        reference_enabled.store(false, std::memory_order_release);
        if (reference_initialized) {
            ma_device_uninit(&loopback);
            reference_initialized = false;
        }
        {
            std::lock_guard<std::mutex> lock(capture_mutex);
            reference.pop(nullptr, reference.size());
        }
        if (!enabled) return true;
        ma_device_info endpoint{};
        if (ma_device_get_info(&playback, ma_device_type_playback, &endpoint) != MA_SUCCESS) {
            return voice_error(error, capacity, "Could not identify the echo reference playback endpoint");
        }
        if (!open_device(loopback, ma_device_type_loopback, &endpoint.id, error, capacity)) return false;
        reference_initialized = true;
        reference_enabled.store(true, std::memory_order_release);
        const ma_result result = ma_device_start(&loopback);
        if (result == MA_SUCCESS) return true;
        reference_enabled.store(false, std::memory_order_release);
        ma_device_uninit(&loopback);
        reference_initialized = false;
        return voice_error(error, capacity, ma_result_description(result));
    }

    bool initialize(char *error, int capacity) {
        if (!processing.configure(config.echo_cancellation != 0, config.noise_suppression != 0, error, capacity)) return false;
        processing_enabled.store(config.echo_cancellation != 0 || config.noise_suppression != 0);
        int result = OPUS_OK;
        encoder = opus_encoder_create(kSampleRate, 1, OPUS_APPLICATION_VOIP, &result);
        if (result != OPUS_OK) return voice_error(error, capacity, opus_strerror(result));
        result = opus_encoder_ctl(encoder, OPUS_SET_BITRATE(config.bitrate));
        if (result != OPUS_OK) return voice_error(error, capacity, opus_strerror(result));
        result = opus_encoder_ctl(encoder, OPUS_SET_DTX(1));
        if (result != OPUS_OK) return voice_error(error, capacity, opus_strerror(result));
        int delay = 0;
        result = opus_encoder_ctl(encoder, OPUS_GET_LOOKAHEAD(&delay));
        if (result != OPUS_OK) return voice_error(error, capacity, opus_strerror(result));
        lookahead = static_cast<uint32_t>(delay);
        wake = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        if (wake == nullptr) return voice_error(error, capacity, "Could not create the voice wake event");
        const ma_backend backend = ma_backend_wasapi;
        const ma_result initialized = ma_context_init(&backend, 1, nullptr, &context);
        if (initialized != MA_SUCCESS) return voice_error(error, capacity, "Could not initialize the WASAPI audio context");
        context_initialized = true;
        if (!devices.initialize(error, capacity)) return false;
        default_playback.store(config.playback_device_id == 0);
        ma_device_id selected{};
        if (config.playback_device_id != 0 && !resolve_playback_device(config.playback_device_id, selected, error, capacity)) return false;
        if (!open_device(playback, ma_device_type_playback, config.playback_device_id == 0 ? nullptr : &selected, error, capacity)) return false;
        playback_initialized = true;
        worker = std::thread([this] { run(); });
        const ma_result started = ma_device_start(&playback);
        return started == MA_SUCCESS || voice_error(error, capacity, ma_result_description(started));
    }

    bool healthy(char *error, int capacity) const {
        return !failure.load(std::memory_order_acquire) || voice_error(error, capacity, failure_text);
    }

    void fail(const char *message) {
        std::lock_guard<std::mutex> lock(failure_mutex);
        if (failure.load(std::memory_order_relaxed)) return;
        std::snprintf(failure_text, sizeof(failure_text), "%s", message);
        failure.store(true, std::memory_order_release);
        SetEvent(wake);
    }

    void encode_capture() {
        std::lock_guard<std::mutex> lock(capture_mutex);
        if (!capture_enabled.load(std::memory_order_acquire)) return;
        const uint32_t samples = kSampleRate * config.frame_ms / 1000;
        char processing_error[160]{};
        constexpr uint32_t reference_samples = kMixFrames * AudioProcessing::ReferenceChannels;
        std::array<float, reference_samples> reference_pcm{};
        while (reference.size() >= reference_samples) {
            reference.pop(reference_pcm.data(), reference_samples);
            const auto start = Clock::now();
            if (!processing.reference(reference_pcm.data(), processing_error, sizeof(processing_error))) {
                fail(processing_error);
                return;
            }
            processing_time_us.fetch_add(static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(Clock::now() - start).count()));
        }
        const uint32_t pending = captured.size();
        if (pending > samples * 2) dropped_capture_frames.fetch_add(captured.pop(nullptr, pending - samples * 2));
        std::array<float, kMixFrames> pcm{};
        while (captured.size() >= kMixFrames) {
            captured.pop(pcm.data(), kMixFrames);
            const auto processing_start = Clock::now();
            const int delay_ms = static_cast<int>(capture_buffer_us.load() / 1000);
            if (!processing.capture(pcm.data(), delay_ms, processing_error, sizeof(processing_error))) {
                fail(processing_error);
                return;
            }
            if (config.echo_cancellation != 0 || config.noise_suppression != 0) {
                const auto elapsed = static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(Clock::now() - processing_start).count());
                processed_frames.fetch_add(1);
                processing_time_us.fetch_add(elapsed);
                maximum_processing_time_us.store(std::max(maximum_processing_time_us.load(), elapsed));
            }
            // Keep AEC converged while push-to-talk is released, but encode nothing.
            if (!transmitting.load(std::memory_order_acquire)) continue;
            std::copy(pcm.begin(), pcm.end(), processed_pcm.begin() + processed_samples);
            processed_samples += kMixFrames;
            if (processed_samples < samples) continue;
            processed_samples = 0;
            Packet packet;
            packet.created = Clock::now();
            packet.sequence = ++sequence;
            packet.stream = capture_stream;
            const auto start = Clock::now();
            const int bytes = opus_encode_float(encoder, processed_pcm.data(), static_cast<int>(samples), packet.data.data(), REALMS_VOICE_MAX_PACKET_SIZE);
            const auto elapsed = static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(Clock::now() - start).count());
            if (bytes < 0) { fail(opus_strerror(bytes)); return; }
            int in_dtx = 0;
            const int activity = opus_encoder_ctl(encoder, OPUS_GET_IN_DTX(&in_dtx));
            if (activity != OPUS_OK) { fail(opus_strerror(activity)); return; }
            packet.speaking = in_dtx == 0 ? 1 : 0;
            packet.size = static_cast<uint32_t>(bytes);
            encode_time_us.fetch_add(elapsed);
            maximum_encode_time_us.store(std::max(maximum_encode_time_us.load(), elapsed));
            maximum_packet_bytes.store(std::max(maximum_packet_bytes.load(), packet.size));
            encoded_frames.fetch_add(1);
            encoded_bytes.fetch_add(packet.size);
            if (outgoing.push(&packet, 1) == 0) dropped_packets.fetch_add(1);
        }
    }

    void enqueue_packet(Packet packet) {
        std::lock_guard<std::mutex> lock(input_mutex);
        if (packet.remove) {
            incoming.erase(std::remove_if(incoming.begin(), incoming.end(), [&](const Packet &queued) {
                return queued.speaker == packet.speaker;
            }), incoming.end());
        } else if (incoming.size() >= kPacketCapacity) {
            const auto oldest = std::find_if(incoming.begin(), incoming.end(), [](const Packet &queued) {
                return !queued.remove;
            });
            dropped_packets.fetch_add(1);
            if (oldest == incoming.end()) return;
            incoming.erase(oldest);
        }
        // Speaker removals must survive congestion and stay ordered with the next stream.
        incoming.push_back(std::move(packet));
        SetEvent(wake);
    }

    void decode_packet(const Packet &packet) {
        if (packet.remove) {
            speakers.erase(packet.speaker);
            has_speakers.store(!speakers.empty());
            return;
        }
        if (Clock::now() - packet.created >= std::chrono::milliseconds(kQueueLifetimeMs)) {
            expired_packets.fetch_add(1);
            return;
        }
        if (speakers.find(packet.speaker) == speakers.end() && speakers.size() >= RealmsRuntime_MaximumHostMembers()) {
            fail("Voice speaker capacity exceeded");
            return;
        }
        auto &slot = speakers[packet.speaker];
        if (!slot) {
            slot = std::make_unique<Speaker>();
            int result = OPUS_OK;
            slot->decoder = opus_decoder_create(kSampleRate, 1, &result);
            if (result != OPUS_OK) { fail(opus_strerror(result)); return; }
            has_speakers.store(true);
        }
        auto &speaker = *slot;
        std::array<float, kMaximumFrameSamples> pcm{};
        const auto start = Clock::now();
        const int samples = opus_decode_float(speaker.decoder, packet.size == 0 ? nullptr : packet.data.data(),
                                              static_cast<opus_int32>(packet.size), pcm.data(),
                                              static_cast<int>(kSampleRate * config.frame_ms / 1000), 0);
        const auto elapsed = static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(Clock::now() - start).count());
        if (samples < 0) { fail(opus_strerror(samples)); return; }
        decode_time_us.fetch_add(elapsed);
        maximum_decode_time_us.store(std::max(maximum_decode_time_us.load(), elapsed));
        decoded_frames.fetch_add(1);
        const uint32_t count = static_cast<uint32_t>(samples);
        const uint32_t queued = speaker.pcm.size();
        if (queued + count > kPcmCapacity) {
            dropped_playback_frames.fetch_add(speaker.pcm.pop(nullptr, queued + count - kPcmCapacity));
        }
        speaker.pcm.push(pcm.data(), count);
    }

    void mix_playback() {
        while (rendered.size() < kMixFrames * 2) {
            std::array<float, kMixFrames> mixed{}, pcm{};
            bool available = false;
            for (auto &entry : speakers) {
                const uint32_t count = entry.second->pcm.pop(pcm.data(), kMixFrames);
                available = available || count != 0;
                for (uint32_t i = 0; i < count; ++i) mixed[i] += pcm[i];
            }
            if (!available) return;
            for (float &sample : mixed) sample = std::clamp(sample, -1.0f, 1.0f);
            rendered.push(mixed.data(), kMixFrames);
        }
    }

    void run() {
        try {
            while (!stopping.load(std::memory_order_acquire)) {
                WaitForSingleObject(wake, INFINITE);
                if (stopping.load(std::memory_order_acquire)) return;
                encode_capture();
                std::deque<Packet> packets;
                {
                    std::lock_guard<std::mutex> lock(input_mutex);
                    packets.swap(incoming);
                }
                for (const auto &packet : packets) decode_packet(packet);
                mix_playback();
                if (failure.load(std::memory_order_acquire)) return;
            }
        } catch (const std::bad_alloc &) {
            fail("Could not allocate voice worker memory");
        }
    }
};

std::mutex voice_mutex;
std::unique_ptr<Voice> voice;

bool require_voice(char *error, int capacity) {
    return voice ? voice->healthy(error, capacity) : voice_error(error, capacity, "Voice is not started");
}

} // namespace

int RealmsRuntime_StartVoice(const RealmsVoiceConfig *config, char *error, int capacity) {
    if (config == nullptr || config->struct_size != sizeof(*config) || (config->frame_ms != 10 && config->frame_ms != 20) ||
        config->bitrate < 6000 || config->bitrate > 510000 || config->device_period_ms < 5 || config->device_period_ms > 20 ||
        config->echo_cancellation > 1 || config->noise_suppression > 1 ||
        static_cast<uint64_t>(config->bitrate) * config->frame_ms > REALMS_VOICE_MAX_PACKET_SIZE * 8000) {
        return voice_error(error, capacity, "Voice configuration is invalid or exceeds the packet budget");
    }
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (voice) return voice_error(error, capacity, "Voice is already started");
    try {
        auto instance = std::make_unique<Voice>();
        instance->config = *config;
        if (!instance->initialize(error, capacity)) return 0;
        voice = std::move(instance);
        return 1;
    } catch (const std::bad_alloc &) {
        return voice_error(error, capacity, "Could not allocate voice state");
    } catch (const std::system_error &) {
        return voice_error(error, capacity, "Could not start the voice worker");
    }
}

int RealmsRuntime_StopVoice(char *, int) {
    std::lock_guard<std::mutex> lock(voice_mutex);
    voice.reset();
    return 1;
}

int RealmsRuntime_SetVoicePlaybackDevice(uint32_t device_id, char *error, int capacity) {
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!require_voice(error, capacity)) return 0;
    ma_device_id selected{};
    if (device_id != 0 && !resolve_playback_device(device_id, selected, error, capacity)) {
        voice.reset();
        return 0;
    }
    voice->changing_playback.store(true, std::memory_order_release);
    if (!voice->set_reference(false, error, capacity)) return 0;
    voice->default_playback.store(device_id == 0);
    voice->config.playback_device_id = device_id;
    ma_device_uninit(&voice->playback);
    voice->playback_initialized = false;
    bool success = voice->open_device(voice->playback, ma_device_type_playback, device_id == 0 ? nullptr : &selected, error, capacity);
    if (success) {
        voice->playback_initialized = true;
        const ma_result result = ma_device_start(&voice->playback);
        success = result == MA_SUCCESS || voice_error(error, capacity, ma_result_description(result));
    }
    if (success && voice->capture_initialized && voice->config.echo_cancellation != 0) {
        success = voice->set_reference(true, error, capacity);
    }
    if (success) {
        std::lock_guard<std::mutex> capture_lock(voice->capture_mutex);
        success = voice->processing.reset(error, capacity);
    }
    voice->changing_playback.store(false, std::memory_order_release);
    if (!success) voice.reset();
    return success ? 1 : 0;
}

int RealmsRuntime_SetVoiceCapture(int enabled, const char *device_id, char *error, int capacity) {
    if (enabled != 0 && enabled != 1) return voice_error(error, capacity, "Voice capture flag is invalid");
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!voice) return voice_error(error, capacity, "Voice is not started");
    if (enabled != 0 && !voice->healthy(error, capacity)) return 0;
    if ((enabled != 0) == voice->capture_initialized) return 1;
    if (enabled == 0) {
        voice->transmitting.store(false, std::memory_order_release);
        voice->capture_enabled.store(false, std::memory_order_release);
        ma_device_uninit(&voice->capture);
        voice->capture_initialized = false;
        if (!voice->set_reference(false, error, capacity)) return 0;
        std::lock_guard<std::mutex> capture_lock(voice->capture_mutex);
        voice->captured.pop(nullptr, voice->captured.size());
        voice->outgoing.pop(nullptr, voice->outgoing.size());
        voice->processed_samples = 0;
        opus_encoder_ctl(voice->encoder, OPUS_RESET_STATE);
        ++voice->capture_stream;
        return 1;
    }
    ma_device_id selected{};
    if (device_id != nullptr && MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, device_id, -1,
            selected.wasapi, static_cast<int>(std::size(selected.wasapi))) == 0) {
        return voice_error(error, capacity, "Capture endpoint ID is invalid UTF-8 or too long");
    }
    if (!voice->open_device(voice->capture, ma_device_type_capture, device_id == nullptr ? nullptr : &selected, error, capacity)) return 0;
    voice->capture_initialized = true;
    voice->default_capture.store(device_id == nullptr);
    if (voice->config.echo_cancellation != 0 && !voice->set_reference(true, error, capacity)) {
        ma_device_uninit(&voice->capture);
        voice->capture_initialized = false;
        return 0;
    }
    bool processing_ready;
    {
        std::lock_guard<std::mutex> capture_lock(voice->capture_mutex);
        processing_ready = voice->processing.reset(error, capacity);
    }
    if (!processing_ready) {
        ma_device_uninit(&voice->capture);
        voice->capture_initialized = false;
        voice->set_reference(false, nullptr, 0);
        return 0;
    }
    voice->capture_enabled.store(true, std::memory_order_release);
    const ma_result started = ma_device_start(&voice->capture);
    if (started != MA_SUCCESS) {
        voice->capture_enabled.store(false, std::memory_order_release);
        ma_device_uninit(&voice->capture);
        voice->capture_initialized = false;
        voice->set_reference(false, nullptr, 0);
        return voice_error(error, capacity, ma_result_description(started));
    }
    return 1;
}

int RealmsRuntime_SetVoiceTransmission(int enabled, char *error, int capacity) {
    if (enabled != 0 && enabled != 1) return voice_error(error, capacity, "Voice transmission flag is invalid");
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!require_voice(error, capacity)) return 0;
    if (enabled != 0 && !voice->capture_initialized) return voice_error(error, capacity, "Voice capture is not enabled");
    std::lock_guard<std::mutex> capture_lock(voice->capture_mutex);
    if (voice->transmitting.load() == (enabled != 0)) return 1;
    voice->transmitting.store(false, std::memory_order_release);
    voice->captured.pop(nullptr, voice->captured.size());
    voice->outgoing.pop(nullptr, voice->outgoing.size());
    voice->processed_samples = 0;
    const int result = opus_encoder_ctl(voice->encoder, OPUS_RESET_STATE);
    if (result != OPUS_OK) return voice_error(error, capacity, opus_strerror(result));
    ++voice->capture_stream;
    voice->transmitting.store(enabled != 0, std::memory_order_release);
    return 1;
}

int RealmsRuntime_SetVoiceProcessing(int echo_cancellation, int noise_suppression, char *error, int capacity) {
    if ((echo_cancellation != 0 && echo_cancellation != 1) || (noise_suppression != 0 && noise_suppression != 1)) {
        return voice_error(error, capacity, "Voice processing flags are invalid");
    }
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!require_voice(error, capacity)) return 0;
    if (!voice->set_reference(echo_cancellation != 0 && voice->capture_initialized, error, capacity)) {
        voice.reset();
        return 0;
    }
    try {
        bool success;
        {
            std::lock_guard<std::mutex> capture_lock(voice->capture_mutex);
            success = voice->processing.configure(echo_cancellation != 0, noise_suppression != 0, error, capacity);
            if (success) {
                voice->config.echo_cancellation = static_cast<uint32_t>(echo_cancellation);
                voice->config.noise_suppression = static_cast<uint32_t>(noise_suppression);
                voice->processing_enabled.store(echo_cancellation != 0 || noise_suppression != 0, std::memory_order_release);
                voice->processed_samples = 0;
            }
        }
        if (!success) voice.reset();
        return success ? 1 : 0;
    } catch (const std::bad_alloc &) {
        voice.reset();
        return voice_error(error, capacity, "Could not allocate voice processing state");
    }
}

int RealmsRuntime_UpdateVoice(char *error, int capacity) {
    uint32_t changes;
    bool resume_transmission;
    {
        std::lock_guard<std::mutex> lock(voice_mutex);
        if (!require_voice(error, capacity)) {
            voice.reset();
            return 0;
        }
        changes = voice->devices.take_changes();
        resume_transmission = voice->transmitting.load();
        if (!voice->default_playback.load()) changes &= ~AudioDevices::Playback;
        if (!voice->capture_initialized || !voice->default_capture.load()) changes &= ~AudioDevices::Capture;
    }
    if ((changes & AudioDevices::Playback) != 0 && !RealmsRuntime_SetVoicePlaybackDevice(0, error, capacity)) return 0;
    if ((changes & AudioDevices::Capture) != 0 &&
        (!RealmsRuntime_SetVoiceCapture(0, nullptr, error, capacity) || !RealmsRuntime_SetVoiceCapture(1, nullptr, error, capacity) ||
         !RealmsRuntime_SetVoiceTransmission(resume_transmission ? 1 : 0, error, capacity))) {
        RealmsRuntime_StopVoice(nullptr, 0);
        return 0;
    }
    return 1;
}

int RealmsRuntime_SetVoiceVolume(float volume, char *error, int capacity) {
    if (!std::isfinite(volume) || volume < 0.0f || volume > 2.0f) return voice_error(error, capacity, "Voice volume is invalid");
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!require_voice(error, capacity)) return 0;
    const ma_result result = ma_device_set_master_volume(&voice->playback, volume);
    if (result != MA_SUCCESS) return voice_error(error, capacity, ma_result_description(result));
    voice->volume = volume;
    return 1;
}

int RealmsRuntime_PollVoicePacket(RealmsVoicePacket *output, void *payload, uint32_t capacity, char *error, int error_capacity) {
    if (output == nullptr || output->struct_size != sizeof(*output)) {
        voice_error(error, error_capacity, "Voice packet output has an invalid structure size");
        return -1;
    }
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!require_voice(error, error_capacity)) return -1;
    const Packet *packet = voice->outgoing.front();
    while (packet != nullptr && Clock::now() - packet->created >= std::chrono::milliseconds(kQueueLifetimeMs)) {
        voice->outgoing.pop(nullptr, 1);
        voice->expired_packets.fetch_add(1);
        packet = voice->outgoing.front();
    }
    if (packet == nullptr) return 0;
    output->sequence = packet->sequence;
    output->payload_size = packet->size;
    output->age_ms = static_cast<uint32_t>(std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - packet->created).count());
    output->speaking = packet->speaking;
    output->stream = packet->stream;
    if (payload == nullptr || capacity < packet->size) {
        voice_error(error, error_capacity, "Voice packet buffer is too small");
        return -2;
    }
    std::memcpy(payload, packet->data.data(), packet->size);
    voice->outgoing.pop(nullptr, 1);
    return 1;
}

int RealmsRuntime_SubmitVoicePacket(uint32_t speaker, const void *payload, uint32_t size, char *error, int capacity) {
    if (speaker == 0 || size > REALMS_VOICE_MAX_PACKET_SIZE || (size != 0 && payload == nullptr)) {
        return voice_error(error, capacity, "Voice packet identity or size is invalid");
    }
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!require_voice(error, capacity)) return 0;
    if (size != 0 && opus_packet_get_nb_samples(static_cast<const unsigned char *>(payload), static_cast<opus_int32>(size),
                                               kSampleRate) != static_cast<int>(kSampleRate * voice->config.frame_ms / 1000)) {
        return voice_error(error, capacity, "Opus packet duration does not match the voice configuration");
    }
    try {
        Packet packet;
        packet.speaker = speaker;
        packet.size = size;
        packet.created = Clock::now();
        if (size != 0) std::memcpy(packet.data.data(), payload, size);
        voice->enqueue_packet(std::move(packet));
        return 1;
    } catch (const std::bad_alloc &) {
        return voice_error(error, capacity, "Could not allocate a voice receive packet");
    }
}

int RealmsRuntime_RemoveVoiceSpeaker(uint32_t speaker, char *error, int capacity) {
    if (speaker == 0) return voice_error(error, capacity, "Voice speaker ID is invalid");
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!require_voice(error, capacity)) return 0;
    try {
        Packet packet;
        packet.speaker = speaker;
        packet.remove = true;
        voice->enqueue_packet(std::move(packet));
        return 1;
    } catch (const std::bad_alloc &) {
        return voice_error(error, capacity, "Could not allocate voice speaker removal");
    }
}

int RealmsRuntime_VoiceStats(RealmsVoiceStats *stats, char *error, int capacity) {
    if (stats == nullptr || stats->struct_size != sizeof(*stats)) return voice_error(error, capacity, "Voice statistics structure size is invalid");
    std::lock_guard<std::mutex> lock(voice_mutex);
    if (!require_voice(error, capacity)) return 0;
    stats->capture_enabled = voice->capture_initialized ? 1 : 0;
    stats->maximum_packet_bytes = voice->maximum_packet_bytes.load();
    stats->codec_lookahead_frames = voice->lookahead;
    stats->capture_pending_frames = voice->captured.size();
    stats->playback_pending_frames = voice->rendered.size();
    stats->capture_device_buffer_us = voice->capture_initialized ? voice->capture_buffer_us.load() : 0;
    stats->playback_device_buffer_us = voice->playback_buffer_us.load();
    stats->encoded_frames = voice->encoded_frames.load();
    stats->encoded_bytes = voice->encoded_bytes.load();
    stats->decoded_frames = voice->decoded_frames.load();
    stats->expired_packets = voice->expired_packets.load();
    stats->dropped_packets = voice->dropped_packets.load();
    stats->dropped_capture_frames = voice->dropped_capture_frames.load();
    stats->dropped_playback_frames = voice->dropped_playback_frames.load();
    stats->playback_underrun_frames = voice->playback_underrun_frames.load();
    stats->encode_time_us = voice->encode_time_us.load();
    stats->maximum_encode_time_us = voice->maximum_encode_time_us.load();
    stats->decode_time_us = voice->decode_time_us.load();
    stats->maximum_decode_time_us = voice->maximum_decode_time_us.load();
    stats->echo_cancellation = voice->config.echo_cancellation;
    stats->noise_suppression = voice->config.noise_suppression;
    stats->reference_enabled = voice->reference_initialized ? 1 : 0;
    stats->processed_frames = voice->processed_frames.load();
    stats->processing_time_us = voice->processing_time_us.load();
    stats->maximum_processing_time_us = voice->maximum_processing_time_us.load();
    stats->dropped_reference_frames = voice->dropped_reference_frames.load();
    return 1;
}
