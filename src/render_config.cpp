#include "render_config.h"
#include "engine.h"
#include <windows.h>
#include <algorithm>
#include <array>
#include <cstdio>
#include <cstring>

namespace goo {
namespace {
constexpr uint32_t MaximumConfigSize = 4u * 1024u * 1024u;
constexpr uint32_t PageSize = 4096;
constexpr uint32_t MaximumEntries = 4096;
constexpr unsigned MaximumDepth = 64;

class ConfigExtent {
  public:
    explicit ConfigExtent(const uint8_t *data) : data_(data) {
    }

    uint32_t size() const {
        return (size_ + 3u) & ~3u;
    }

    bool visit(uint32_t kind, uint32_t value, unsigned depth = 0) {
        if (depth > MaximumDepth) {
            return false;
        }
        if (kind == 1) {
            return value <= 1;
        }
        if (kind == 2 || kind == 3) {
            return true;
        }
        if (kind == 4) {
            return text(value);
        }
        if (kind != 5 && kind != 6) {
            return false;
        }
        return visit_children(kind, value, depth);
    }

  private:
    bool range(uint32_t offset, uint32_t bytes) {
        if (offset > MaximumConfigSize || bytes > MaximumConfigSize - offset) {
            return false;
        }
        const auto base = reinterpret_cast<uintptr_t>(data_) & ~uintptr_t(PageSize - 1);
        const auto first = (reinterpret_cast<uintptr_t>(data_ + offset) - base) / PageSize;
        const auto last =
            (reinterpret_cast<uintptr_t>(data_ + offset + bytes - 1) - base) / PageSize;
        for (auto page = first; page <= last; ++page) {
            if (readable_[page]) {
                continue;
            }
            const auto address = base + page * PageSize;
            MEMORY_BASIC_INFORMATION region{};
            if (VirtualQuery(reinterpret_cast<const void *>(address), &region, sizeof(region)) !=
                sizeof(region)) {
                return false;
            }
            const auto region_begin = reinterpret_cast<uintptr_t>(region.BaseAddress);
            const auto region_end = region_begin + region.RegionSize;
            if (region_begin > address || region_end <= address ||
                !dtintutils_is_readable_range(reinterpret_cast<const void *>(address),
                                              region_end - address)) {
                return false;
            }
            // VirtualQuery describes one region with uniform state and page protection.
            const auto end_page = std::min((region_end - base) / PageSize, readable_.size());
            std::fill(readable_.begin() + page, readable_.begin() + end_page, true);
        }
        size_ = std::max(size_, offset + bytes);
        return true;
    }

    bool text(uint32_t offset) {
        for (uint32_t index = 0; index < PageSize; ++index) {
            if (!range(offset + index, 1)) {
                return false;
            }
            if (!data_[offset + index]) {
                return true;
            }
        }
        return false;
    }

    bool visit_children(uint32_t kind, uint32_t value, unsigned depth) {
        const bool array = kind == 5;
        const uint32_t header = array ? 8u : 4u;
        const uint32_t stride = array ? 4u : 12u;
        if (!range(value, header)) {
            return false;
        }
        const auto count = engine::read<uint32_t>(data_, value + (array ? 4u : 0u));
        if (count > MaximumEntries || !range(value, header + count * stride)) {
            return false;
        }
        for (uint32_t index = 0; index < count; ++index) {
            const auto entry = value + header + index * stride;
            if (array) {
                if (!visit(engine::read<uint32_t>(data_, value),
                           engine::read<uint32_t>(data_, entry), depth + 1)) {
                    return false;
                }
            } else {
                if (!text(engine::read<uint32_t>(data_, entry)) ||
                    !visit(engine::read<uint32_t>(data_, entry + 4),
                           engine::read<uint32_t>(data_, entry + 8), depth + 1)) {
                    return false;
                }
            }
        }
        return true;
    }

    const uint8_t *data_;
    uint32_t size_ = 8;
    std::array<bool, MaximumConfigSize / PageSize + 1> readable_{};
};
} // namespace

const void *RenderConfig::snapshot(uint32_t *size, char *error, int capacity) {
    if (applied) {
        std::snprintf(error, capacity, "Cannot snapshot an active outline config");
        return nullptr;
    }
    void *renderer;
    auto *located = engine::locate_config(error, capacity, &renderer);
    if (!located) {
        return nullptr;
    }
    ConfigExtent extent(located);
    if (!extent.visit(engine::read<uint32_t>(located, 0), engine::read<uint32_t>(located, 4))) {
        std::snprintf(error, capacity, "Invalid live binary render config");
        return nullptr;
    }
    target = located;
    original.assign(target, target + extent.size());
    if (!graph.initialize(renderer, target, extent.size(), error, capacity))
        return nullptr;
    *size = extent.size();
    return original.data();
}

bool RenderConfig::apply(const void *data, uint32_t size, char *error, int capacity) {
    if (!target || applied || size != original.size()) {
        std::snprintf(error, capacity, "Invalid render config activation state or size");
        return false;
    }
    if (std::memcmp(target, original.data(), original.size())) {
        std::snprintf(error, capacity, "Render config changed after snapshot");
        return false;
    }
    const auto *bytes = static_cast<const uint8_t *>(data);
    modified.assign(bytes, bytes + size);
    std::memcpy(target, modified.data(), modified.size());
    if (!graph.rebuild(error, capacity)) {
        std::memcpy(target, original.data(), original.size());
        return false;
    }
    applied = true;
    return true;
}

bool RenderConfig::restore(char *error, int capacity) {
    if (!applied) {
        return true;
    }
    if (std::memcmp(target, modified.data(), modified.size())) {
        std::snprintf(error, capacity, "Render config changed while outline runtime was active");
        return false;
    }
    std::memcpy(target, original.data(), original.size());
    if (!graph.rebuild(error, capacity)) {
        std::memcpy(target, modified.data(), modified.size());
        return false;
    }
    applied = false;
    return true;
}
} // namespace goo
