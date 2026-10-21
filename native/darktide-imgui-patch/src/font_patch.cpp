#include "font_patch.h"

#include "clipboard_patch.h"
#include "font_batch.h"
#include "imgui_atlas.h"
#include "input_patch.h"
#include "text_capture.h"

#include <chrono>
#include <exception>
#include <future>
#include <mutex>
#include <string>
#include <vector>

namespace imgui_patch
{
namespace
{
constexpr std::size_t kMaxCapturedTextsPerBatch = 64;

enum ConfigureStatus
{
    kConfigureError = -1,
    kConfigureAtlasLocked = 0,
    kConfigureApplied = 1,
};

enum CaptureStatus
{
    kCaptureError = -1,
    kCaptureIdle = 0,
    kCapturePending = 1,
    kCapturePreparing = 2,
    kCaptureAtlasLocked = 3,
    kCaptureApplied = 4,
    kCaptureNotInstalled = 5,
};

std::mutex g_configure_mutex;
bool g_configure_prepared = false;
PreparedFontBatch g_configure_batch;

std::mutex g_capture_mutex;
std::future<PreparedFontBatch> g_capture_future;
bool g_capture_active = false;
bool g_capture_ready = false;
PreparedFontBatch g_capture_batch;

void reset_capture_preparation()
{
    g_capture_active = false;
    g_capture_ready = false;
    g_capture_batch = {};
    g_capture_future = {};
}

std::string join_captured_texts(const std::vector<std::string>& texts)
{
    std::string result;
    for (const std::string& text : texts) {
        if (!result.empty()) {
            result.push_back('\n');
        }

        result += text;
    }

    return result;
}

}
}

extern "C" __declspec(dllexport) const char* ImguiPatch_LastError()
{
    return imgui_patch::g_last_error;
}

extern "C" __declspec(dllexport) int ImguiPatch_ConfigureFonts()
{
    using namespace imgui_patch;

    try {
        set_last_error("");

        if (!install_clipboard_patch()) {
            return kConfigureError;
        }

        if (!install_input_patch()) {
            return kConfigureError;
        }

        std::lock_guard<std::mutex> lock(g_configure_mutex);
        if (!g_configure_prepared) {
            g_configure_batch = prepare_base_font_batch();
            g_configure_prepared = true;
        }
        if (!g_configure_batch.error.empty()) {
            set_last_error(g_configure_batch.error);
            g_configure_batch = {};
            g_configure_prepared = false;
            return kConfigureError;
        }
        FontBatchApplyResult apply_result;
        if (!apply_prepared_font_batch(&g_configure_batch, kDefaultFontSizePixels, &apply_result)) {
            return kConfigureError;
        }
        if (apply_result.atlas_locked) {
            return kConfigureAtlasLocked;
        }
        g_configure_batch = {};
        g_configure_prepared = false;
        return kConfigureApplied;
    } catch (const std::exception& error) {
        set_last_error(std::string("native exception: ") + error.what());
        return kConfigureError;
    } catch (...) {
        set_last_error("unknown native exception");
        return kConfigureError;
    }
}

extern "C" __declspec(dllexport) int ImguiPatch_InstallTextCapture()
{
    using namespace imgui_patch;

    try {
        set_last_error("");

        if (!install_text_capture()) {
            return 0;
        }

        return 1;
    } catch (const std::exception& error) {
        set_last_error(std::string("native exception: ") + error.what());
        return 0;
    } catch (...) {
        set_last_error("unknown native exception");
        return 0;
    }
}

extern "C" __declspec(dllexport) int ImguiPatch_PollTextCapture()
{
    using namespace imgui_patch;

    try {
        set_last_error("");

        if (!is_text_capture_installed()) {
            return kCaptureNotInstalled;
        }

        std::lock_guard<std::mutex> lock(g_capture_mutex);
        if (g_capture_active && !g_capture_ready) {
            if (!g_capture_future.valid()) {
                set_last_error("text capture font preparation future is invalid");
                reset_capture_preparation();
                return kCaptureError;
            }

            if (g_capture_future.wait_for(std::chrono::seconds(0)) != std::future_status::ready) {
                return kCapturePending;
            }

            g_capture_batch = g_capture_future.get();
            g_capture_ready = true;
        }

        if (g_capture_active && g_capture_ready) {
            if (!g_capture_batch.error.empty()) {
                set_last_error(g_capture_batch.error);
                reset_capture_preparation();
                return kCaptureError;
            }

            FontBatchApplyResult apply_result;
            if (!apply_prepared_font_batch(&g_capture_batch, 0.0f, &apply_result)) {
                return kCaptureError;
            }

            if (apply_result.atlas_locked) {
                return kCaptureAtlasLocked;
            }

            reset_capture_preparation();
            return kCaptureApplied;
        }

        CapturedTextBatch captured;
        if (!pop_captured_text_batch(kMaxCapturedTextsPerBatch, &captured)) {
            return kCaptureError;
        }

        if (captured.texts.empty()) {
            return kCaptureIdle;
        }

        const std::string text = join_captured_texts(captured.texts);
        g_capture_batch = {};
        g_capture_ready = false;
        g_capture_active = true;
        g_capture_future = std::async(std::launch::async, [text]() {
            return prepare_font_batch_for_text(text);
        });

        return kCapturePreparing;
    } catch (const std::exception& error) {
        set_last_error(std::string("native exception: ") + error.what());
        return kCaptureError;
    } catch (...) {
        set_last_error("unknown native exception");
        return kCaptureError;
    }
}

extern "C" __declspec(dllexport) int ImguiPatch_UninstallTextCapture()
{
    using namespace imgui_patch;

    try {
        set_last_error("");

        {
            std::lock_guard<std::mutex> lock(g_capture_mutex);
            reset_capture_preparation();
        }

        if (!uninstall_text_capture()) {
            return 0;
        }

        return 1;
    } catch (const std::exception& error) {
        set_last_error(std::string("native exception: ") + error.what());
        return 0;
    } catch (...) {
        set_last_error("unknown native exception");
        return 0;
    }
}

extern "C" __declspec(dllexport) int ImguiPatch_WantsTextInput()
{
    using namespace imgui_patch;

    try {
        set_last_error("");

        std::uintptr_t context = 0;
        if (!locate_imgui_context(&context)) {
            return 0;
        }

        unsigned char wants_text_input = 0;
        if (!read_value(context + kContextWantTextInputOffset, &wants_text_input)) {
            set_last_error("ImGuiIO.WantTextInput offset is not readable");
            return 0;
        }

        return wants_text_input != 0 ? 1 : 0;
    } catch (const std::exception& error) {
        set_last_error(std::string("native exception: ") + error.what());
        return 0;
    } catch (...) {
        set_last_error("unknown native exception");
        return 0;
    }
}
