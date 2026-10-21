#pragma once
#include <windows.h>
#include <objbase.h>
#include <oleauto.h>
#include <dxcapi.h>
#include <wrl/client.h>
#include <span>
#include <string>

namespace goo {
class DxilReader {
  public:
    bool initialize(const std::wstring &library_path, std::string &error);
    bool disassemble(std::span<const uint8_t> bytes, std::string &text, std::string &error);

  private:
    // Retain the SDK module until process exit, including across mod reloads.
    HMODULE library_ = nullptr;
    Microsoft::WRL::ComPtr<IDxcCompiler3> compiler_;
};
} // namespace goo
