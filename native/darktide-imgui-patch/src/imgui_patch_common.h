#pragma once

#include <Windows.h>
#include <dwrite_2.h>

#include <cfloat>
#include <cstdint>
#include <cstddef>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

namespace imgui_patch
{
constexpr std::uintptr_t kContextRendererBackendDataOffset = 0x0b0;
constexpr std::uintptr_t kContextBackendFlagsOffset = 0x0c;
constexpr std::uintptr_t kContextWantTextInputOffset = 0xc2;
constexpr std::uintptr_t kContextIoFontsOffset = 0x40;
constexpr std::uintptr_t kContextIoFontDefaultOffset = 0x48;
constexpr std::uintptr_t kContextStyleFontSizeBaseOffset = 0xd68;
constexpr std::uintptr_t kContextStyleNextFrameFontSizeBaseOffset = 0x1260;
constexpr std::uintptr_t kContextFontOffset = 0x1280;
constexpr std::uintptr_t kContextFontBakedOffset = 0x1288;
constexpr std::uintptr_t kContextFontSizeOffset = 0x1290;
constexpr std::uintptr_t kContextFontSizeBaseOffset = 0x1294;
constexpr std::uintptr_t kContextFrameCountOffset = 0x14e8;
constexpr std::uintptr_t kContextVersionStringOffset = 0x2908;
constexpr std::uintptr_t kContextScanBytes = 0x3200;

constexpr std::uintptr_t kAtlasTexDataOffset = 0x38;
constexpr std::uintptr_t kAtlasTexListSizeOffset = 0x40;
constexpr std::uintptr_t kAtlasTexListCapacityOffset = 0x44;
constexpr std::uintptr_t kAtlasTexListDataOffset = 0x48;
constexpr std::uintptr_t kAtlasLockedOffset = 0x50;
constexpr std::uintptr_t kAtlasRendererHasTexturesOffset = 0x51;
constexpr std::uintptr_t kAtlasTexIsBuiltOffset = 0x52;
constexpr std::uintptr_t kAtlasFontsSizeOffset = 0x68;
constexpr std::uintptr_t kAtlasFontsDataOffset = 0x70;
constexpr std::uintptr_t kAtlasSourcesSizeOffset = 0x78;
constexpr std::uintptr_t kAtlasSourcesCapacityOffset = 0x7c;
constexpr std::uintptr_t kAtlasSourcesDataOffset = 0x80;

constexpr std::uintptr_t kTextureStatusOffset = 0x04;
constexpr std::uintptr_t kTextureWidthOffset = 0x1c;
constexpr std::uintptr_t kTextureHeightOffset = 0x20;
constexpr std::uintptr_t kTextureBytesPerPixelOffset = 0x24;

constexpr std::uintptr_t kFontLastBakedOffset = 0x00;
constexpr std::uintptr_t kBakedIndexAdvanceXSizeOffset = 0x00;
constexpr std::uintptr_t kBakedIndexAdvanceXDataOffset = 0x08;
constexpr std::uintptr_t kBakedIndexLookupSizeOffset = 0x20;
constexpr std::uintptr_t kBakedIndexLookupDataOffset = 0x28;
constexpr std::uintptr_t kBakedOwnerFontOffset = 0x58;

constexpr std::size_t kNativeImFontConfigSize = 0x90;
constexpr std::size_t kNativeImFontConfigNameSize = 40;
constexpr unsigned int kImGuiBackendFlagRendererHasTextures = 1u << 4;
constexpr unsigned int kImGuiFreeTypeLoaderFlagsLoadColor = 1u << 8;

extern char g_last_error[4096];

struct NativeImFontConfig
{
    char name[kNativeImFontConfigNameSize];
    void* font_data;
    int font_data_size;
    bool font_data_owned_by_atlas;
    bool merge_mode;
    bool pixel_snap_h;
    bool pixel_snap_v;
    std::int8_t oversample_h;
    std::int8_t oversample_v;
    std::uint16_t ellipsis_char;
    float size_pixels;
    const std::uint16_t* glyph_ranges;
    const std::uint16_t* glyph_exclude_ranges;
    float glyph_offset_x;
    float glyph_offset_y;
    float glyph_min_advance_x;
    float glyph_max_advance_x;
    float glyph_extra_advance_x;
    std::uint32_t font_no;
    unsigned int font_loader_flags;
    float rasterizer_multiply;
    float rasterizer_density;
    std::uint32_t flags;
    void* dst_font;
    const void* font_loader;
    void* font_loader_data;
};

static_assert(sizeof(NativeImFontConfig) == kNativeImFontConfigSize, "NativeImFontConfig must match Dear ImGui 1.92.2.");
static_assert(offsetof(NativeImFontConfig, font_data) == 0x28, "Unexpected NativeImFontConfig::FontData offset.");
static_assert(offsetof(NativeImFontConfig, glyph_ranges) == 0x40, "Unexpected NativeImFontConfig::GlyphRanges offset.");
static_assert(offsetof(NativeImFontConfig, font_loader_data) == 0x88, "Unexpected NativeImFontConfig::FontLoaderData offset.");

struct FontFileRef
{
    std::wstring path;
    std::wstring family_name;
    std::uint32_t face_index = 0;
};

struct InstalledFont
{
    std::wstring key;
    std::wstring path;
    std::wstring family_name;
    std::uint32_t face_index = 0;
    std::shared_ptr<const std::vector<unsigned char>> bytes;
    std::vector<std::uint16_t> glyph_ranges;
};

struct PreparedFontBatch
{
    InstalledFont base_font;
    std::vector<InstalledFont> fonts;
    std::string error;
    bool has_base_font = false;
};

struct ResolvedImguiSymbols
{
    std::uintptr_t module_base = 0;
    std::uintptr_t version_string = 0;
    std::uintptr_t version_pointer_slot = 0;
    std::uintptr_t create_context = 0;
    std::uintptr_t g_imgui_storage = 0;
    std::uintptr_t add_font = 0;
    std::uintptr_t build_atlas = 0;
    std::uintptr_t calc_text_size = 0;
    std::uintptr_t render_text = 0;
    std::uintptr_t add_input_character = 0;
    std::uintptr_t win32_message_handler = 0;
    std::uintptr_t platform_get_clipboard_text_offset = 0;
    std::uintptr_t platform_set_clipboard_text_offset = 0;
};

struct AtlasProbe
{
    std::uintptr_t address = 0;
    std::uintptr_t tex_data = 0;
    int tex_list_size = 0;
    int tex_list_capacity = 0;
    std::uintptr_t tex_list_data = 0;
    unsigned char locked = 0;
    unsigned char renderer_has_textures = 0;
    unsigned char tex_is_built = 0;
    int fonts_size = 0;
    int sources_size = 0;
    int texture_status = -1;
    int texture_width = 0;
    int texture_height = 0;
    int texture_bytes_per_pixel = 0;
    int score = 0;
};

void set_last_error(const char* message);
void set_last_error(const std::string& message);

bool is_readable(const void* address, std::size_t size);
bool is_writable(std::uintptr_t address, std::size_t size);

template <typename T>
bool read_value(std::uintptr_t address, T* value)
{
    if (!is_readable(reinterpret_cast<const void*>(address), sizeof(T))) {
        return false;
    }

    std::memcpy(value, reinterpret_cast<const void*>(address), sizeof(T));
    return true;
}

template <typename T>
bool write_value(std::uintptr_t address, const T& value)
{
    if (!is_writable(address, sizeof(T))) {
        return false;
    }

    std::memcpy(reinterpret_cast<void*>(address), &value, sizeof(T));
    return true;
}

bool read_c_string(std::uintptr_t address, char* buffer, std::size_t buffer_size);
std::string hresult_message(const char* operation, HRESULT result);
std::string win32_message(const char* operation, DWORD error);
bool contains_non_ascii(const char* value);
bool utf16_from_utf8(const char* utf8_text, std::wstring* utf16_text, std::string* error);
std::string utf8_from_wide(const std::wstring& value);
std::wstring font_key(const FontFileRef& font);
std::string font_source_name(const std::wstring& key);
bool read_file_bytes(const std::wstring& path, std::vector<unsigned char>* bytes, std::string* error);
bool is_probably_pointer(std::uintptr_t value);
}
