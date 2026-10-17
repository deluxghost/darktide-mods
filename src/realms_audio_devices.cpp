#include "realms_audio_devices.h"
#include <cstdio>

struct AudioDevices::Notifications final : IMMNotificationClient {
    std::atomic<ULONG> references{1};
    std::atomic<uint32_t> changes{0};

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void **object) override {
        if (object == nullptr) return E_POINTER;
        *object = nullptr;
        if (id != __uuidof(IUnknown) && id != __uuidof(IMMNotificationClient)) return E_NOINTERFACE;
        *object = static_cast<IMMNotificationClient *>(this);
        AddRef();
        return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return references.fetch_add(1) + 1; }
    ULONG STDMETHODCALLTYPE Release() override {
        const ULONG remaining = references.fetch_sub(1) - 1;
        if (remaining == 0) delete this;
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow flow, ERole role, LPCWSTR) override {
        if (role == eConsole && (flow == eRender || flow == eCapture)) {
            changes.fetch_or(flow == eRender ? Playback : Capture);
        }
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR, DWORD) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR, const PROPERTYKEY) override { return S_OK; }
};

bool AudioDevices::initialize(char *error, int capacity) {
    const HRESULT created = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
        __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator_));
    if (FAILED(created)) {
        if (error != nullptr && capacity > 0) std::snprintf(error, capacity, "Could not create the voice device enumerator (0x%08lX)", created);
        return false;
    }
    notifications_ = new Notifications;
    const HRESULT registered = enumerator_->RegisterEndpointNotificationCallback(notifications_);
    if (FAILED(registered)) {
        if (error != nullptr && capacity > 0) std::snprintf(error, capacity, "Could not observe default voice devices (0x%08lX)", registered);
        uninitialize();
        return false;
    }
    return true;
}

void AudioDevices::uninitialize() {
    if (enumerator_ != nullptr) {
        if (notifications_ != nullptr) enumerator_->UnregisterEndpointNotificationCallback(notifications_);
        enumerator_->Release();
        enumerator_ = nullptr;
    }
    if (notifications_ != nullptr) {
        notifications_->Release();
        notifications_ = nullptr;
    }
}

uint32_t AudioDevices::take_changes() {
    return notifications_ == nullptr ? 0 : notifications_->changes.exchange(0);
}

void AudioDevices::request_change(uint32_t devices) {
    if (notifications_ != nullptr) notifications_->changes.fetch_or(devices);
}
