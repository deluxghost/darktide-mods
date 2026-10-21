#pragma once

#include <windows.h>
#include <mmdeviceapi.h>
#include <atomic>
#include <cstdint>

class AudioDevices {
public:
    static constexpr uint32_t Playback = 1;
    static constexpr uint32_t Capture = 2;

    ~AudioDevices() { uninitialize(); }
    bool initialize(char *error, int capacity);
    void uninitialize();
    uint32_t take_changes();
    void request_change(uint32_t devices);

private:
    struct Notifications;
    IMMDeviceEnumerator *enumerator_ = nullptr;
    Notifications *notifications_ = nullptr;
};
