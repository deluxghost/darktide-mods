#include "realms_internal.h"

#include <algorithm>
#include <array>
#include <cstdio>
#include <cstring>
#include <deque>
#include <map>
#include <new>
#include <vector>

using namespace realms;

namespace {

constexpr uint32_t kBinarySystem = 15;
constexpr uint32_t kWireVersion = 1;
constexpr uint32_t kFrameSize = 1024;
constexpr uint32_t kHeaderSize = 33;
constexpr uint32_t kMaximumMessageSize = 4 * 1024 * 1024;
constexpr uint32_t kMaximumControlSize = 96 * 1024;
constexpr size_t kMaximumQueuedBytes = 64 * 1024 * 1024;
constexpr size_t kMaximumChannelBytes = 8 * 1024 * 1024;
constexpr size_t kGlobalControlReserveBytes = 4 * 1024 * 1024;
constexpr size_t kMaximumQueuedMessages = 4096;
constexpr size_t kMaximumChannelMessages = 1024;
constexpr size_t kControlReserveMessages = 16;
constexpr uint32_t kSendRate = 64 * 1024;
constexpr uint32_t kSendBurst = 4 * 1024;
constexpr uint32_t kReliableReserve = 8 * 1024;
constexpr uint32_t kEngineFrameOverhead = 32;
constexpr size_t kReliableCapacityOffset = 0x2088;
constexpr size_t kReliableReadOffset = 0x20a0;
constexpr size_t kReliableWriteOffset = 0x20a4;
constexpr size_t kReliableUsedOffset = 0x20a8;
constexpr size_t kUnreliableCapacityOffset = 0x20b0;
constexpr size_t kUnreliableUsedOffset = 0x20d0;
constexpr uint64_t kReassemblyTimeout = 30000;
constexpr size_t kControlLane = 0;
constexpr size_t kBulkLane = 1;
constexpr size_t kUnreliableLane = 0;

struct Message {
    uint64_t sender = 0;
    uint64_t recipient = 0;
    uint64_t tick = 0;
    uint32_t channel = 0;
    uint32_t type = 0;
    uint32_t id = 0;
    uint32_t offset = 0;
    bool reliable = false;
    std::vector<uint8_t> payload;
};

struct Assembly {
    Message message;
    uint32_t total = 0;
    bool active = false;
};

struct Channel {
    uint64_t peer = 0;
    uint64_t context = 0;
    uint64_t last_update = 0;
    uint32_t listener = 0;
    uint32_t next_message = 0;
    double tokens = kSendBurst;
    size_t queued_bytes = 0;
    size_t queued_messages = 0;
    bool is_host = false;
    bool prefer_unreliable = true;
    char failure[160]{};
    std::array<std::deque<Message>, 2> outgoing;
    std::array<Assembly, 2> incoming;
    uint64_t sent_messages = 0;
    uint64_t received_messages = 0;
    uint64_t expired_messages = 0;
};

BinaryConnectionMethods methods;
std::mutex data_mutex;
std::map<uint32_t, Channel> channels;
std::array<std::deque<Message>, 2> received;
size_t receive_messages = 0;
size_t queued_bytes = 0;
size_t receive_bytes = 0;
uint32_t next_context = 1;
std::atomic<bool> pending_work{false};
std::atomic<bool> pending_receive{false};

bool fail(Channel &channel, const char *reason) {
    if (channel.failure[0] == '\0') {
        std::snprintf(channel.failure, sizeof(channel.failure), "%s", reason);
    }
    pending_work.store(true, std::memory_order_release);
    return false;
}

bool validate_connection(char *error, int capacity) {
    void *manager = nullptr;
    void *current = nullptr;
    void *vtable = nullptr;
    if (!current_network_manager(&manager, error, capacity) ||
        !read_pointer(static_cast<const uint8_t *>(manager) + kConnectionOffset, &current,
                      "Binary Connection", error, capacity) ||
        !read_pointer(static_cast<const uint8_t *>(current), &vtable, "Binary Connection", error, capacity)) {
        return false;
    }
    return (current == methods.connection && vtable == methods.vtable) ||
           write_error(error, capacity, "Binary transport Connection changed before channel cleanup");
}

uint32_t frame_capacity(uint64_t peer) {
    void *endpoint = methods.peer_endpoint(methods.connection, peer);
    return endpoint == nullptr ? 0 : std::min(kFrameSize, methods.message_size(endpoint));
}

template <typename T>
void pack(uint8_t *&cursor, T value) {
    std::memcpy(cursor, &value, sizeof(value));
    cursor += sizeof(value);
}

uint32_t read_bits(void *reader, uint32_t bits) {
    return static_cast<uint32_t>(methods.read_bits(static_cast<int32_t *>(reader), bits));
}

uint64_t read_peer(void *reader) {
    const uint64_t low = read_bits(reader, 32);
    return low | (static_cast<uint64_t>(read_bits(reader, 32)) << 32);
}

bool complete(Channel &channel, Message &&message) {
    const size_t limit = kMaximumQueuedMessages - (message.type == 0 ? 0 : kControlReserveMessages * kMaximumRemotePeers);
    if (receive_messages >= limit) {
        return fail(channel, "Binary receive queue is full");
    }
    received[message.type == 0 ? kControlLane : kBulkLane].push_back(std::move(message));
    ++receive_messages;
    ++channel.received_messages;
    pending_receive.store(true, std::memory_order_release);
    return true;
}

bool receive_frame(Channel &channel, uint32_t channel_id, int32_t kind, void *reader) {
    if ((kind != 0 && kind != 1) || !reader_succeeded(reader) || read_bits(reader, 2) != kWireVersion) {
        return fail(channel, "Binary frame type or version is invalid");
    }
    Message frame;
    frame.channel = channel_id;
    frame.reliable = kind == 0;
    frame.type = read_bits(reader, 16);
    frame.id = read_bits(reader, 32);
    frame.sender = read_peer(reader);
    frame.recipient = read_peer(reader);
    const uint32_t total = read_bits(reader, 32);
    const uint32_t offset = read_bits(reader, 32);
    const uint32_t size = read_bits(reader, 16);
    if (!reader_succeeded(reader) || frame.sender == 0 || frame.id == 0 || total > kMaximumMessageSize ||
        size > kFrameSize - kHeaderSize || offset > total || size > total - offset ||
        (total != 0 && size == 0) || (frame.type == 0 && (!frame.reliable || total > kMaximumControlSize)) ||
        (channel.is_host && frame.sender != channel.peer) ||
        (!frame.reliable && (offset != 0 || size != total))) {
        return fail(channel, "Binary frame header is invalid");
    }

    frame.payload.resize(size);
    uint32_t index = 0;
    for (; size - index >= sizeof(uint32_t); index += sizeof(uint32_t)) {
        const uint32_t word = read_bits(reader, 32);
        std::memcpy(frame.payload.data() + index, &word, sizeof(word));
    }
    for (; index < size; ++index) {
        frame.payload[index] = static_cast<uint8_t>(read_bits(reader, 8));
    }
    if (!reader_succeeded(reader)) {
        return fail(channel, "Binary frame payload is truncated");
    }

    const uint64_t now = GetTickCount64();
    if (!frame.reliable) {
        if (receive_bytes > kMaximumQueuedBytes - kGlobalControlReserveBytes ||
            size > kMaximumQueuedBytes - kGlobalControlReserveBytes - receive_bytes) {
            return fail(channel, "Binary receive memory limit exceeded");
        }
        if (!complete(channel, std::move(frame))) {
            return false;
        }
        receive_bytes += size;
        return true;
    }

    Assembly &assembly = channel.incoming[frame.type == 0 ? kControlLane : kBulkLane];
    if (!assembly.active) {
        const size_t limit = kMaximumQueuedBytes - (frame.type == 0 ? 0 : kGlobalControlReserveBytes);
        if (offset != 0 || receive_bytes > limit || total > limit - receive_bytes) {
            return fail(channel, "Binary message start or receive capacity is invalid");
        }
        assembly.message = frame;
        assembly.message.payload.clear();
        assembly.message.payload.reserve(total);
        assembly.total = total;
        assembly.active = true;
        receive_bytes += total;
    }
    Message &message = assembly.message;
    if (message.id != frame.id || message.type != frame.type || message.sender != frame.sender ||
        message.recipient != frame.recipient || assembly.total != total || message.payload.size() != offset) {
        return fail(channel, "Binary message fragments are inconsistent or out of order");
    }
    message.payload.insert(message.payload.end(), frame.payload.begin(), frame.payload.end());
    message.tick = now;
    if (message.payload.size() == total) {
        if (!complete(channel, std::move(message))) {
            return false;
        }
        assembly = {};
    }
    pending_work.store(true, std::memory_order_release);
    return true;
}

uint64_t __fastcall receive_callback(void *context, uint64_t, uint64_t peer, uint64_t channel_id, uint64_t,
                                      uint64_t, int32_t kind, void *reader) {
    std::lock_guard<std::mutex> lock(data_mutex);
    const uint64_t identity = reinterpret_cast<uintptr_t>(context);
    auto it = channels.find(static_cast<uint32_t>(identity));
    if (it == channels.end() || it->second.context != identity) {
        return 1;
    }
    Channel &channel = it->second;
    if (channel.failure[0] != '\0') {
        return 2;
    }
    if (channel.peer != peer || it->first != channel_id) {
        fail(channel, "Binary callback peer or channel does not match its registration");
        return 2;
    }
    try {
        return receive_frame(channel, it->first, kind, reader) ? 0 : 2;
    } catch (const std::bad_alloc &) {
        fail(channel, "Could not allocate binary receive memory");
        return 2;
    }
}

void discard_channel(uint32_t id, Channel &channel) {
    methods.remove_listener(methods.connection, channel.listener);
    queued_bytes -= channel.queued_bytes;
    for (const Assembly &assembly : channel.incoming) {
        if (assembly.active) {
            receive_bytes -= assembly.total;
        }
    }
    for (auto &queue : received) {
        for (auto it = queue.begin(); it != queue.end();) {
            if (it->channel == id) {
                receive_bytes -= it->payload.size();
                --receive_messages;
                it = queue.erase(it);
            } else {
                ++it;
            }
        }
    }
    pending_receive.store(receive_messages != 0, std::memory_order_release);
}

bool send_frame(uint32_t id, Channel &channel, Message &message, uint32_t size) {
    std::array<uint8_t, kFrameSize> packet{};
    uint8_t *cursor = packet.data();
    pack(cursor, static_cast<uint8_t>((kWireVersion << 6) | (message.reliable ? 0 : 1)));
    pack(cursor, static_cast<uint16_t>(message.type));
    pack(cursor, message.id);
    pack(cursor, message.sender);
    pack(cursor, message.recipient);
    pack(cursor, static_cast<uint32_t>(message.payload.size()));
    pack(cursor, message.offset);
    pack(cursor, static_cast<uint16_t>(size));
    if (size != 0) {
        std::memcpy(cursor, message.payload.data() + message.offset, size);
    }
    if ((methods.send(methods.connection, id, kBinarySystem, message.reliable ? 1 : 0, packet.data(),
                       (kHeaderSize + size) * 8, nullptr) & 0xff) == 0) {
        return fail(channel, "Engine rejected a binary frame send");
    }
    message.offset += size;
    return true;
}

bool send_control(uint32_t id, Channel &channel, Message &message, char *error, int error_capacity) {
    if (!validate_connection(error, error_capacity)) {
        return false;
    }
    const uint32_t capacity = frame_capacity(channel.peer);
    if (!methods.is_connected(methods.connection, channel.peer) || capacity <= kHeaderSize) {
        return write_error(error, error_capacity, "Binary control peer or frame capacity is unavailable");
    }
    const size_t frames = std::max<size_t>(1, (message.payload.size() + capacity - kHeaderSize - 1) / (capacity - kHeaderSize));
    // Control must enter the engine queue before the following Lua RPC, never behind bulk throttling.
    const size_t required = message.payload.size() + frames * (kHeaderSize + kEngineFrameOverhead) + kReliableReserve;
    const auto *endpoint = static_cast<const uint8_t *>(methods.peer_endpoint(methods.connection, channel.peer));
    if (endpoint == nullptr || !dtintutils_is_readable_range(endpoint + kReliableCapacityOffset,
                                                          kReliableUsedOffset - kReliableCapacityOffset + sizeof(uint32_t))) {
        return write_error(error, error_capacity, "Engine reliable queue is unreadable");
    }
    uint32_t queue_capacity = 0;
    uint32_t read = 0;
    uint32_t write = 0;
    uint32_t used = 0;
    std::memcpy(&queue_capacity, endpoint + kReliableCapacityOffset, sizeof(queue_capacity));
    std::memcpy(&read, endpoint + kReliableReadOffset, sizeof(read));
    std::memcpy(&write, endpoint + kReliableWriteOffset, sizeof(write));
    std::memcpy(&used, endpoint + kReliableUsedOffset, sizeof(used));
    if (read > queue_capacity || write > queue_capacity || used > queue_capacity) {
        return write_error(error, error_capacity, "Engine reliable queue has invalid accounting");
    }
    // The public buffer-left query is a flow-control window, not the storage available to enqueue RPCs.
    const uint32_t space = std::min(queue_capacity - used, write < read ? read - write : queue_capacity - write + read);
    if (space < required) {
        char reason[160]{};
        std::snprintf(reason, sizeof(reason), "Engine reliable queue needs %zu bytes including RPC reserve; %u are available", required, space);
        return write_error(error, error_capacity, reason);
    }
    do {
        const uint32_t size = std::min<uint32_t>(static_cast<uint32_t>(message.payload.size()) - message.offset, capacity - kHeaderSize);
        if (!send_frame(id, channel, message, size)) {
            return write_error(error, error_capacity, channel.failure);
        }
    } while (message.offset < message.payload.size());
    ++channel.sent_messages;
    return true;
}

bool flush_channel(uint32_t id, Channel &channel, uint64_t now) {
    for (const Assembly &assembly : channel.incoming) {
        if (assembly.active && now - assembly.message.tick > kReassemblyTimeout) {
            return fail(channel, "Binary message reassembly timed out");
        }
    }
    channel.tokens = std::min<double>(kSendBurst, channel.tokens +
                                    static_cast<double>(now - channel.last_update) * kSendRate / 1000.0);
    channel.last_update = now;
    if (channel.queued_messages == 0) {
        return true;
    }
    if (!methods.is_connected(methods.connection, channel.peer)) {
        return fail(channel, "Binary peer disconnected before queued data was sent");
    }
    const uint32_t capacity = frame_capacity(channel.peer);
    if (capacity <= kHeaderSize) {
        return fail(channel, "Binary frame does not fit the engine message limit");
    }

    while (channel.queued_messages != 0) {
        auto &datagrams = channel.outgoing[kUnreliableLane];
        while (!datagrams.empty() && now >= datagrams.front().tick) {
            const size_t size = datagrams.front().payload.size();
            queued_bytes -= size;
            channel.queued_bytes -= size;
            --channel.queued_messages;
            ++channel.expired_messages;
            datagrams.pop_front();
        }
        const size_t lane = !datagrams.empty() && (channel.prefer_unreliable || channel.outgoing[kBulkLane].empty())
                                ? kUnreliableLane : kBulkLane;
        auto &queue = channel.outgoing[lane];
        if (queue.empty()) {
            break;
        }
        Message &message = queue.front();
        const uint32_t remaining = static_cast<uint32_t>(message.payload.size()) - message.offset;
        const uint32_t size = std::min(remaining, capacity - kHeaderSize);
        const uint32_t packet_size = kHeaderSize + size;
        if (!message.reliable && size != remaining) {
            return fail(channel, "Unreliable binary frame exceeds the current engine message limit");
        }
        if (channel.tokens < packet_size ||
            methods.buffer_left(methods.connection, channel.peer) < kReliableReserve + packet_size * 2) {
            break;
        }
        if (!message.reliable) {
            const auto *endpoint = static_cast<const uint8_t *>(methods.peer_endpoint(methods.connection, channel.peer));
            if (endpoint == nullptr || !dtintutils_is_readable_range(endpoint + kUnreliableUsedOffset, sizeof(uint32_t))) {
                return fail(channel, "Binary unreliable Endpoint queue is unreadable");
            }
            uint32_t queue_capacity = 0;
            uint32_t used = 0;
            std::memcpy(&queue_capacity, endpoint + kUnreliableCapacityOffset, sizeof(queue_capacity));
            std::memcpy(&used, endpoint + kUnreliableUsedOffset, sizeof(used));
            if (used > queue_capacity) {
                return fail(channel, "Binary unreliable Endpoint queue has invalid accounting");
            }
            if (queue_capacity - used < std::min(kReliableReserve, queue_capacity / 2) + packet_size * 2) {
                break;
            }
        }
        if (!send_frame(id, channel, message, size)) {
            return false;
        }
        channel.tokens -= packet_size;
        channel.prefer_unreliable = lane != kUnreliableLane;
        if (message.offset == message.payload.size()) {
            queued_bytes -= message.payload.size();
            channel.queued_bytes -= message.payload.size();
            --channel.queued_messages;
            ++channel.sent_messages;
            queue.pop_front();
        }
    }
    return true;
}

} // namespace

int RealmsRuntime_AttachBinaryChannel(uint32_t id, const char *peer_text, int is_host, char *error, int capacity) {
    uint64_t peer = 0;
    if (id == 0 || (is_host != 0 && is_host != 1) ||
        !parse_hex_id(peer_text, &peer, "Binary peer ID", error, capacity) || peer == 0) {
        write_error(error, capacity, "Binary channel identity is invalid");
        return 0;
    }
    std::lock_guard<std::mutex> lock(data_mutex);
    auto existing = channels.find(id);
    if (existing != channels.end()) {
        return (existing->second.peer == peer && existing->second.is_host == (is_host != 0)) ? 1 :
               static_cast<int>(write_error(error, capacity, "Binary channel is already attached to another peer"));
    }
    if (channels.size() >= kMaximumRemotePeers || next_context == 0) {
        write_error(error, capacity, "Binary channel registration capacity exceeded");
        return 0;
    }
    if (channels.empty()) {
        if (!resolve_binary_connection(&methods, error, capacity)) {
            return 0;
        }
    } else if (!validate_connection(error, capacity)) {
        return 0;
    }
    try {
        auto inserted = channels.try_emplace(id);
        Channel &channel = inserted.first->second;
        channel.peer = peer;
        channel.is_host = is_host != 0;
        channel.context = (static_cast<uint64_t>(next_context++) << 32) | id;
        channel.last_update = GetTickCount64();
        // The callback context is an identity, not an object pointer: deferred removal cannot leave a dangling object.
        methods.register_listener(methods.connection, &channel.listener, kBinarySystem, id, receive_callback,
                                  reinterpret_cast<void *>(static_cast<uintptr_t>(channel.context)));
        if (channel.listener == 0) {
            channels.erase(inserted.first);
            write_error(error, capacity, "Engine rejected the binary channel listener");
            return 0;
        }
        return 1;
    } catch (const std::bad_alloc &) {
        auto partial = channels.find(id);
        if (partial != channels.end()) {
            if (partial->second.listener != 0) {
                methods.remove_listener(methods.connection, partial->second.listener);
            }
            channels.erase(partial);
        }
        write_error(error, capacity, "Could not allocate binary channel state");
        return 0;
    }
}

int RealmsRuntime_DetachBinaryChannel(uint32_t id, char *error, int capacity) {
    std::lock_guard<std::mutex> lock(data_mutex);
    auto it = channels.find(id);
    if (it == channels.end()) {
        return 1;
    }
    if (!validate_connection(error, capacity)) {
        return 0;
    }
    discard_channel(id, it->second);
    channels.erase(it);
    if (channels.empty()) {
        methods = {};
        pending_work.store(false, std::memory_order_release);
    }
    return 1;
}

int RealmsRuntime_SendBinary(uint32_t id, const char *sender_text, const char *recipient_text, uint32_t type,
                             int reliable, const void *payload, uint32_t size, uint32_t lifetime,
                             uint32_t *message_id, char *error, int capacity) {
    uint64_t sender = 0;
    uint64_t recipient = 0;
    if (message_id == nullptr || type > UINT16_MAX || (reliable != 0 && reliable != 1) ||
        (size != 0 && payload == nullptr) || size > kMaximumMessageSize || (type == 0 && size > kMaximumControlSize) ||
        (reliable == 0 && (size > kFrameSize - kHeaderSize || type == 0 || lifetime == 0)) ||
        (reliable != 0 && lifetime != 0)) {
        write_error(error, capacity, "Binary send arguments or payload size are invalid");
        return 0;
    }
    if (!parse_hex_id(sender_text, &sender, "Binary sender ID", error, capacity) ||
        !parse_hex_id(recipient_text, &recipient, "Binary recipient ID", error, capacity)) {
        return 0;
    }
    if (sender == 0) {
        write_error(error, capacity, "Binary sender ID must not be zero");
        return 0;
    }
    std::lock_guard<std::mutex> lock(data_mutex);
    auto it = channels.find(id);
    if (it == channels.end()) {
        write_error(error, capacity, "Binary channel is not attached");
        return 0;
    }
    Channel &channel = it->second;
    if (channel.failure[0] != '\0') {
        write_error(error, capacity, channel.failure);
        return 0;
    }
    const bool control = type == 0;
    if (!control && (size > kMaximumChannelBytes - channel.queued_bytes || size > kMaximumQueuedBytes - queued_bytes ||
                     channel.queued_messages >= kMaximumChannelMessages)) {
        write_error(error, capacity, "Binary send queue is full");
        return 0;
    }
    try {
        Message message;
        message.sender = sender;
        message.recipient = recipient;
        message.channel = id;
        message.type = type;
        message.id = channel.next_message + 1;
        if (message.id == 0) {
            message.id = 1;
        }
        message.reliable = reliable != 0;
        message.tick = GetTickCount64() + lifetime;
        if (size != 0) {
            const auto *bytes = static_cast<const uint8_t *>(payload);
            message.payload.assign(bytes, bytes + size);
        }
        if (control) {
            if (!send_control(id, channel, message, error, capacity)) {
                return 0;
            }
            channel.next_message = message.id;
            *message_id = message.id;
            return 1;
        }
        const size_t lane = reliable != 0 ? kBulkLane : kUnreliableLane;
        channel.outgoing[lane].push_back(std::move(message));
        channel.next_message = channel.outgoing[lane].back().id;
        channel.queued_bytes += size;
        ++channel.queued_messages;
        queued_bytes += size;
        *message_id = channel.next_message;
        pending_work.store(true, std::memory_order_release);
        return 1;
    } catch (const std::bad_alloc &) {
        write_error(error, capacity, "Could not allocate binary send memory");
        return 0;
    }
}

int RealmsRuntime_UpdateBinary(uint32_t *failed_channel, char *error, int capacity) {
    if (failed_channel == nullptr) {
        write_error(error, capacity, "Binary update output is null");
        return 0;
    }
    *failed_channel = 0;
    if (!pending_work.load(std::memory_order_acquire)) {
        return 1;
    }
    std::lock_guard<std::mutex> lock(data_mutex);
    if (channels.empty()) {
        pending_work.store(false, std::memory_order_release);
        return 1;
    }
    *failed_channel = channels.begin()->first;
    if (!validate_connection(error, capacity)) {
        return 0;
    }
    const uint64_t now = GetTickCount64();
    bool work = false;
    for (auto &entry : channels) {
        Channel &channel = entry.second;
        if (channel.failure[0] != '\0' || !flush_channel(entry.first, channel, now)) {
            *failed_channel = entry.first;
            write_error(error, capacity, channel.failure);
            return 0;
        }
        work = work || channel.queued_messages != 0;
        for (const Assembly &assembly : channel.incoming) {
            work = work || assembly.active;
        }
    }
    *failed_channel = 0;
    pending_work.store(work, std::memory_order_release);
    return 1;
}

int RealmsRuntime_PollBinary(uint32_t control_channel, uint32_t message_id, RealmsBinaryMessage *output, void *payload, uint32_t capacity, char *error,
                             int error_capacity) {
    if (!pending_receive.load(std::memory_order_acquire)) {
        return 0;
    }
    if (output == nullptr || output->struct_size != sizeof(*output) || (control_channel == 0) != (message_id == 0)) {
        write_error(error, error_capacity, "Binary receive output has an invalid structure size");
        return -1;
    }
    std::lock_guard<std::mutex> lock(data_mutex);
    auto &queue = received[control_channel == 0 ? kBulkLane : kControlLane];
    auto next = control_channel == 0 ? queue.begin() :
                std::find_if(queue.begin(), queue.end(), [control_channel](const Message &message) { return message.channel == control_channel; });
    if (next == queue.end()) {
        return 0;
    }
    const Message &message = *next;
    if (control_channel != 0 && message.id != message_id) {
        write_error(error, error_capacity, "Binary control wakeup is out of order");
        return -1;
    }
    output->channel_id = message.channel;
    output->message_type = message.type;
    output->message_id = message.id;
    output->reliable = message.reliable ? 1 : 0;
    output->payload_size = static_cast<uint32_t>(message.payload.size());
    std::snprintf(output->sender_peer_id, sizeof(output->sender_peer_id), "%016llx", message.sender);
    std::snprintf(output->recipient_peer_id, sizeof(output->recipient_peer_id), "%016llx", message.recipient);
    if (capacity < message.payload.size() || (payload == nullptr && !message.payload.empty())) {
        write_error(error, error_capacity, "Binary receive buffer is too small");
        return -2;
    }
    if (!message.payload.empty()) {
        std::memcpy(payload, message.payload.data(), message.payload.size());
    }
    receive_bytes -= message.payload.size();
    queue.erase(next);
    --receive_messages;
    pending_receive.store(receive_messages != 0, std::memory_order_release);
    return 1;
}

int RealmsRuntime_BinaryStats(uint32_t id, RealmsBinaryStats *stats, char *error, int capacity) {
    if (stats == nullptr || stats->struct_size != sizeof(*stats)) {
        write_error(error, capacity, "Binary statistics output has an invalid structure size");
        return 0;
    }
    std::lock_guard<std::mutex> lock(data_mutex);
    auto it = channels.find(id);
    if (it == channels.end()) {
        write_error(error, capacity, "Binary channel is not attached");
        return 0;
    }
    const Channel &channel = it->second;
    stats->queued_messages = static_cast<uint32_t>(channel.queued_messages);
    stats->queued_bytes = channel.queued_bytes;
    stats->sent_messages = channel.sent_messages;
    stats->received_messages = channel.received_messages;
    stats->expired_messages = channel.expired_messages;
    return 1;
}
