#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace realms {

struct DatagramRoute {
    uint64_t peer_id = 0;
    uint32_t connection_id = 0;
};

// Owns a snapshot of the engine dictionary, independent of its lifetime and game-thread buffers.
class DatagramDecoder {
public:
    DatagramDecoder() = default;
    DatagramDecoder(const DatagramDecoder &) = delete;
    DatagramDecoder &operator=(const DatagramDecoder &) = delete;
    DatagramDecoder(DatagramDecoder &&) = default;

    bool initialize(char *error, int error_capacity);
    bool read_route(const uint8_t *packet, int packet_size, DatagramRoute *route) const;

private:
    using DecodeFunction = int (*)(const void *, const void *, const void *, intptr_t, void *, intptr_t);
    DecodeFunction decode_ = nullptr;
    std::vector<uint8_t> dictionary_;
    std::vector<uint8_t> state_;
    std::vector<uint8_t> shared_;
};

} // namespace realms
