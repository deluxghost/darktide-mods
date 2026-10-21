#pragma once

#include "imgui_patch_common.h"

#include <string>
#include <vector>

namespace imgui_patch
{
struct CapturedTextBatch
{
    std::vector<std::string> texts;
};

bool install_text_capture();
bool uninstall_text_capture();
bool is_text_capture_installed();
bool pop_captured_text_batch(std::size_t max_texts, CapturedTextBatch* batch);
}
