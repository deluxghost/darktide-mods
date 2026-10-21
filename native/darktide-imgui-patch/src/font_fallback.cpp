#include "font_fallback.h"

#include <algorithm>
#include <utility>
#include <wrl/client.h>

namespace imgui_patch
{
namespace
{
std::wstring read_directwrite_localized_string(IDWriteLocalizedStrings* strings)
{
    if (strings == nullptr) {
        return {};
    }

    UINT32 index = 0;
    BOOL exists = FALSE;

    wchar_t locale_name[LOCALE_NAME_MAX_LENGTH] = {};
    if (GetUserDefaultLocaleName(locale_name, LOCALE_NAME_MAX_LENGTH) > 0) {
        strings->FindLocaleName(locale_name, &index, &exists);
    }

    if (!exists) {
        strings->FindLocaleName(L"en-us", &index, &exists);
    }

    if (!exists) {
        index = 0;
    }

    UINT32 length = 0;
    HRESULT hr = strings->GetStringLength(index, &length);
    if (FAILED(hr)) {
        return {};
    }

    std::wstring value(static_cast<std::size_t>(length) + 1u, L'\0');
    hr = strings->GetString(index, value.data(), length + 1u);
    if (FAILED(hr)) {
        return {};
    }

    value.resize(length);
    return value;
}

class DirectWriteTextAnalysisSource final : public IDWriteTextAnalysisSource
{
public:
    explicit DirectWriteTextAnalysisSource(std::wstring text) : text_(std::move(text))
    {
    }

    IFACEMETHODIMP QueryInterface(REFIID iid, void** object) override
    {
        if (object == nullptr) {
            return E_POINTER;
        }

        if (iid == __uuidof(IUnknown) || iid == __uuidof(IDWriteTextAnalysisSource)) {
            *object = static_cast<IDWriteTextAnalysisSource*>(this);
            AddRef();
            return S_OK;
        }

        *object = nullptr;
        return E_NOINTERFACE;
    }

    IFACEMETHODIMP_(ULONG) AddRef() override
    {
        return static_cast<ULONG>(InterlockedIncrement(&ref_count_));
    }

    IFACEMETHODIMP_(ULONG) Release() override
    {
        const ULONG count = static_cast<ULONG>(InterlockedDecrement(&ref_count_));
        if (count == 0) {
            delete this;
        }

        return count;
    }

    IFACEMETHODIMP GetTextAtPosition(UINT32 text_position, WCHAR const** text_string, UINT32* text_length) override
    {
        if (text_string == nullptr || text_length == nullptr) {
            return E_POINTER;
        }

        if (static_cast<std::size_t>(text_position) >= text_.size()) {
            *text_string = nullptr;
            *text_length = 0;
            return S_OK;
        }

        *text_string = text_.c_str() + text_position;
        *text_length = static_cast<UINT32>(text_.size() - text_position);
        return S_OK;
    }

    IFACEMETHODIMP GetTextBeforePosition(UINT32 text_position, WCHAR const** text_string, UINT32* text_length) override
    {
        if (text_string == nullptr || text_length == nullptr) {
            return E_POINTER;
        }

        const UINT32 bounded_position = std::min<UINT32>(text_position, static_cast<UINT32>(text_.size()));
        if (bounded_position == 0) {
            *text_string = nullptr;
            *text_length = 0;
            return S_OK;
        }

        *text_string = text_.c_str();
        *text_length = bounded_position;
        return S_OK;
    }

    IFACEMETHODIMP_(DWRITE_READING_DIRECTION) GetParagraphReadingDirection() override
    {
        return DWRITE_READING_DIRECTION_LEFT_TO_RIGHT;
    }

    IFACEMETHODIMP GetLocaleName(UINT32 text_position, UINT32* text_length, WCHAR const** locale_name) override
    {
        if (text_length == nullptr || locale_name == nullptr) {
            return E_POINTER;
        }

        *text_length = static_cast<std::size_t>(text_position) < text_.size() ? static_cast<UINT32>(text_.size() - text_position) : 0;
        *locale_name = L"und";
        return S_OK;
    }

    IFACEMETHODIMP GetNumberSubstitution(UINT32 text_position, UINT32* text_length, IDWriteNumberSubstitution** number_substitution) override
    {
        if (text_length == nullptr || number_substitution == nullptr) {
            return E_POINTER;
        }

        *text_length = static_cast<std::size_t>(text_position) < text_.size() ? static_cast<UINT32>(text_.size() - text_position) : 0;
        *number_substitution = nullptr;
        return S_OK;
    }

private:
    volatile LONG ref_count_ = 1;
    std::wstring text_;
};

bool add_unique_font(std::vector<FontFileRef>* fonts, const FontFileRef& font)
{
    const std::wstring key = font_key(font);
    for (const FontFileRef& existing : *fonts) {
        if (font_key(existing) == key) {
            return true;
        }
    }

    fonts->push_back(font);
    return true;
}

bool get_font_family_name(IDWriteFont* font, std::wstring* family_name, std::string* error)
{
    Microsoft::WRL::ComPtr<IDWriteFontFamily> family;
    HRESULT hr = font->GetFontFamily(&family);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFont::GetFontFamily", hr);
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteLocalizedStrings> family_names;
    hr = family->GetFamilyNames(&family_names);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFontFamily::GetFamilyNames", hr);
        return false;
    }

    *family_name = read_directwrite_localized_string(family_names.Get());
    if (family_name->empty()) {
        *error = "DirectWrite returned a font without a readable family name";
        return false;
    }

    return true;
}

bool get_font_file_ref(IDWriteFont* font, FontFileRef* font_file, std::string* error)
{
    if (font == nullptr || font_file == nullptr || error == nullptr) {
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteFontFace> font_face;
    HRESULT hr = font->CreateFontFace(&font_face);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFont::CreateFontFace", hr);
        return false;
    }

    UINT32 file_count = 0;
    hr = font_face->GetFiles(&file_count, nullptr);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFontFace::GetFiles(count)", hr);
        return false;
    }

    if (file_count != 1) {
        *error = "DirectWrite returned a font that does not map to exactly one local font file";
        return false;
    }

    IDWriteFontFile* file_ptr = nullptr;
    hr = font_face->GetFiles(&file_count, &file_ptr);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFontFace::GetFiles(file)", hr);
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteFontFile> file;
    file.Attach(file_ptr);

    const void* reference_key = nullptr;
    UINT32 reference_key_size = 0;
    hr = file->GetReferenceKey(&reference_key, &reference_key_size);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFontFile::GetReferenceKey", hr);
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteFontFileLoader> loader;
    hr = file->GetLoader(&loader);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFontFile::GetLoader", hr);
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteLocalFontFileLoader> local_loader;
    hr = loader.As(&local_loader);
    if (FAILED(hr)) {
        *error = "DirectWrite returned a font that is not backed by a local font file";
        return false;
    }

    UINT32 path_length = 0;
    hr = local_loader->GetFilePathLengthFromKey(reference_key, reference_key_size, &path_length);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteLocalFontFileLoader::GetFilePathLengthFromKey", hr);
        return false;
    }

    std::wstring path(static_cast<std::size_t>(path_length) + 1u, L'\0');
    hr = local_loader->GetFilePathFromKey(reference_key, reference_key_size, path.data(), path_length + 1u);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteLocalFontFileLoader::GetFilePathFromKey", hr);
        return false;
    }

    path.resize(path_length);

    font_file->path = std::move(path);
    font_file->face_index = font_face->GetIndex();
    return get_font_family_name(font, &font_file->family_name, error);
}

bool get_windows_message_font(IDWriteFactory* factory, Microsoft::WRL::ComPtr<IDWriteFont>* font, std::string* error)
{
    if (factory == nullptr || font == nullptr || error == nullptr) {
        return false;
    }

    NONCLIENTMETRICSW metrics = {};
    metrics.cbSize = sizeof(metrics);
    if (!SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, metrics.cbSize, &metrics, 0)) {
        *error = win32_message("SystemParametersInfoW(SPI_GETNONCLIENTMETRICS)", GetLastError());
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteGdiInterop> gdi_interop;
    HRESULT hr = factory->GetGdiInterop(&gdi_interop);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFactory::GetGdiInterop", hr);
        return false;
    }

    hr = gdi_interop->CreateFontFromLOGFONT(&metrics.lfMessageFont, font->GetAddressOf());
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteGdiInterop::CreateFontFromLOGFONT", hr);
        return false;
    }

    return true;
}
}

bool get_system_base_font(FontFileRef* font, std::string* error)
{
    if (font == nullptr || error == nullptr) {
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteFactory> factory;
    HRESULT hr = DWriteCreateFactory(
        DWRITE_FACTORY_TYPE_SHARED,
        __uuidof(IDWriteFactory),
        reinterpret_cast<IUnknown**>(factory.GetAddressOf()));
    if (FAILED(hr)) {
        *error = hresult_message("DWriteCreateFactory", hr);
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteFont> dwrite_font;
    if (!get_windows_message_font(factory.Get(), &dwrite_font, error)) {
        return false;
    }

    if (!get_font_file_ref(dwrite_font.Get(), font, error)) {
        return false;
    }

    if (font_key(*font).empty()) {
        *error = "DirectWrite returned an empty base font reference";
        return false;
    }

    return true;
}

bool discover_system_fallback_fonts(const char* utf8_text, std::vector<FontFileRef>* fonts, std::string* error)
{
    std::wstring text;
    if (!utf16_from_utf8(utf8_text, &text, error)) {
        return false;
    }

    if (text.empty()) {
        return true;
    }

    Microsoft::WRL::ComPtr<IDWriteFactory2> factory;
    HRESULT hr = DWriteCreateFactory(
        DWRITE_FACTORY_TYPE_SHARED,
        __uuidof(IDWriteFactory2),
        reinterpret_cast<IUnknown**>(factory.GetAddressOf()));
    if (FAILED(hr)) {
        *error = hresult_message("DWriteCreateFactory", hr);
        return false;
    }

    Microsoft::WRL::ComPtr<IDWriteFontFallback> fallback;
    hr = factory->GetSystemFontFallback(&fallback);
    if (FAILED(hr)) {
        *error = hresult_message("IDWriteFactory2::GetSystemFontFallback", hr);
        return false;
    }

    Microsoft::WRL::ComPtr<DirectWriteTextAnalysisSource> source;
    source.Attach(new DirectWriteTextAnalysisSource(text));

    UINT32 position = 0;
    const UINT32 text_length = static_cast<UINT32>(text.size());
    while (position < text_length) {
        UINT32 mapped_length = 0;
        FLOAT scale = 1.0f;
        Microsoft::WRL::ComPtr<IDWriteFont> mapped_font;

        hr = fallback->MapCharacters(
            source.Get(),
            position,
            text_length - position,
            nullptr,
            nullptr,
            DWRITE_FONT_WEIGHT_NORMAL,
            DWRITE_FONT_STYLE_NORMAL,
            DWRITE_FONT_STRETCH_NORMAL,
            &mapped_length,
            &mapped_font,
            &scale);
        if (FAILED(hr)) {
            *error = hresult_message("IDWriteFontFallback::MapCharacters", hr);
            return false;
        }

        if (mapped_length == 0) {
            *error = "DirectWrite mapped zero characters while discovering fallback fonts";
            return false;
        }

        if (mapped_font) {
            FontFileRef font;
            if (!get_font_file_ref(mapped_font.Get(), &font, error)) {
                return false;
            }

            add_unique_font(fonts, font);
        }

        position += mapped_length;
    }

    return true;
}
}
