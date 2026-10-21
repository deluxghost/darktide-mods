#include "clipboard_patch.h"

#include "imgui_atlas.h"
#include "imgui_symbols.h"

#include <string>

namespace imgui_patch
{
namespace
{
using PlatformGetClipboardTextFn = const char* (__fastcall*)(void* context);
using PlatformSetClipboardTextFn = void(__fastcall*)(void* context, const char* text);

thread_local std::string g_clipboard_text;

const char* __fastcall get_clipboard_text_utf8(void*)
{
    g_clipboard_text.clear();

    if (!OpenClipboard(nullptr)) {
        return nullptr;
    }

    HANDLE data_handle = GetClipboardData(CF_UNICODETEXT);
    if (data_handle == nullptr) {
        CloseClipboard();
        return nullptr;
    }

    const auto* wide_text = static_cast<const wchar_t*>(GlobalLock(data_handle));
    if (wide_text == nullptr) {
        CloseClipboard();
        return nullptr;
    }

    const int size = WideCharToMultiByte(CP_UTF8, 0, wide_text, -1, nullptr, 0, nullptr, nullptr);
    if (size > 0) {
        g_clipboard_text.resize(static_cast<std::size_t>(size));
        if (WideCharToMultiByte(CP_UTF8, 0, wide_text, -1, g_clipboard_text.data(), size, nullptr, nullptr) <= 0) {
            g_clipboard_text.clear();
        }
    }

    GlobalUnlock(data_handle);
    CloseClipboard();

    return g_clipboard_text.empty() ? nullptr : g_clipboard_text.c_str();
}

void __fastcall set_clipboard_text_utf8(void*, const char* text)
{
    if (text == nullptr) {
        text = "";
    }

    const int wide_size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, -1, nullptr, 0);
    if (wide_size <= 0) {
        return;
    }

    HGLOBAL data_handle = GlobalAlloc(GMEM_MOVEABLE, static_cast<SIZE_T>(wide_size) * sizeof(wchar_t));
    if (data_handle == nullptr) {
        return;
    }

    auto* wide_text = static_cast<wchar_t*>(GlobalLock(data_handle));
    if (wide_text == nullptr) {
        GlobalFree(data_handle);
        return;
    }

    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, -1, wide_text, wide_size) <= 0) {
        GlobalUnlock(data_handle);
        GlobalFree(data_handle);
        return;
    }

    GlobalUnlock(data_handle);

    if (!OpenClipboard(nullptr)) {
        GlobalFree(data_handle);
        return;
    }

    EmptyClipboard();
    if (SetClipboardData(CF_UNICODETEXT, data_handle) == nullptr) {
        CloseClipboard();
        GlobalFree(data_handle);
        return;
    }

    CloseClipboard();
}

bool write_callback_slot(std::uintptr_t address, std::uintptr_t callback, const char* name)
{
    if (!write_value(address, callback)) {
        set_last_error(std::string(name) + " slot is not writable");
        return false;
    }

    return true;
}
}

bool install_clipboard_patch()
{
    ResolvedImguiSymbols symbols = {};
    if (!resolve_imgui_symbols(&symbols)) {
        return false;
    }

    if (symbols.platform_get_clipboard_text_offset == 0 || symbols.platform_set_clipboard_text_offset == 0) {
        set_last_error("ImGui clipboard callback slots were not resolved");
        return false;
    }

    std::uintptr_t context = 0;
    if (!locate_imgui_context(&context)) {
        return false;
    }

    const auto get_callback = reinterpret_cast<std::uintptr_t>(&get_clipboard_text_utf8);
    const auto set_callback = reinterpret_cast<std::uintptr_t>(&set_clipboard_text_utf8);

    if (!write_callback_slot(
            context + symbols.platform_get_clipboard_text_offset,
            get_callback,
            "ImGuiPlatformIO.Platform_GetClipboardTextFn")) {
        return false;
    }

    if (!write_callback_slot(
            context + symbols.platform_set_clipboard_text_offset,
            set_callback,
            "ImGuiPlatformIO.Platform_SetClipboardTextFn")) {
        return false;
    }

    return true;
}
}
