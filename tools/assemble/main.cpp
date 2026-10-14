#include <windows.h>
#include <objbase.h>
#include <oleauto.h>
#include <dxcapi.h>
#include <wrl/client.h>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

using Microsoft::WRL::ComPtr;

static void check(HRESULT result, const char *operation) {
    if (FAILED(result))
        throw std::runtime_error(operation);
}

static ComPtr<IDxcBlob> result_blob(IDxcOperationResult *result) {
    HRESULT status;
    check(result->GetStatus(&status), "GetStatus failed");
    if (FAILED(status)) {
        ComPtr<IDxcBlobEncoding> errors;
        check(result->GetErrorBuffer(&errors), "GetErrorBuffer failed");
        throw std::runtime_error(std::string(static_cast<const char *>(errors->GetBufferPointer()),
                                             errors->GetBufferSize()));
    }
    ComPtr<IDxcBlob> blob;
    check(result->GetResult(&blob), "GetResult failed");
    return blob;
}

int main(int argc, char **argv) {
    try {
        if (argc != 3)
            throw std::runtime_error("Usage: assemble input.ll output.dxil");
        std::ifstream input(argv[1], std::ios::binary);
        if (!input)
            throw std::runtime_error("Could not open LLVM input");
        std::vector<char> text((std::istreambuf_iterator<char>(input)), {});
        ComPtr<IDxcLibrary> library;
        check(DxcCreateInstance(CLSID_DxcLibrary, IID_PPV_ARGS(&library)), "Create library failed");
        ComPtr<IDxcBlobEncoding> source;
        check(library->CreateBlobWithEncodingOnHeapCopy(
                  text.data(), static_cast<UINT32>(text.size()), CP_UTF8, &source),
              "Create blob failed");
        ComPtr<IDxcAssembler> assembler;
        check(DxcCreateInstance(CLSID_DxcAssembler, IID_PPV_ARGS(&assembler)),
              "Create assembler failed");
        ComPtr<IDxcOperationResult> assembled;
        check(assembler->AssembleToContainer(source.Get(), &assembled), "Assembly failed");
        auto blob = result_blob(assembled.Get());
        ComPtr<IDxcValidator> validator;
        check(DxcCreateInstance(CLSID_DxcValidator, IID_PPV_ARGS(&validator)),
              "Create validator failed");
        ComPtr<IDxcOperationResult> validated;
        check(validator->Validate(blob.Get(), DxcValidatorFlags_InPlaceEdit, &validated),
              "Validation failed");
        blob = result_blob(validated.Get());
        std::ofstream output(argv[2], std::ios::binary);
        output.write(static_cast<const char *>(blob->GetBufferPointer()), blob->GetBufferSize());
        if (!output)
            throw std::runtime_error("Could not write DXIL output");
        std::cout << "Assembled and validated " << blob->GetBufferSize() << " bytes\n";
        return 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
