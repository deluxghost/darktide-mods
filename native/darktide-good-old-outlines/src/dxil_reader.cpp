#include "dxil_reader.h"
#include <cstdio>

namespace goo {
namespace {
bool failure(HRESULT status, const char *operation, std::string &error) {
    char message[160];
    std::snprintf(message, sizeof(message), "%s failed: 0x%08lx", operation,
                  static_cast<unsigned long>(status));
    error = message;
    return false;
}
} // namespace

bool DxilReader::initialize(const std::wstring &library_path, std::string &error) {
    if (compiler_)
        return true;
    library_ = LoadLibraryExW(library_path.c_str(), nullptr,
                              LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (!library_) {
        const auto code = GetLastError();
        error = "Cannot load DXIL reader, Win32 error " + std::to_string(code);
        return false;
    }
    const auto create =
        reinterpret_cast<DxcCreateInstanceProc>(GetProcAddress(library_, "DxcCreateInstance"));
    if (!create) {
        error = "DXIL reader has no DxcCreateInstance export";
        return false;
    }
    const auto status = create(CLSID_DxcCompiler, IID_PPV_ARGS(&compiler_));
    return SUCCEEDED(status) || failure(status, "Create DXIL reader", error);
}

bool DxilReader::disassemble(std::span<const uint8_t> bytes, std::string &text,
                             std::string &error) {
    DxcBuffer input{bytes.data(), bytes.size(), 0};
    Microsoft::WRL::ComPtr<IDxcResult> result;
    auto status = compiler_->Disassemble(&input, IID_PPV_ARGS(&result));
    if (FAILED(status))
        return failure(status, "Disassemble DXIL", error);
    HRESULT operation;
    status = result->GetStatus(&operation);
    if (FAILED(status))
        return failure(status, "Read DXIL status", error);
    if (FAILED(operation))
        return failure(operation, "Decode DXIL", error);
    Microsoft::WRL::ComPtr<IDxcBlobUtf8> output;
    status = result->GetOutput(DXC_OUT_DISASSEMBLY, IID_PPV_ARGS(&output), nullptr);
    if (FAILED(status))
        return failure(status, "Read DXIL disassembly", error);
    if (!output) {
        error = "DXIL reader returned no disassembly";
        return false;
    }
    text.assign(output->GetStringPointer(), output->GetStringLength());
    return true;
}
} // namespace goo
