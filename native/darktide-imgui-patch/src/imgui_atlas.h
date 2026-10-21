#pragma once

#include "imgui_patch_common.h"

namespace imgui_patch
{
bool probe_atlas(std::uintptr_t atlas, AtlasProbe* probe);
bool locate_imgui_context(std::uintptr_t* context);
bool atlas_has_font_source_name(std::uintptr_t atlas, const char* source_name);
void initialize_font_config(
    NativeImFontConfig* config,
    const InstalledFont& font,
    float size_pixels,
    const std::string& source_name,
    bool merge_mode);
}
