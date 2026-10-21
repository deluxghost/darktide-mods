#pragma once

#include "imgui_patch_common.h"

namespace imgui_patch
{
void clear_missing_glyph_caches(std::uintptr_t context, std::uintptr_t atlas);
}
