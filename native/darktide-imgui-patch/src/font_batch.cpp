#include "font_batch.h"

#include "font_fallback.h"
#include "glyph_cache.h"
#include "imgui_atlas.h"
#include "imgui_symbols.h"

#include <algorithm>
#include <cwctype>
#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>

namespace imgui_patch
{
namespace
{
std::mutex g_font_mutex;
std::unordered_set<std::wstring> g_installed_font_keys;
std::vector<InstalledFont> g_installed_fonts;
std::uintptr_t g_installed_font_atlas = 0;
std::uintptr_t g_base_font_atlas = 0;
std::uintptr_t g_base_font = 0;
std::wstring g_base_font_key;
std::mutex g_font_file_cache_mutex;
std::unordered_map<std::wstring, std::shared_ptr<const std::vector<unsigned char>>> g_font_file_cache;

bool load_cached_font_bytes(
    const std::wstring& path,
    std::shared_ptr<const std::vector<unsigned char>>* bytes,
    std::string* error)
{
    std::wstring key = path;
    std::transform(key.begin(), key.end(), key.begin(), [](wchar_t value) {
        return static_cast<wchar_t>(std::towlower(value));
    });

    {
        std::lock_guard<std::mutex> lock(g_font_file_cache_mutex);
        const auto existing = g_font_file_cache.find(key);
        if (existing != g_font_file_cache.end()) {
            *bytes = existing->second;
            return true;
        }
    }

    auto loaded = std::make_shared<std::vector<unsigned char>>();
    if (!read_file_bytes(path, loaded.get(), error)) {
        return false;
    }

    std::lock_guard<std::mutex> lock(g_font_file_cache_mutex);
    const auto stored = g_font_file_cache.emplace(key, loaded).first;
    *bytes = stored->second;
    return true;
}

bool prepare_system_base_font(InstalledFont* font, std::string* error)
{
    if (font == nullptr || error == nullptr) {
        return false;
    }

    FontFileRef base_font;
    if (!get_system_base_font(&base_font, error)) {
        return false;
    }

    font->key = font_key(base_font);
    font->path = base_font.path;
    font->family_name = base_font.family_name;
    font->face_index = base_font.face_index;

    return load_cached_font_bytes(font->path, &font->bytes, error);
}

bool read_runtime_font_atlas(std::uintptr_t context, AtlasProbe* probe)
{
    std::uintptr_t io_fonts = 0;
    if (!read_value(context + kContextIoFontsOffset, &io_fonts)) {
        set_last_error("ImGuiIO.Fonts offset is not readable");
        return false;
    }

    if (!probe_atlas(io_fonts, probe)) {
        set_last_error("ImGuiIO.Fonts is not a valid ImFontAtlas");
        return false;
    }

    return true;
}

bool apply_default_font_settings(std::uintptr_t context, std::uintptr_t font, float size_pixels)
{
    if (!write_value(context + kContextIoFontDefaultOffset, font) ||
        !write_value(context + kContextStyleFontSizeBaseOffset, size_pixels) ||
        !write_value(context + kContextStyleNextFrameFontSizeBaseOffset, size_pixels)) {
        set_last_error("failed to write ImGui default font/style state");
        return false;
    }

    std::uintptr_t new_default_font = 0;
    float new_style_size = 0.0f;
    float new_next_style_size = 0.0f;

    if (!read_value(context + kContextIoFontDefaultOffset, &new_default_font) ||
        !read_value(context + kContextStyleFontSizeBaseOffset, &new_style_size) ||
        !read_value(context + kContextStyleNextFrameFontSizeBaseOffset, &new_next_style_size)) {
        set_last_error("failed to verify ImGui default font/style state");
        return false;
    }

    if (new_default_font != font || new_style_size != size_pixels || new_next_style_size != size_pixels) {
        set_last_error("ImGui default font/style verification failed");
        return false;
    }

    return true;
}

struct BaseFontInstallResult
{
    bool changed = false;
    std::uintptr_t font = 0;
};

bool install_base_font_if_needed(
    PreparedFontBatch* batch,
    std::uintptr_t context,
    std::uintptr_t atlas,
    float size_pixels,
    void* (*add_font)(void*, const NativeImFontConfig*),
    BaseFontInstallResult* result)
{
    if (batch == nullptr || add_font == nullptr || result == nullptr) {
        set_last_error("invalid base font install arguments");
        return false;
    }

    if (!batch->has_base_font) {
        if (g_base_font_atlas == atlas && g_base_font != 0) {
            result->font = g_base_font;
            return apply_default_font_settings(context, g_base_font, size_pixels);
        }

        set_last_error("base font was not prepared");
        return false;
    }

    const bool already_installed =
        g_base_font_atlas == atlas &&
        g_base_font != 0 &&
        g_base_font_key == batch->base_font.key;

    if (already_installed) {
        result->font = g_base_font;
        return apply_default_font_settings(context, g_base_font, size_pixels);
    }

    const std::string source_name = font_source_name(L"base:" + batch->base_font.key);
    g_installed_fonts.push_back(std::move(batch->base_font));
    InstalledFont& installed_font = g_installed_fonts.back();

    NativeImFontConfig config = {};
    initialize_font_config(&config, installed_font, size_pixels, source_name, false);

    void* result_font = add_font(reinterpret_cast<void*>(atlas), &config);
    if (result_font == nullptr) {
        g_installed_fonts.pop_back();
        set_last_error("Darktide ImFontAtlas::AddFont returned null for base font");
        return false;
    }

    g_base_font_atlas = atlas;
    g_base_font = reinterpret_cast<std::uintptr_t>(result_font);
    g_base_font_key = installed_font.key;
    g_installed_font_atlas = atlas;
    g_installed_font_keys.insert(installed_font.key);

    result->changed = true;
    result->font = g_base_font;
    return apply_default_font_settings(context, g_base_font, size_pixels);
}
}

PreparedFontBatch prepare_base_font_batch()
{
    PreparedFontBatch batch;

    std::string error;
    if (!prepare_system_base_font(&batch.base_font, &error)) {
        batch.error = error;
        return batch;
    }

    batch.has_base_font = true;
    return batch;
}

PreparedFontBatch prepare_font_batch_for_text(const std::string& utf8_text)
{
    PreparedFontBatch batch = prepare_base_font_batch();
    if (!batch.error.empty()) {
        return batch;
    }

    if (utf8_text.empty() || !contains_non_ascii(utf8_text.c_str())) {
        return batch;
    }

    std::string error;
    std::vector<FontFileRef> fallback_fonts;
    if (!discover_system_fallback_fonts(utf8_text.c_str(), &fallback_fonts, &error)) {
        batch.error = error;
        return batch;
    }

    if (fallback_fonts.empty()) {
        batch.error = "DirectWrite did not return fallback fonts for captured ImGui text";
        return batch;
    }

    for (const FontFileRef& font_ref : fallback_fonts) {
        InstalledFont font;
        font.key = font_key(font_ref);
        font.path = font_ref.path;
        font.family_name = font_ref.family_name;
        font.face_index = font_ref.face_index;

        if (!load_cached_font_bytes(font.path, &font.bytes, &error)) {
            batch.error = error;
            return batch;
        }

        batch.fonts.push_back(std::move(font));
    }

    return batch;
}

bool apply_prepared_font_batch(PreparedFontBatch* batch, float size_pixels, FontBatchApplyResult* result)
{
    if (batch == nullptr || result == nullptr) {
        set_last_error("invalid prepared font batch arguments");
        return false;
    }

    std::uintptr_t context = 0;
    if (!locate_imgui_context(&context)) {
        return false;
    }

    ResolvedImguiSymbols symbols = {};
    if (!resolve_imgui_symbols(&symbols)) {
        return false;
    }

    float runtime_font_size = 0.0f;
    if (!read_value(context + kContextFontSizeOffset, &runtime_font_size)) {
        set_last_error("ImGuiContext.FontSize offset is not readable");
        return false;
    }

    const float effective_size =
        size_pixels > 0.0f ? size_pixels : std::max(runtime_font_size, kDefaultFontSizePixels);
    if (effective_size <= 0.0f) {
        set_last_error("effective font size is not positive");
        return false;
    }

    AtlasProbe atlas_probe = {};
    if (!read_runtime_font_atlas(context, &atlas_probe)) {
        return false;
    }

    if (atlas_probe.locked != 0) {
        result->atlas_locked = true;
        return true;
    }

    using AddFontFn = void* (*)(void*, const NativeImFontConfig*);
    const auto add_font = reinterpret_cast<AddFontFn>(symbols.add_font);

    int installed_count = 0;
    {
        std::lock_guard<std::mutex> guard(g_font_mutex);

        BaseFontInstallResult base_result;
        if (!install_base_font_if_needed(
                batch,
                context,
                atlas_probe.address,
                effective_size,
                add_font,
                &base_result)) {
            return false;
        }

        result->changed = result->changed || base_result.changed;

        for (InstalledFont& prepared_font : batch->fonts) {
            const std::string source_name = font_source_name(prepared_font.key);
            const bool installed_on_this_atlas =
                g_installed_font_atlas == atlas_probe.address &&
                g_installed_font_keys.find(prepared_font.key) != g_installed_font_keys.end();

            if (installed_on_this_atlas || atlas_has_font_source_name(atlas_probe.address, source_name.c_str())) {
                continue;
            }

            g_installed_fonts.push_back(std::move(prepared_font));
            InstalledFont& installed_font = g_installed_fonts.back();

            NativeImFontConfig config = {};
            initialize_font_config(&config, installed_font, effective_size, source_name, true);

            void* result_font = add_font(reinterpret_cast<void*>(atlas_probe.address), &config);
            if (result_font == nullptr) {
                g_installed_fonts.pop_back();
                set_last_error("Darktide ImFontAtlas::AddFont returned null");
                return false;
            }

            g_installed_font_keys.insert(installed_font.key);
            g_installed_font_atlas = atlas_probe.address;
            ++installed_count;
        }
    }

    unsigned int backend_flags = 0;
    if (!read_value(context + kContextBackendFlagsOffset, &backend_flags)) {
        set_last_error("ImGuiContext.BackendFlags offset is not readable");
        return false;
    }

    int frame_count = 0;
    if (!read_value(context + kContextFrameCountOffset, &frame_count)) {
        set_last_error("ImGuiContext.FrameCount offset is not readable");
        return false;
    }

    const char renderer_has_textures =
        (backend_flags & kImGuiBackendFlagRendererHasTextures) != 0 ? static_cast<char>(1) : static_cast<char>(0);

    result->changed = result->changed || installed_count > 0;
    if (result->changed) {
        if (symbols.build_atlas == 0) {
            set_last_error("ImFontAtlas build/update symbol was not resolved");
            return false;
        }

        clear_missing_glyph_caches(context, atlas_probe.address);

        using BuildAtlasFn = void(__fastcall*)(void*, int, char);
        const auto build_atlas = reinterpret_cast<BuildAtlasFn>(symbols.build_atlas);
        build_atlas(reinterpret_cast<void*>(atlas_probe.address), frame_count, renderer_has_textures);
    }

    return true;
}
}
