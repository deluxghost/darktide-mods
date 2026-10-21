#include "glyph_cache.h"


#include <algorithm>
#include <unordered_set>

namespace imgui_patch
{
namespace
{
bool baked_font_matches_owner(std::uintptr_t baked_font, std::uintptr_t owner_font)
{
    if (!is_probably_pointer(baked_font) || !is_probably_pointer(owner_font) ||
        !is_readable(reinterpret_cast<const void*>(baked_font), kBakedOwnerFontOffset + sizeof(std::uintptr_t))) {
        return false;
    }

    std::uintptr_t baked_owner = 0;
    return read_value(baked_font + kBakedOwnerFontOffset, &baked_owner) && baked_owner == owner_font;
}

std::size_t clear_missing_glyph_cache_for_baked_font(std::uintptr_t baked_font)
{
    int advance_size = 0;
    int lookup_size = 0;
    std::uintptr_t advance_data = 0;
    std::uintptr_t lookup_data = 0;

    if (!read_value(baked_font + kBakedIndexAdvanceXSizeOffset, &advance_size) ||
        !read_value(baked_font + kBakedIndexAdvanceXDataOffset, &advance_data) ||
        !read_value(baked_font + kBakedIndexLookupSizeOffset, &lookup_size) ||
        !read_value(baked_font + kBakedIndexLookupDataOffset, &lookup_data)) {
        return 0;
    }

    if (advance_size <= 0 || lookup_size <= 0 || advance_size > 0x10000 || lookup_size > 0x10000) {
        return 0;
    }

    const int entry_count = std::min(advance_size, lookup_size);
    const auto advance_bytes = static_cast<std::size_t>(entry_count) * sizeof(float);
    const auto lookup_bytes = static_cast<std::size_t>(entry_count) * sizeof(std::uint16_t);
    if (!is_writable(advance_data, advance_bytes) || !is_writable(lookup_data, lookup_bytes)) {
        return 0;
    }

    auto* advances = reinterpret_cast<float*>(advance_data);
    auto* lookup = reinterpret_cast<std::uint16_t*>(lookup_data);

    std::size_t cleared = 0;
    for (int codepoint = 0x80; codepoint < entry_count; ++codepoint) {
        if (lookup[codepoint] != 0xfffeu) {
            continue;
        }

        lookup[codepoint] = 0xffffu;
        advances[codepoint] = -1.0f;
        ++cleared;
    }

    return cleared;
}

void clear_baked_font_if_valid(
    std::uintptr_t baked_font,
    std::uintptr_t owner_font,
    std::unordered_set<std::uintptr_t>* seen_baked_fonts)
{
    if (seen_baked_fonts == nullptr ||
        !baked_font_matches_owner(baked_font, owner_font) ||
        seen_baked_fonts->find(baked_font) != seen_baked_fonts->end()) {
        return;
    }

    seen_baked_fonts->insert(baked_font);
    clear_missing_glyph_cache_for_baked_font(baked_font);
}
}

void clear_missing_glyph_caches(std::uintptr_t context, std::uintptr_t atlas)
{
    std::unordered_set<std::uintptr_t> seen_baked_fonts;

    std::uintptr_t current_font = 0;
    if (read_value(context + kContextFontOffset, &current_font) && is_probably_pointer(current_font)) {
        std::uintptr_t context_baked_font = 0;
        if (read_value(context + kContextFontBakedOffset, &context_baked_font)) {
            clear_baked_font_if_valid(context_baked_font, current_font, &seen_baked_fonts);
        }

        std::uintptr_t last_baked_font = 0;
        if (read_value(current_font + kFontLastBakedOffset, &last_baked_font)) {
            clear_baked_font_if_valid(last_baked_font, current_font, &seen_baked_fonts);
        }
    }

    int fonts_size = 0;
    std::uintptr_t fonts_data = 0;
    if (!read_value(atlas + kAtlasFontsSizeOffset, &fonts_size) ||
        !read_value(atlas + kAtlasFontsDataOffset, &fonts_data) ||
        fonts_size <= 0 || fonts_size > 64 ||
        !is_readable(reinterpret_cast<const void*>(fonts_data), static_cast<std::size_t>(fonts_size) * sizeof(std::uintptr_t))) {
        return;
    }

    for (int index = 0; index < fonts_size; ++index) {
        std::uintptr_t font = 0;
        if (!read_value(fonts_data + static_cast<std::uintptr_t>(index) * sizeof(std::uintptr_t), &font) ||
            !is_probably_pointer(font)) {
            continue;
        }

        std::uintptr_t last_baked_font = 0;
        if (read_value(font + kFontLastBakedOffset, &last_baked_font)) {
            clear_baked_font_if_valid(last_baked_font, font, &seen_baked_fonts);
        }
    }
}
}
