#pragma once

#include "imgui_patch_common.h"

namespace imgui_patch
{
inline constexpr float kDefaultFontSizePixels = 18.0f;

struct FontBatchApplyResult
{
    bool atlas_locked = false;
    bool changed = false;
};

PreparedFontBatch prepare_base_font_batch();
PreparedFontBatch prepare_font_batch_for_text(const std::string& utf8_text);
bool apply_prepared_font_batch(PreparedFontBatch* batch, float size_pixels, FontBatchApplyResult* result);
}
