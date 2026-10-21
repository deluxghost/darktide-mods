#include "imgui_atlas.h"

#include "imgui_symbols.h"

#include <cstdio>
#include <cstring>

namespace imgui_patch
{
bool probe_atlas(std::uintptr_t atlas, AtlasProbe* probe)
{
    if (probe == nullptr) {
        return false;
    }
    if (!is_probably_pointer(atlas) || !is_readable(reinterpret_cast<const void*>(atlas), 0x90)) {
        return false;
    }

    AtlasProbe candidate = {};
    candidate.address = atlas;

    const bool atlas_ok =
        read_value(atlas + kAtlasTexDataOffset, &candidate.tex_data) &&
        read_value(atlas + kAtlasTexListSizeOffset, &candidate.tex_list_size) &&
        read_value(atlas + kAtlasTexListCapacityOffset, &candidate.tex_list_capacity) &&
        read_value(atlas + kAtlasTexListDataOffset, &candidate.tex_list_data) &&
        read_value(atlas + kAtlasLockedOffset, &candidate.locked) &&
        read_value(atlas + kAtlasRendererHasTexturesOffset, &candidate.renderer_has_textures) &&
        read_value(atlas + kAtlasTexIsBuiltOffset, &candidate.tex_is_built) &&
        read_value(atlas + kAtlasFontsSizeOffset, &candidate.fonts_size) &&
        read_value(atlas + kAtlasSourcesSizeOffset, &candidate.sources_size);

    if (!atlas_ok) {
        return false;
    }

    if (candidate.tex_list_size < 0 || candidate.tex_list_size > 16) {
        return false;
    }
    if (candidate.tex_list_capacity < candidate.tex_list_size || candidate.tex_list_capacity > 64) {
        return false;
    }
    if (candidate.fonts_size < 0 || candidate.fonts_size > 64) {
        return false;
    }
    if (candidate.sources_size < 0 || candidate.sources_size > 128) {
        return false;
    }
    if (candidate.locked > 1 || candidate.renderer_has_textures > 1 || candidate.tex_is_built > 1) {
        return false;
    }

    candidate.score = 1;
    if (candidate.fonts_size > 0) {
        candidate.score += 4;
    }
    if (candidate.sources_size > 0) {
        candidate.score += 4;
    }
    if (candidate.tex_list_size > 0 && candidate.tex_list_capacity >= candidate.tex_list_size) {
        candidate.score += 2;
    }
    if (candidate.tex_list_data != 0 && is_readable(reinterpret_cast<const void*>(candidate.tex_list_data), static_cast<std::size_t>(candidate.tex_list_size) * sizeof(std::uintptr_t))) {
        candidate.score += 2;
    }
    if (candidate.renderer_has_textures == 1) {
        candidate.score += 2;
    }
    if (candidate.tex_is_built == 1) {
        candidate.score += 2;
    }

    if (candidate.tex_data != 0 && is_readable(reinterpret_cast<const void*>(candidate.tex_data), 0x50)) {
        const bool texture_ok =
            read_value(candidate.tex_data + kTextureStatusOffset, &candidate.texture_status) &&
            read_value(candidate.tex_data + kTextureWidthOffset, &candidate.texture_width) &&
            read_value(candidate.tex_data + kTextureHeightOffset, &candidate.texture_height) &&
            read_value(candidate.tex_data + kTextureBytesPerPixelOffset, &candidate.texture_bytes_per_pixel);

        if (texture_ok) {
            if (candidate.texture_status >= 0 && candidate.texture_status <= 4) {
                candidate.score += 2;
            }
            if (candidate.texture_width > 0 && candidate.texture_width <= 16384 &&
                candidate.texture_height > 0 && candidate.texture_height <= 16384) {
                candidate.score += 3;
            }
            if (candidate.texture_bytes_per_pixel == 1 || candidate.texture_bytes_per_pixel == 4) {
                candidate.score += 2;
            }
        }
    }

    if (candidate.score < 10) {
        return false;
    }

    *probe = candidate;
    return true;
}

bool locate_imgui_context(std::uintptr_t* context)
{
    if (context == nullptr) {
        return false;
    }

    ResolvedImguiSymbols symbols = {};
    if (!resolve_imgui_symbols(&symbols)) {
        return false;
    }

    if (!read_value(symbols.g_imgui_storage, context)) {
        set_last_error("GImGui storage address is not readable");
        return false;
    }

    if (*context == 0) {
        set_last_error("GImGui is null");
        return false;
    }

    std::uintptr_t version_string_address = 0;
    if (!read_value(*context + kContextVersionStringOffset, &version_string_address)) {
        set_last_error("ImGuiContext version string offset is not readable");
        return false;
    }

    if (version_string_address != symbols.version_string) {
        set_last_error("resolved GImGui context failed version string validation");
        return false;
    }

    return true;
}

bool atlas_has_font_source_name(std::uintptr_t atlas, const char* source_name)
{
    if (source_name == nullptr || source_name[0] == '\0') {
        return false;
    }

    int sources_size = 0;
    int sources_capacity = 0;
    std::uintptr_t sources_data = 0;
    if (!read_value(atlas + kAtlasSourcesSizeOffset, &sources_size) ||
        !read_value(atlas + kAtlasSourcesCapacityOffset, &sources_capacity) ||
        !read_value(atlas + kAtlasSourcesDataOffset, &sources_data)) {
        return false;
    }

    if (sources_size <= 0 || sources_size > 128 || sources_capacity < sources_size || sources_capacity > 256 ||
        !is_probably_pointer(sources_data) ||
        !is_readable(reinterpret_cast<const void*>(sources_data), static_cast<std::size_t>(sources_size) * kNativeImFontConfigSize)) {
        return false;
    }

    for (int index = 0; index < sources_size; ++index) {
        char existing_name[kNativeImFontConfigNameSize] = {};
        const auto name_address = sources_data + static_cast<std::uintptr_t>(index) * kNativeImFontConfigSize;
        if (!is_readable(reinterpret_cast<const void*>(name_address), sizeof(existing_name))) {
            continue;
        }

        std::memcpy(existing_name, reinterpret_cast<const void*>(name_address), sizeof(existing_name));
        existing_name[kNativeImFontConfigNameSize - 1] = '\0';
        if (std::strncmp(existing_name, source_name, kNativeImFontConfigNameSize) == 0) {
            return true;
        }
    }

    return false;
}

void initialize_font_config(
    NativeImFontConfig* config,
    const InstalledFont& font,
    float size_pixels,
    const std::string& source_name,
    bool merge_mode)
{
    std::memset(config, 0, sizeof(*config));
    std::snprintf(config->name, sizeof(config->name), "%s", source_name.c_str());
    config->font_data = const_cast<unsigned char*>(font.bytes->data());
    config->font_data_size = static_cast<int>(font.bytes->size());
    config->font_data_owned_by_atlas = false;
    config->merge_mode = merge_mode;
    config->oversample_h = 0;
    config->oversample_v = 0;
    config->ellipsis_char = 0;
    config->size_pixels = size_pixels;
    config->glyph_ranges = font.glyph_ranges.empty() ? nullptr : font.glyph_ranges.data();
    config->glyph_exclude_ranges = nullptr;
    config->glyph_max_advance_x = FLT_MAX;
    config->font_no = font.face_index;
    config->font_loader_flags = kImGuiFreeTypeLoaderFlagsLoadColor;
    config->rasterizer_multiply = 1.0f;
    config->rasterizer_density = 1.0f;
}

}
