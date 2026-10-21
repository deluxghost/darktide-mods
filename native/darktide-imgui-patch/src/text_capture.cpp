#include "text_capture.h"

#include "dtintutils.h"
#include "imgui_symbols.h"

#include <algorithm>
#include <deque>
#include <mutex>
#include <unordered_set>

namespace imgui_patch
{
namespace
{
struct NativeImVec2
{
    float x;
    float y;
};

struct NativeImVec4
{
    float x;
    float y;
    float z;
    float w;
};

using RenderTextFn = void(__fastcall*)(
    void* font,
    void* draw_list,
    float size,
    const NativeImVec2& pos,
    unsigned int col,
    const NativeImVec4& clip_rect,
    const char* text_begin,
    const char* text_end,
    float wrap_width,
    int flags);

using CalcTextSizeFn = float* (__fastcall*)(
    void* font,
    float* out,
    float size,
    float max_width,
    float wrap_width,
    const char* text_begin,
    const char* text_end,
    void* remaining);

constexpr std::size_t kMaxCapturedTextBytes = 4096;
constexpr std::size_t kMaxQueuedTexts = 512;

std::mutex g_detour_mutex;
DtIntUtilsHook g_calc_text_size_hook;
DtIntUtilsHook g_render_text_hook;
bool g_capture_installed = false;

std::mutex g_queue_mutex;
std::deque<std::string> g_text_queue;
std::unordered_set<std::uint32_t> g_seen_codepoints;

bool read_text_range(const char* text_begin, const char* text_end, std::size_t* length)
{
    if (text_begin == nullptr || length == nullptr) {
        return false;
    }

    *length = 0;
    if (text_end != nullptr) {
        const auto begin = reinterpret_cast<std::uintptr_t>(text_begin);
        const auto end = reinterpret_cast<std::uintptr_t>(text_end);
        if (end <= begin || end - begin > kMaxCapturedTextBytes) {
            return false;
        }

        *length = static_cast<std::size_t>(end - begin);
    } else {
        while (*length < kMaxCapturedTextBytes && text_begin[*length] != '\0') {
            ++*length;
        }
    }
    return true;
}

bool contains_non_ascii_text(const char* text, std::size_t length)
{
    for (std::size_t index = 0; index < length; ++index) {
        if (static_cast<unsigned char>(text[index]) >= 0x80) {
            return true;
        }
    }

    return false;
}

std::size_t decode_utf8_codepoint(
    const unsigned char* text,
    std::size_t remaining,
    std::uint32_t* codepoint)
{
    const unsigned char first = text[0];
    if (first < 0x80) {
        *codepoint = first;
        return 1;
    }
    if (first >= 0xc2 && first <= 0xdf && remaining >= 2 &&
        (text[1] & 0xc0) == 0x80) {
        *codepoint = ((first & 0x1f) << 6) | (text[1] & 0x3f);
        return 2;
    }
    if (first >= 0xe0 && first <= 0xef && remaining >= 3 &&
        (text[1] & 0xc0) == 0x80 && (text[2] & 0xc0) == 0x80 &&
        !(first == 0xe0 && text[1] < 0xa0) &&
        !(first == 0xed && text[1] >= 0xa0)) {
        *codepoint = ((first & 0x0f) << 12) |
            ((text[1] & 0x3f) << 6) |
            (text[2] & 0x3f);
        return 3;
    }
    if (first >= 0xf0 && first <= 0xf4 && remaining >= 4 &&
        (text[1] & 0xc0) == 0x80 && (text[2] & 0xc0) == 0x80 &&
        (text[3] & 0xc0) == 0x80 &&
        !(first == 0xf0 && text[1] < 0x90) &&
        !(first == 0xf4 && text[1] >= 0x90)) {
        *codepoint = ((first & 0x07) << 18) |
            ((text[1] & 0x3f) << 12) |
            ((text[2] & 0x3f) << 6) |
            (text[3] & 0x3f);
        return 4;
    }
    return 0;
}

void enqueue_rendered_text(const char* text_begin, const char* text_end)
{
    std::size_t length = 0;
    if (!read_text_range(text_begin, text_end, &length)) {
        return;
    }

    if (length == 0 || !contains_non_ascii_text(text_begin, length)) {
        return;
    }

    std::unique_lock<std::mutex> lock(g_queue_mutex, std::try_to_lock);
    if (!lock.owns_lock()) {
        return;
    }

    if (g_text_queue.size() >= kMaxQueuedTexts) {
        return;
    }

    std::string new_codepoints;
    new_codepoints.reserve(length);
    const auto* bytes = reinterpret_cast<const unsigned char*>(text_begin);
    for (std::size_t offset = 0; offset < length;) {
        std::uint32_t codepoint = 0;
        const std::size_t sequence_length = decode_utf8_codepoint(
            bytes + offset, length - offset, &codepoint);
        if (sequence_length == 0) {
            ++offset;
            continue;
        }
        if (codepoint >= 0x80 && g_seen_codepoints.insert(codepoint).second) {
            new_codepoints.append(text_begin + offset, sequence_length);
        }
        offset += sequence_length;
    }
    if (!new_codepoints.empty()) {
        g_text_queue.push_back(std::move(new_codepoints));
    }
}

void __fastcall render_text_hook(
    void* font,
    void* draw_list,
    float size,
    const NativeImVec2& pos,
    unsigned int col,
    const NativeImVec4& clip_rect,
    const char* text_begin,
    const char* text_end,
    float wrap_width,
    int flags)
{
    try {
        enqueue_rendered_text(text_begin, text_end);
    } catch (...) {
    }

    const auto original = reinterpret_cast<RenderTextFn>(g_render_text_hook.trampoline);
    if (original != nullptr) {
        original(font, draw_list, size, pos, col, clip_rect, text_begin, text_end, wrap_width, flags);
    }
}

float* __fastcall calc_text_size_hook(
    void* font,
    float* out,
    float size,
    float max_width,
    float wrap_width,
    const char* text_begin,
    const char* text_end,
    void* remaining)
{
    try {
        enqueue_rendered_text(text_begin, text_end);
    } catch (...) {
    }

    const auto original = reinterpret_cast<CalcTextSizeFn>(g_calc_text_size_hook.trampoline);
    if (original != nullptr) {
        return original(font, out, size, max_width, wrap_width, text_begin, text_end, remaining);
    }

    return out;
}

void clear_captured_texts()
{
    std::lock_guard<std::mutex> lock(g_queue_mutex);
    g_text_queue.clear();
    g_seen_codepoints.clear();
}
}

bool install_text_capture()
{
    std::lock_guard<std::mutex> lock(g_detour_mutex);

    if (g_capture_installed) {
        return true;
    }

    ResolvedImguiSymbols symbols = {};
    if (!resolve_imgui_symbols(&symbols)) {
        return false;
    }

    if (symbols.calc_text_size == 0) {
        set_last_error("CalcTextSize symbol was not resolved");
        return false;
    }

    if (symbols.render_text == 0) {
        set_last_error("RenderText symbol was not resolved");
        return false;
    }

    clear_captured_texts();

    static constexpr unsigned char kCalcTextSizeExpectedPrefix[] = {
        0x48, 0x8b, 0xc4, 0x48, 0x89, 0x48, 0x08, 0x53,
        0x56, 0x48, 0x81, 0xec,
    };
    static constexpr unsigned char kRenderTextExpectedPrefix[] = {
        0x4c, 0x8b, 0xdc, 0x4d, 0x89, 0x4b, 0x20, 0xf3, 0x0f,
        0x11, 0x54, 0x24, 0x18, 0x49, 0x89, 0x53, 0x10,
    };
    DtIntUtilsPatternByte calc_text_size_expected[sizeof(kCalcTextSizeExpectedPrefix)] = {};
    DtIntUtilsPatternByte render_text_expected[sizeof(kRenderTextExpectedPrefix)] = {};
    for (std::size_t index = 0; index < sizeof(kCalcTextSizeExpectedPrefix); ++index) {
        calc_text_size_expected[index].value = kCalcTextSizeExpectedPrefix[index];
    }
    for (std::size_t index = 0; index < sizeof(kRenderTextExpectedPrefix); ++index) {
        render_text_expected[index].value = kRenderTextExpectedPrefix[index];
    }
    const DtIntUtilsHookRequest requests[] = {
        {
            &g_calc_text_size_hook,
            reinterpret_cast<void*>(symbols.calc_text_size),
            reinterpret_cast<void*>(&calc_text_size_hook),
            calc_text_size_expected,
            sizeof(calc_text_size_expected) / sizeof(calc_text_size_expected[0]),
        },
        {
            &g_render_text_hook,
            reinterpret_cast<void*>(symbols.render_text),
            reinterpret_cast<void*>(&render_text_hook),
            render_text_expected,
            sizeof(render_text_expected) / sizeof(render_text_expected[0]),
        },
    };
    char utility_error[512] = {};

    if (!dtintutils_hooks_install(
            requests,
            sizeof(requests) / sizeof(requests[0]),
            utility_error,
            sizeof(utility_error))) {
        set_last_error(utility_error);
        return false;
    }

    g_capture_installed = true;
    return true;
}

bool uninstall_text_capture()
{
    std::lock_guard<std::mutex> lock(g_detour_mutex);

    if (!g_capture_installed) {
        clear_captured_texts();
        return true;
    }

    char utility_error[512] = {};
    if (!dtintutils_hook_remove(&g_render_text_hook, utility_error, sizeof(utility_error))) {
        set_last_error(utility_error);
        return false;
    }

    if (!dtintutils_hook_remove(&g_calc_text_size_hook, utility_error, sizeof(utility_error))) {
        set_last_error(utility_error);
        return false;
    }

    g_capture_installed = false;
    clear_captured_texts();
    return true;
}

bool is_text_capture_installed()
{
    std::lock_guard<std::mutex> lock(g_detour_mutex);
    return g_capture_installed;
}

bool pop_captured_text_batch(std::size_t max_texts, CapturedTextBatch* batch)
{
    if (batch == nullptr || max_texts == 0) {
        set_last_error("invalid captured text batch output");
        return false;
    }

    batch->texts.clear();

    std::lock_guard<std::mutex> lock(g_queue_mutex);
    while (!g_text_queue.empty() && batch->texts.size() < max_texts) {
        batch->texts.push_back(std::move(g_text_queue.front()));
        g_text_queue.pop_front();
    }

    return true;
}
}
