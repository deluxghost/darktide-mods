#pragma once

#include "imgui_patch_common.h"

namespace imgui_patch
{
bool get_system_base_font(FontFileRef* font, std::string* error);
bool discover_system_fallback_fonts(const char* utf8_text, std::vector<FontFileRef>* fonts, std::string* error);
}
