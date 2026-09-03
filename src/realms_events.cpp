#include "realms_internal.h"

#include <atomic>
#include <cstdio>
#include <deque>
#include <mutex>

namespace realms {

namespace {

constexpr size_t kMaximumQueuedEvents = 64;

std::deque<RealmsRuntimeEvent> g_events;
std::mutex g_events_mutex;
std::atomic<uint32_t> g_dropped_event_count{0};

RealmsRuntimeEvent make_event(RealmsRuntimeEventType type, RealmsRuntimeEventCode code, uint64_t peer_id,
                              uint32_t channel_id, const char *message) {
    RealmsRuntimeEvent event{};
    event.struct_size = sizeof(event);
    event.type = static_cast<uint32_t>(type);
    if (peer_id != 0) {
        std::snprintf(event.peer_id, sizeof(event.peer_id), "%016llx", static_cast<unsigned long long>(peer_id));
    }
    event.channel_id = channel_id;
    event.code = static_cast<int32_t>(code);
    std::snprintf(event.message, sizeof(event.message), "%s", message != nullptr ? message : "");
    return event;
}

} // namespace

void clear_runtime_events() {
    std::lock_guard<std::mutex> lock(g_events_mutex);
    g_events.clear();
    g_dropped_event_count.store(0, std::memory_order_relaxed);
}

void push_runtime_event(RealmsRuntimeEventType type, RealmsRuntimeEventCode code, uint64_t peer_id, uint32_t channel_id,
                        const char *message) {
    std::lock_guard<std::mutex> lock(g_events_mutex);
    if (g_events.size() >= kMaximumQueuedEvents) {
        g_dropped_event_count.fetch_add(1, std::memory_order_relaxed);
        return;
    }

    g_events.push_back(make_event(type, code, peer_id, channel_id, message));
}

int poll_runtime_event(RealmsRuntimeEvent *event, char *error, int error_capacity) {
    if (event == nullptr || !dtintutils_is_writable_range(event, sizeof(*event))) {
        write_error(error, error_capacity, "Event output is not writable");
        return -1;
    }
    if (event->struct_size != sizeof(*event)) {
        write_error(error, error_capacity, "Event structure size does not match the Realms ABI");
        return -1;
    }

    const uint32_t dropped = g_dropped_event_count.exchange(0, std::memory_order_acq_rel);
    if (dropped != 0) {
        char message[REALMS_RUNTIME_EVENT_MESSAGE_CAPACITY]{};
        std::snprintf(message, sizeof(message), "Realms event queue dropped %u events", dropped);
        *event = make_event(REALMS_RUNTIME_EVENT_ERROR, REALMS_RUNTIME_ERROR_EVENT_OVERFLOW, 0, 0, message);
        return 1;
    }

    std::lock_guard<std::mutex> lock(g_events_mutex);
    if (g_events.empty()) {
        return 0;
    }

    *event = g_events.front();
    g_events.pop_front();
    return 1;
}

} // namespace realms
