#include "runtime.h"
#include <cstdio>

namespace goo {
namespace {
bool load_vertex(engine::PipelineArguments &arguments, std::vector<uint8_t> &vertex,
                 std::string &error) {
    auto &state = runtime();
    const auto *source = engine::read<const uint8_t *>(arguments.pass, engine::VertexBytes);
    const auto compressed = engine::read<uint64_t>(arguments.pass, engine::VertexCompressedSize);
    const auto expanded = engine::read<uint32_t>(arguments.pass, engine::VertexExpandedSize);
    if (!expanded || !dtintutils_is_readable_range(source, compressed)) {
        error = "Invalid live vertex shader storage";
        return false;
    }
    vertex.resize(expanded);
    if (state.engine.decompress(source, intptr_t(compressed), vertex.data(), expanded, 1, 0, 0,
                                nullptr, 0, nullptr, nullptr, nullptr, 0, 3) != expanded) {
        error = "Vertex shader decompression failed";
        return false;
    }
    return true;
}

bool build_descriptor(engine::PipelineArguments &arguments, void *root,
                      D3D12_GRAPHICS_PIPELINE_STATE_DESC &descriptor, std::string &error) {
    auto &state = runtime();
    const auto count = arguments.target_count;
    if (!root || count > arguments.target_formats.size()) {
        error = "Live target contract changed";
        return false;
    }
    if (state.engine.build_descriptor(&descriptor, root, &arguments) != &descriptor ||
        descriptor.pRootSignature != root || descriptor.NumRenderTargets != count ||
        uint32_t(descriptor.DSVFormat) != arguments.depth_format ||
        uint32_t(descriptor.PrimitiveTopologyType) != arguments.topology ||
        (count && std::memcmp(descriptor.RTVFormats, arguments.target_formats.data(),
                              size_t(count) * sizeof(uint32_t)))) {
        error = "Native descriptor differs from live arguments";
        return false;
    }
    if (descriptor.GS.BytecodeLength || descriptor.HS.BytecodeLength ||
        descriptor.DS.BytecodeLength) {
        error = "Unexpected additional graphics shader stage";
        return false;
    }
    return true;
}

bool configure_mask(D3D12_GRAPHICS_PIPELINE_STATE_DESC &descriptor, std::string &error) {
    if (descriptor.NumRenderTargets != 2 ||
        descriptor.RTVFormats[1] != DXGI_FORMAT_R32G32B32A32_FLOAT) {
        error = "Outline mask target is not bound";
        return false;
    }
    descriptor.BlendState.IndependentBlendEnable = TRUE;
    auto &mask = descriptor.BlendState.RenderTarget[1];
    mask = descriptor.BlendState.RenderTarget[0];
    // Encode depth in the high bits of every channel, so MIN retains the nearest fragment.
    mask.BlendEnable = TRUE;
    mask.SrcBlend = D3D12_BLEND_ONE;
    mask.DestBlend = D3D12_BLEND_ONE;
    mask.BlendOp = D3D12_BLEND_OP_MIN;
    mask.SrcBlendAlpha = D3D12_BLEND_ONE;
    mask.DestBlendAlpha = D3D12_BLEND_ONE;
    mask.BlendOpAlpha = D3D12_BLEND_OP_MIN;
    mask.LogicOpEnable = FALSE;
    mask.RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;
    return true;
}

bool configure_composite(D3D12_GRAPHICS_PIPELINE_STATE_DESC &descriptor, std::string &error) {
    if (descriptor.NumRenderTargets != 1) {
        error = "Composite target contract changed";
        return false;
    }
    auto &blend = descriptor.BlendState.RenderTarget[0];
    blend.BlendEnable = TRUE;
    blend.LogicOpEnable = FALSE;
    blend.SrcBlend = D3D12_BLEND_ONE;
    blend.DestBlend = D3D12_BLEND_INV_SRC_ALPHA;
    blend.BlendOp = D3D12_BLEND_OP_ADD;
    blend.SrcBlendAlpha = D3D12_BLEND_ONE;
    blend.DestBlendAlpha = D3D12_BLEND_INV_SRC_ALPHA;
    blend.BlendOpAlpha = D3D12_BLEND_OP_ADD;
    blend.RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;
    descriptor.DepthStencilState.DepthEnable = FALSE;
    descriptor.DepthStencilState.StencilEnable = FALSE;
    return true;
}
} // namespace

ComPtr<ID3D12PipelineState> create_pipeline(ID3D12PipelineState *original,
                                            engine::PipelineArguments &arguments, void *root,
                                            Program program, std::string &error) {
    auto &state = runtime();
    std::lock_guard<std::mutex> lock(state.pipeline_mutex);
    if (state.failure.load(std::memory_order_acquire)) {
        return {};
    }
    D3D12_GRAPHICS_PIPELINE_STATE_DESC descriptor{};
    std::vector<uint8_t> vertex;
    if (!build_descriptor(arguments, root, descriptor, error) ||
        !load_vertex(arguments, vertex, error)) {
        return {};
    }
    const auto &replacement = state.shaders[static_cast<size_t>(program)];
    descriptor.VS = {vertex.data(), vertex.size()};
    descriptor.PS = {replacement.data(), replacement.size()};
    const bool configured = program == Program::Composite ? configure_composite(descriptor, error)
                                                          : configure_mask(descriptor, error);
    if (!configured) {
        return {};
    }
    if (program == Program::PropOutline) {
        // Scene depth would cut holes in this mask; MIN and the composite handle occlusion.
        descriptor.DepthStencilState.DepthEnable = FALSE;
    }
    descriptor.CachedPSO = {};
    ComPtr<ID3D12Device> device;
    HRESULT result = original->GetDevice(IID_PPV_ARGS(&device));
    ComPtr<ID3D12PipelineState> replacement_pipeline;
    if (SUCCEEDED(result)) {
        result =
            device->CreateGraphicsPipelineState(&descriptor, IID_PPV_ARGS(&replacement_pipeline));
    }
    if (FAILED(result)) {
        char message[128];
        std::snprintf(message, sizeof(message), "Pipeline creation failed: 0x%08lx",
                      static_cast<unsigned long>(result));
        error = message;
        return {};
    }
    return replacement_pipeline;
}
} // namespace goo
