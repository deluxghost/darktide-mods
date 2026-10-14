#include "runtime.h"
#include <cstdio>

namespace goo {
namespace {
bool load_vertex(engine::PipelineArguments &arguments, std::vector<uint8_t> &vertex) {
    auto &state = runtime();
    const auto *source = engine::read<const uint8_t *>(arguments.pass, engine::VertexBytes);
    const auto compressed = engine::read<uint64_t>(arguments.pass, engine::VertexCompressedSize);
    const auto expanded = engine::read<uint32_t>(arguments.pass, engine::VertexExpandedSize);
    if (!expanded || !dtintutils_is_readable_range(source, compressed)) {
        return state.fail("Invalid live vertex shader storage");
    }
    vertex.resize(expanded);
    if (state.engine.decompress(source, intptr_t(compressed), vertex.data(), expanded, 1, 0, 0,
                                nullptr, 0, nullptr, nullptr, nullptr, 0, 3) != expanded) {
        return state.fail("Vertex shader decompression failed");
    }
    return true;
}

bool build_descriptor(engine::PipelineArguments &arguments, void *root,
                      D3D12_GRAPHICS_PIPELINE_STATE_DESC &descriptor) {
    auto &state = runtime();
    const auto count = arguments.target_count;
    if (!root || count > arguments.target_formats.size()) {
        return state.fail("Live target contract changed");
    }
    if (state.engine.build_descriptor(&descriptor, root, &arguments) != &descriptor ||
        descriptor.pRootSignature != root || descriptor.NumRenderTargets != count ||
        uint32_t(descriptor.DSVFormat) != arguments.depth_format ||
        uint32_t(descriptor.PrimitiveTopologyType) != arguments.topology ||
        (count && std::memcmp(descriptor.RTVFormats, arguments.target_formats.data(),
                              size_t(count) * sizeof(uint32_t)))) {
        return state.fail("Native descriptor differs from live arguments");
    }
    if (descriptor.GS.BytecodeLength || descriptor.HS.BytecodeLength ||
        descriptor.DS.BytecodeLength) {
        return state.fail("Unexpected additional graphics shader stage");
    }
    return true;
}

bool configure_mask(D3D12_GRAPHICS_PIPELINE_STATE_DESC &descriptor) {
    if (descriptor.NumRenderTargets != 2 ||
        descriptor.RTVFormats[1] != DXGI_FORMAT_R8G8B8A8_UNORM) {
        return runtime().fail("Outline mask target is not bound");
    }
    descriptor.BlendState.IndependentBlendEnable = TRUE;
    auto &mask = descriptor.BlendState.RenderTarget[1];
    mask = descriptor.BlendState.RenderTarget[0];
    mask.BlendEnable = FALSE;
    mask.LogicOpEnable = FALSE;
    mask.RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;
    return true;
}

bool configure_composite(D3D12_GRAPHICS_PIPELINE_STATE_DESC &descriptor) {
    if (descriptor.NumRenderTargets != 1) {
        return runtime().fail("Composite target contract changed");
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
                                            Program program) {
    auto &state = runtime();
    std::lock_guard<std::mutex> lock(state.pipeline_mutex);
    if (state.failure.load(std::memory_order_acquire)) {
        return {};
    }
    D3D12_GRAPHICS_PIPELINE_STATE_DESC descriptor{};
    std::vector<uint8_t> vertex;
    if (!build_descriptor(arguments, root, descriptor) || !load_vertex(arguments, vertex)) {
        return {};
    }
    const auto &replacement = state.shaders[static_cast<size_t>(program)];
    descriptor.VS = {vertex.data(), vertex.size()};
    descriptor.PS = {replacement.data(), replacement.size()};
    const bool configured = program == Program::Composite ? configure_composite(descriptor)
                                                          : configure_mask(descriptor);
    if (!configured) {
        return {};
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
        state.fail(message);
        return {};
    }
    return replacement_pipeline;
}
} // namespace goo
