#include "realms_datagram.h"
#include "realms_internal.h"

#include <array>
#include <cstring>

namespace realms {

namespace {

constexpr size_t kTransportCodecOffset = 0x60;
constexpr size_t kCodecResourceOffset = 0x08;
constexpr size_t kResourceHeaderSize = 0x20;
constexpr size_t kMaximumEngineDatagramSize = 1200;
constexpr size_t kConnectionHeaderSize = 5;
constexpr uint8_t kExtendedLengthThreshold = 247;
constexpr size_t kExtendedLengthBias = 0xf708;

} // namespace

bool DatagramDecoder::initialize(char *error, int error_capacity) {
    void *manager = nullptr;
    void *transport = nullptr;
    void *codec = nullptr;
    void *resource = nullptr;
    if (!current_network_manager(&manager, error, error_capacity) ||
        !read_pointer(static_cast<const uint8_t *>(manager) + kTransportOffset, &transport,
                      "Darktide LAN transport", error, error_capacity) ||
        !read_pointer(static_cast<const uint8_t *>(transport) + kTransportCodecOffset, &codec,
                      "Darktide UDP codec", error, error_capacity) ||
        !read_pointer(static_cast<const uint8_t *>(codec) + kCodecResourceOffset, &resource,
                      "Darktide UDP dictionary resource", error, error_capacity)) {
        return false;
    }
    if (!dtintutils_is_readable_range(resource, kResourceHeaderSize)) {
        return write_error(error, error_capacity, "Darktide UDP dictionary header is unreadable");
    }

    std::array<uint32_t, kResourceHeaderSize / sizeof(uint32_t)> header{};
    std::memcpy(header.data(), resource, kResourceHeaderSize);
    const uint32_t hash_bits = header[2];
    const uint32_t dictionary_size = header[3];
    const uint32_t compacted_offset = header[5];
    const uint32_t compacted_size = header[6];
    const auto *data = static_cast<const uint8_t *>(resource) + kResourceHeaderSize;
    if (dictionary_size == 0 || compacted_offset < dictionary_size || compacted_size == 0 ||
        !dtintutils_is_readable_range(data, dictionary_size) ||
        !dtintutils_is_readable_range(data + compacted_offset, compacted_size)) {
        return write_error(error, error_capacity, "Darktide UDP dictionary layout is invalid");
    }

    const HMODULE oodle = GetModuleHandleW(L"oo2net_9_win64.dll");
    if (oodle == nullptr) {
        return write_error(error, error_capacity, "Darktide Oodle network module is not loaded");
    }
    using StateSizeFunction = intptr_t (*)();
    using SharedSizeFunction = intptr_t (*)(int);
    using UncompactFunction = int (*)(void *, const void *);
    using SetWindowFunction = void (*)(void *, int, const void *, intptr_t);
    const auto state_size = reinterpret_cast<StateSizeFunction>(GetProcAddress(oodle, "OodleNetwork1UDP_State_Size"));
    const auto shared_size = reinterpret_cast<SharedSizeFunction>(GetProcAddress(oodle, "OodleNetwork1_Shared_Size"));
    const auto uncompact = reinterpret_cast<UncompactFunction>(GetProcAddress(oodle, "OodleNetwork1UDP_State_Uncompact"));
    const auto set_window = reinterpret_cast<SetWindowFunction>(GetProcAddress(oodle, "OodleNetwork1_Shared_SetWindow"));
    decode_ = reinterpret_cast<DecodeFunction>(GetProcAddress(oodle, "OodleNetwork1UDP_Decode"));
    if (state_size == nullptr || shared_size == nullptr || uncompact == nullptr || set_window == nullptr ||
        decode_ == nullptr) {
        return write_error(error, error_capacity, "Darktide Oodle network exports are incomplete");
    }

    const intptr_t state_bytes = state_size();
    const intptr_t shared_bytes = shared_size(static_cast<int>(hash_bits));
    if (state_bytes <= 0 || shared_bytes <= 0) {
        return write_error(error, error_capacity, "Darktide Oodle network state sizes are invalid");
    }
    dictionary_.assign(data, data + dictionary_size);
    state_.resize(static_cast<size_t>(state_bytes));
    shared_.resize(static_cast<size_t>(shared_bytes));
    if (uncompact(state_.data(), data + compacted_offset) == 0) {
        return write_error(error, error_capacity, "Darktide UDP dictionary state could not be unpacked");
    }
    set_window(shared_.data(), static_cast<int>(hash_bits), dictionary_.data(), dictionary_size);
    return true;
}

bool DatagramDecoder::read_route(const uint8_t *packet, int packet_size, DatagramRoute *route) const {
    if (packet_size < 2 || packet_size > static_cast<int>(kMaximumEngineDatagramSize)) {
        return false;
    }
    size_t header_size = 1;
    size_t decoded_size = packet[0];
    if (packet[0] > kExtendedLengthThreshold) {
        header_size = 2;
        decoded_size = (static_cast<size_t>(packet[0]) << 8) - kExtendedLengthBias + packet[1];
    }
    const size_t encoded_size = static_cast<size_t>(packet_size) - header_size;
    if (decoded_size < kConnectionHeaderSize || decoded_size > kMaximumEngineDatagramSize ||
        encoded_size > decoded_size) {
        return false;
    }

    std::array<uint8_t, kMaximumEngineDatagramSize> decoded{};
    if (decode_(state_.data(), shared_.data(), packet + header_size, static_cast<intptr_t>(encoded_size),
                decoded.data(), static_cast<intptr_t>(decoded_size)) == 0) {
        return false;
    }
    const uint32_t protocol = static_cast<uint32_t>(decoded[0]) | (static_cast<uint32_t>(decoded[1]) << 8);
    if (protocol != kWireProtocol) {
        return false;
    }
    route->connection_id = static_cast<uint32_t>(decoded[2]) | (static_cast<uint32_t>(decoded[3]) << 8) |
                           (static_cast<uint32_t>(decoded[4]) << 16);
    route->peer_id = 0;
    if (route->connection_id != 0) {
        return true;
    }
    if (decoded_size < kConnectionHeaderSize + sizeof(route->peer_id)) {
        return false;
    }
    std::memcpy(&route->peer_id, decoded.data() + kConnectionHeaderSize, sizeof(route->peer_id));
    return route->peer_id != 0;
}

} // namespace realms
