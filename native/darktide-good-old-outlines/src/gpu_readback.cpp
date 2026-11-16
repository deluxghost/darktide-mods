#include "gpu_readback.h"
#include <windows.h>
#include <dxgi.h>
#include <wrl/client.h>
#include <array>
#include <atomic>
#include <cstdio>
#include <mutex>
#include <unordered_set>

namespace goo::gpu_readback {
namespace {
using Microsoft::WRL::ComPtr;
using SetPipeline = void (STDMETHODCALLTYPE *)(ID3D12GraphicsCommandList *, ID3D12PipelineState *);
using Execute = void (STDMETHODCALLTYPE *)(ID3D12CommandQueue *, UINT, ID3D12CommandList *const *);
constexpr size_t SetPipelineSlot = 25;
constexpr size_t ExecuteSlot = 10;
constexpr DWORD FenceTimeout = 5000;
constexpr size_t ReadbackBytes = 2 * sizeof(uint32_t);

struct HookSlot {
    void **address = nullptr;
    void *original = nullptr;
    void *replacement = nullptr;
};

struct Frame {
    ComPtr<ID3D12CommandAllocator> allocator;
    ComPtr<ID3D12GraphicsCommandList> commands;
    ComPtr<ID3D12Resource> readback;
    uint64_t completion = 0;
};

struct Monitor {
    std::atomic<bool> active{false};
    std::atomic<unsigned> callbacks{0};
    std::atomic<const char *> failure{nullptr};
    char message[256]{};
    std::mutex work_mutex, submission_mutex, pipelines_mutex;
    std::unordered_set<ID3D12PipelineState *> pipelines;
    std::unordered_set<ID3D12CommandList *> marked_lists;
    std::array<std::atomic<uint64_t>, 16> filter{};
    std::array<Frame, 8> frames;
    ComPtr<ID3D12Resource> source;
    ComPtr<ID3D12Fence> fence;
    HANDLE event = nullptr;
    uint64_t next_completion = 0;
    HookSlot set_pipeline, execute;
};

Monitor monitor;

struct Callback {
    Callback() { monitor.callbacks.fetch_add(1, std::memory_order_acquire); }
    ~Callback() { monitor.callbacks.fetch_sub(1, std::memory_order_release); }
};

size_t filter_bit(ID3D12PipelineState *pipeline) {
    const auto value = reinterpret_cast<uintptr_t>(pipeline);
    return ((value >> 4) ^ (value >> 17)) & 1023;
}

bool exchange_slot(void **slot, void *expected, void *replacement, char *message, int capacity) {
    DWORD protection;
    if (!VirtualProtect(slot, sizeof(void *), PAGE_READWRITE, &protection)) {
        std::snprintf(message, capacity, "Cannot write GPU readback hook: %lu", GetLastError());
        return false;
    }
    auto *previous = InterlockedCompareExchangePointer(reinterpret_cast<void *volatile *>(slot), replacement, expected);
    DWORD ignored;
    const BOOL restored = VirtualProtect(slot, sizeof(void *), protection, &ignored);
    FlushInstructionCache(GetCurrentProcess(), slot, sizeof(void *));
    if (!restored || previous != expected) {
        std::snprintf(message, capacity, "GPU readback hook protection or ownership changed");
        return false;
    }
    return true;
}

bool install_slot(HookSlot &hook, void **table, size_t index, void *replacement, char *message, int capacity) {
    hook.address = table + index;
    hook.original = *hook.address;
    hook.replacement = replacement;
    if (exchange_slot(hook.address, hook.original, replacement, message, capacity)) return true;
    if (*hook.address != replacement) hook.address = nullptr;
    return false;
}

void fail(const char *stage, HRESULT result) {
    if (monitor.failure.load(std::memory_order_acquire)) return;
    std::snprintf(monitor.message, sizeof(monitor.message), "Layered outline readback %s failed: 0x%08lx",
        stage, static_cast<unsigned long>(result));
    monitor.failure.store(monitor.message, std::memory_order_release);
}

void read_completed() {
    const auto completed = monitor.fence->GetCompletedValue();
    if (completed == UINT64_MAX) {
        fail("device", DXGI_ERROR_DEVICE_REMOVED);
        return;
    }
    for (auto &frame : monitor.frames) {
        if (!frame.completion || frame.completion > completed) continue;
        void *mapped = nullptr;
        const D3D12_RANGE range{0, ReadbackBytes};
        const auto result = frame.readback->Map(0, &range, &mapped);
        if (FAILED(result)) {
            fail("map", result);
            return;
        }
        const auto *values = static_cast<const uint32_t *>(mapped);
        const uint32_t count = values[0], overflow = values[1];
        const D3D12_RANGE written{0, 0};
        frame.readback->Unmap(0, &written);
        frame.completion = 0;
        if (overflow && !monitor.failure.load(std::memory_order_acquire)) {
            std::snprintf(monitor.message, sizeof(monitor.message),
                "Layered outline fragment buffer exhausted (%u fragments)", count);
            monitor.failure.store(monitor.message, std::memory_order_release);
        }
    }
}

bool wait_for(uint64_t value, char *message, int capacity) {
    if (!value || monitor.fence->GetCompletedValue() >= value) return true;
    const auto result = monitor.fence->SetEventOnCompletion(value, monitor.event);
    if (FAILED(result) || WaitForSingleObject(monitor.event, FenceTimeout) != WAIT_OBJECT_0) {
        std::snprintf(message, capacity, "Layered outline GPU readback fence did not complete");
        return false;
    }
    return true;
}

void submit_readback(ID3D12CommandQueue *queue) {
    std::lock_guard<std::mutex> lock(monitor.work_mutex);
    read_completed();
    if (monitor.failure.load(std::memory_order_acquire)) return;
    Frame *available = nullptr;
    uint64_t oldest = UINT64_MAX;
    for (auto &frame : monitor.frames) {
        if (!frame.completion) { available = &frame; break; }
        if (frame.completion < oldest) { oldest = frame.completion; available = &frame; }
    }
    if (available->completion) {
        if (!wait_for(oldest, monitor.message, sizeof(monitor.message))) {
            monitor.failure.store(monitor.message, std::memory_order_release);
            return;
        }
        read_completed();
        if (monitor.failure.load(std::memory_order_acquire)) return;
    }
    ID3D12CommandList *commands = available->commands.Get();
    reinterpret_cast<Execute>(monitor.execute.original)(queue, 1, &commands);
    available->completion = ++monitor.next_completion;
    const auto result = queue->Signal(monitor.fence.Get(), available->completion);
    if (FAILED(result)) fail("signal", result);
}

void STDMETHODCALLTYPE set_pipeline(ID3D12GraphicsCommandList *commands, ID3D12PipelineState *pipeline) {
    Callback callback;
    reinterpret_cast<SetPipeline>(monitor.set_pipeline.original)(commands, pipeline);
    if (!monitor.active.load(std::memory_order_acquire)) return;
    const auto bit = filter_bit(pipeline);
    if (!(monitor.filter[bit / 64].load(std::memory_order_relaxed) & (uint64_t(1) << (bit % 64)))) return;
    std::lock_guard<std::mutex> lock(monitor.pipelines_mutex);
    if (monitor.pipelines.contains(pipeline)) monitor.marked_lists.insert(commands);
}

void STDMETHODCALLTYPE execute(ID3D12CommandQueue *queue, UINT count, ID3D12CommandList *const *commands) {
    Callback callback;
    const auto original = reinterpret_cast<Execute>(monitor.execute.original);
    if (!monitor.active.load(std::memory_order_acquire)) { original(queue, count, commands); return; }
    std::lock_guard<std::mutex> submission(monitor.submission_mutex);
    bool contains_composite = false;
    {
        std::lock_guard<std::mutex> lock(monitor.pipelines_mutex);
        for (UINT i = 0; i < count; ++i)
            contains_composite = monitor.marked_lists.erase(commands[i]) != 0 || contains_composite;
    }
    original(queue, count, commands);
    if (contains_composite) submit_readback(queue);
}

bool create_frames(ID3D12Device *device, ID3D12Resource *buffer, char *message, int capacity) {
    HRESULT result = device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&monitor.fence));
    D3D12_HEAP_PROPERTIES heap{};
    heap.Type = D3D12_HEAP_TYPE_READBACK;
    heap.CreationNodeMask = heap.VisibleNodeMask = 1;
    D3D12_RESOURCE_DESC resource{};
    resource.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    resource.Width = ReadbackBytes;
    resource.Height = 1;
    resource.DepthOrArraySize = 1;
    resource.MipLevels = 1;
    resource.SampleDesc.Count = 1;
    resource.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    for (auto &frame : monitor.frames) {
        if (SUCCEEDED(result)) result = device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&frame.allocator));
        if (SUCCEEDED(result)) result = device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, frame.allocator.Get(), nullptr, IID_PPV_ARGS(&frame.commands));
        if (SUCCEEDED(result)) result = device->CreateCommittedResource(&heap, D3D12_HEAP_FLAG_NONE, &resource,
            D3D12_RESOURCE_STATE_COPY_DEST, nullptr, IID_PPV_ARGS(&frame.readback));
        if (SUCCEEDED(result)) {
            // The graph leaves the source in COPY_SOURCE; this fixed copy can be resubmitted.
            frame.commands->CopyBufferRegion(frame.readback.Get(), 0, buffer, 0, ReadbackBytes);
            result = frame.commands->Close();
        }
        if (FAILED(result)) break;
    }
    if (FAILED(result)) {
        std::snprintf(message, capacity, "Cannot create layered outline GPU readback: 0x%08lx", static_cast<unsigned long>(result));
        return false;
    }
    return true;
}
}

bool start(ID3D12Device *device, ID3D12Resource *buffer, char *message, int capacity) {
    if (monitor.active.load() || monitor.set_pipeline.address || monitor.execute.address) {
        std::snprintf(message, capacity, "Layered outline GPU readback is already installed");
        return false;
    }
    if (!create_frames(device, buffer, message, capacity)) return false;
    monitor.event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    if (!monitor.event) {
        std::snprintf(message, capacity, "Cannot create layered outline readback event: %lu", GetLastError());
        return false;
    }
    D3D12_COMMAND_QUEUE_DESC description{};
    description.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    ComPtr<ID3D12CommandQueue> queue;
    const auto result = device->CreateCommandQueue(&description, IID_PPV_ARGS(&queue));
    if (FAILED(result)) {
        std::snprintf(message, capacity, "Cannot inspect GPU submission interface: 0x%08lx", static_cast<unsigned long>(result));
        return false;
    }
    auto **commands_table = *reinterpret_cast<void ***>(monitor.frames[0].commands.Get());
    auto **queue_table = *reinterpret_cast<void ***>(queue.Get());
    if (!install_slot(monitor.set_pipeline, commands_table, SetPipelineSlot, reinterpret_cast<void *>(set_pipeline), message, capacity)) return false;
    if (!install_slot(monitor.execute, queue_table, ExecuteSlot, reinterpret_cast<void *>(execute), message, capacity)) return false;
    monitor.source = buffer;
    monitor.next_completion = 0;
    monitor.active.store(true, std::memory_order_release);
    return true;
}

bool stop(char *message, int capacity) {
    monitor.active.store(false, std::memory_order_release);
    for (auto *hook : {&monitor.execute, &monitor.set_pipeline}) {
        if (!hook->address) continue;
        if (!exchange_slot(hook->address, hook->replacement, hook->original, message, capacity)) return false;
        hook->address = nullptr;
    }
    const auto deadline = GetTickCount64() + FenceTimeout;
    while (monitor.callbacks.load(std::memory_order_acquire)) {
        if (GetTickCount64() >= deadline) {
            std::snprintf(message, capacity, "Layered outline GPU readback callbacks did not finish");
            return false;
        }
        Sleep(0);
    }
    std::lock_guard<std::mutex> lock(monitor.work_mutex);
    if (monitor.fence && !wait_for(monitor.next_completion, message, capacity)) return false;
    for (auto &frame : monitor.frames) frame = {};
    monitor.source.Reset();
    monitor.fence.Reset();
    monitor.marked_lists.clear();
    if (monitor.event) { CloseHandle(monitor.event); monitor.event = nullptr; }
    return true;
}

void add_composite(ID3D12PipelineState *pipeline) {
    std::lock_guard<std::mutex> lock(monitor.pipelines_mutex);
    monitor.pipelines.insert(pipeline);
    const auto bit = filter_bit(pipeline);
    monitor.filter[bit / 64].fetch_or(uint64_t(1) << (bit % 64), std::memory_order_relaxed);
}

const char *error() {
    if (monitor.active.load(std::memory_order_acquire)) {
        std::lock_guard<std::mutex> lock(monitor.work_mutex);
        read_completed();
    }
    return monitor.failure.load(std::memory_order_acquire);
}
}
