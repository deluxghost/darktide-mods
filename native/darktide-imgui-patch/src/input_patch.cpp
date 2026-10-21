#include "input_patch.h"

#include "dtintutils.h"
#include "imgui_symbols.h"

#include <mutex>

#pragma comment(lib, "imm32.lib")

namespace imgui_patch
{
namespace
{
using AddInputCharFn = void(__fastcall*)(void* io, unsigned int character);
using Win32MsgHandlerFn = LRESULT(__fastcall*)(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam, void* io);

std::mutex g_input_mutex;
DtIntUtilsHook g_msg_handler_hook;
AddInputCharFn g_add_input_char = nullptr;
bool g_input_patch_installed = false;
thread_local unsigned int g_pending_surrogate = 0;

bool is_ime_open(HWND hwnd)
{
    const HIMC himc = ImmGetContext(hwnd);
    if (himc == nullptr) {
        return false;
    }

    const bool open = ImmGetOpenStatus(himc) != FALSE;
    ImmReleaseContext(hwnd, himc);
    return open;
}

void submit_utf16_code_unit(void* io, WPARAM wparam)
{
    if (wparam > 0xffff) {
        g_pending_surrogate = 0;
        return;
    }

    const unsigned int code_unit = static_cast<unsigned int>(wparam);
    if (code_unit >= 0xd800 && code_unit <= 0xdbff) {
        g_pending_surrogate = code_unit;
        return;
    }
    if (code_unit >= 0xdc00 && code_unit <= 0xdfff) {
        if (g_pending_surrogate != 0 && g_add_input_char != nullptr) {
            const unsigned int codepoint =
                0x10000 + ((g_pending_surrogate - 0xd800) << 10) + (code_unit - 0xdc00);
            g_add_input_char(io, codepoint);
        }
        g_pending_surrogate = 0;
        return;
    }

    g_pending_surrogate = 0;
    if (code_unit != 0 && g_add_input_char != nullptr) {
        g_add_input_char(io, code_unit);
    }
}

LRESULT __fastcall win32_message_handler_hook(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam, void* io)
{
    if (message == WM_IME_CHAR || message == WM_CHAR) {
        if (is_ime_open(hwnd)) {
            if (message == WM_IME_CHAR) {
                submit_utf16_code_unit(io, wparam);
            }

            return 1;
        }

        if (message == WM_CHAR) {
            submit_utf16_code_unit(io, wparam);
        }

        return 0;
    }

    const auto original = reinterpret_cast<Win32MsgHandlerFn>(g_msg_handler_hook.trampoline);
    if (original == nullptr) {
        return 0;
    }

    return original(hwnd, message, wparam, lparam, io);
}
}

bool install_input_patch()
{
    std::lock_guard<std::mutex> lock(g_input_mutex);

    if (g_input_patch_installed) {
        return true;
    }

    ResolvedImguiSymbols symbols = {};
    if (!resolve_imgui_symbols(&symbols)) {
        return false;
    }

    if (symbols.add_input_character == 0) {
        set_last_error("AddInputCharacter symbol was not resolved");
        return false;
    }

    if (symbols.win32_message_handler == 0) {
        set_last_error("Win32 message handler symbol was not resolved");
        return false;
    }

    g_add_input_char = reinterpret_cast<AddInputCharFn>(symbols.add_input_character);

    static constexpr unsigned char kExpectedPrefix[] = {
        0x48, 0x8b, 0xc4, 0x48, 0x89, 0x58, 0x08, 0x48, 0x89, 0x70,
        0x10, 0x48, 0x89, 0x78, 0x20, 0x4c, 0x89, 0x40, 0x18,
    };
    char utility_error[512] = {};
    if (!dtintutils_hook_install_exact(
            &g_msg_handler_hook,
            reinterpret_cast<void*>(symbols.win32_message_handler),
            reinterpret_cast<void*>(&win32_message_handler_hook),
            kExpectedPrefix,
            sizeof(kExpectedPrefix),
            utility_error,
            sizeof(utility_error))) {
        set_last_error(utility_error);
        g_add_input_char = nullptr;
        return false;
    }

    g_input_patch_installed = true;
    return true;
}
}
