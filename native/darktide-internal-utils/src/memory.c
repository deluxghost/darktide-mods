#include <windows.h>

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "dtintutils_internal.h"

void dtintutils_set_error(char *buffer, size_t buffer_size, const char *format, ...) {
    va_list arguments;

    if (buffer == NULL || buffer_size == 0) {
        return;
    }

    va_start(arguments, format);
    vsnprintf(buffer, buffer_size, format, arguments);
    va_end(arguments);
    buffer[buffer_size - 1] = '\0';
}

static int dtintutils_is_readable_protection(DWORD protection) {
    if ((protection & PAGE_GUARD) != 0 || (protection & PAGE_NOACCESS) != 0) {
        return 0;
    }

    switch (protection & 0xffu) {
        case PAGE_READONLY:
        case PAGE_READWRITE:
        case PAGE_WRITECOPY:
        case PAGE_EXECUTE_READ:
        case PAGE_EXECUTE_READWRITE:
        case PAGE_EXECUTE_WRITECOPY:
            return 1;
        default:
            return 0;
    }
}

static int dtintutils_is_writable_protection(DWORD protection) {
    if ((protection & PAGE_GUARD) != 0 || (protection & PAGE_NOACCESS) != 0) {
        return 0;
    }

    switch (protection & 0xffu) {
        case PAGE_READWRITE:
        case PAGE_WRITECOPY:
        case PAGE_EXECUTE_READWRITE:
        case PAGE_EXECUTE_WRITECOPY:
            return 1;
        default:
            return 0;
    }
}

static int dtintutils_check_memory_range(
    const void *address,
    size_t size,
    int (*accept_protection)(DWORD)
) {
    const uint8_t *cursor = (const uint8_t *)address;
    const uint8_t *end;

    if (address == NULL || size == 0 || (uintptr_t)address > UINTPTR_MAX - size) {
        return 0;
    }

    end = cursor + size;
    while (cursor < end) {
        MEMORY_BASIC_INFORMATION information;
        const uint8_t *region_end;

        if (VirtualQuery(cursor, &information, sizeof(information)) != sizeof(information) ||
            information.State != MEM_COMMIT || !accept_protection(information.Protect)) {
            return 0;
        }

        region_end = (const uint8_t *)information.BaseAddress + information.RegionSize;
        if (region_end <= cursor) {
            return 0;
        }
        cursor = region_end < end ? region_end : end;
    }

    return 1;
}

int dtintutils_is_readable_range(const void *address, size_t size) {
    return dtintutils_check_memory_range(address, size, dtintutils_is_readable_protection);
}

int dtintutils_is_writable_range(const void *address, size_t size) {
    return dtintutils_check_memory_range(address, size, dtintutils_is_writable_protection);
}

int dtintutils_module_init_current(
    DtIntUtilsModule *module,
    char *error,
    size_t error_size
) {
    HMODULE native_module;
    IMAGE_DOS_HEADER *dos_header;
    IMAGE_NT_HEADERS64 *nt_headers;
    IMAGE_SECTION_HEADER *section_headers;
    IMAGE_DATA_DIRECTORY exception_directory;
    WORD index;

    if (module == NULL) {
        dtintutils_set_error(error, error_size, "module output is null");
        return 0;
    }

    memset(module, 0, sizeof(*module));
    native_module = GetModuleHandleW(NULL);
    if (native_module == NULL) {
        dtintutils_set_error(error, error_size, "GetModuleHandleW(NULL) failed with Win32 error %lu", GetLastError());
        return 0;
    }

    module->base = (uint8_t *)native_module;
    dos_header = (IMAGE_DOS_HEADER *)module->base;
    if (dos_header->e_magic != IMAGE_DOS_SIGNATURE || dos_header->e_lfanew <= 0) {
        dtintutils_set_error(error, error_size, "the main module does not have a valid DOS header");
        return 0;
    }

    nt_headers = (IMAGE_NT_HEADERS64 *)(module->base + dos_header->e_lfanew);
    if (nt_headers->Signature != IMAGE_NT_SIGNATURE ||
        nt_headers->FileHeader.Machine != IMAGE_FILE_MACHINE_AMD64 ||
        nt_headers->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
        dtintutils_set_error(error, error_size, "the main module is not a valid AMD64 PE image");
        return 0;
    }
    if (nt_headers->FileHeader.NumberOfSections == 0 ||
        nt_headers->FileHeader.NumberOfSections > DTINTUTILS_MAX_SECTIONS) {
        dtintutils_set_error(error, error_size, "the main module has an unsupported section count: %u",
                            nt_headers->FileHeader.NumberOfSections);
        return 0;
    }

    module->image_size = nt_headers->OptionalHeader.SizeOfImage;
    module->section_count = nt_headers->FileHeader.NumberOfSections;
    section_headers = IMAGE_FIRST_SECTION(nt_headers);
    for (index = 0; index < nt_headers->FileHeader.NumberOfSections; ++index) {
        DtIntUtilsSection *section = &module->sections[index];
        size_t section_size = section_headers[index].Misc.VirtualSize != 0
            ? section_headers[index].Misc.VirtualSize
            : section_headers[index].SizeOfRawData;
        size_t section_rva = section_headers[index].VirtualAddress;

        if (section_rva >= module->image_size) {
            section_size = 0;
        } else if (section_size > module->image_size - section_rva) {
            section_size = module->image_size - section_rva;
        }

        section->start = module->base + section_rva;
        section->size = section_size;
        section->characteristics = section_headers[index].Characteristics;
        memcpy(section->name, section_headers[index].Name, IMAGE_SIZEOF_SHORT_NAME);
        section->name[IMAGE_SIZEOF_SHORT_NAME] = '\0';

        if (strcmp(section->name, ".text") == 0) {
            if (module->text != NULL) {
                dtintutils_set_error(error, error_size, "the main module contains multiple .text sections");
                return 0;
            }
            module->text = section;
        }
    }

    if (module->text == NULL || module->text->size == 0 ||
        (module->text->characteristics & IMAGE_SCN_MEM_EXECUTE) == 0 ||
        (module->text->characteristics & IMAGE_SCN_MEM_READ) == 0) {
        dtintutils_set_error(error, error_size, "the main module has no readable executable .text section");
        return 0;
    }

    exception_directory = nt_headers->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXCEPTION];
    if (exception_directory.VirtualAddress == 0 || exception_directory.Size < sizeof(RUNTIME_FUNCTION) ||
        exception_directory.Size % sizeof(RUNTIME_FUNCTION) != 0 ||
        exception_directory.VirtualAddress >= module->image_size ||
        exception_directory.Size > module->image_size - exception_directory.VirtualAddress) {
        dtintutils_set_error(error, error_size, "the main module has no valid x64 exception directory");
        return 0;
    }

    module->runtime_functions = module->base + exception_directory.VirtualAddress;
    module->runtime_function_count = exception_directory.Size / sizeof(RUNTIME_FUNCTION);
    if (error != NULL && error_size != 0) {
        error[0] = '\0';
    }
    return 1;
}

const DtIntUtilsSection *dtintutils_section(
    const DtIntUtilsModule *module,
    const char *name
) {
    size_t index;

    if (module == NULL || name == NULL) {
        return NULL;
    }
    for (index = 0; index < module->section_count; ++index) {
        if (strcmp(module->sections[index].name, name) == 0) {
            return &module->sections[index];
        }
    }
    return NULL;
}

const DtIntUtilsSection *dtintutils_section_for_address(
    const DtIntUtilsModule *module,
    const void *address
) {
    const uint8_t *value = (const uint8_t *)address;
    size_t index;

    if (module == NULL || address == NULL) {
        return NULL;
    }
    for (index = 0; index < module->section_count; ++index) {
        const DtIntUtilsSection *section = &module->sections[index];
        if (section->size != 0 && value >= section->start && value < section->start + section->size) {
            return section;
        }
    }
    return NULL;
}

int dtintutils_is_executable_address(
    const DtIntUtilsModule *module,
    const void *address
) {
    const DtIntUtilsSection *section = dtintutils_section_for_address(module, address);
    return section != NULL && (section->characteristics & IMAGE_SCN_MEM_EXECUTE) != 0;
}

int dtintutils_is_writable_address(
    const DtIntUtilsModule *module,
    const void *address
) {
    const DtIntUtilsSection *section = dtintutils_section_for_address(module, address);
    return section != NULL && (section->characteristics & IMAGE_SCN_MEM_WRITE) != 0;
}
