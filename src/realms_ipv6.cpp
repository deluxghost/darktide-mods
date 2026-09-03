#include "realms_internal.h"

#include <ws2tcpip.h>

#include <algorithm>
#include <atomic>
#include <charconv>
#include <cstdio>
#include <cstring>
#include <iterator>

namespace realms {
namespace {

using MemberAddressScanFunction = int(__cdecl *)(const char *, const char *, int *, int *, int *, int *, int *);

constexpr size_t kMemberAddressValidationScanSize = 64;
constexpr size_t kMemberAddressFailureScanSize = 256;
constexpr uint8_t kCompareFive[] = {0x83, 0xf8, 0x05};

DtIntUtilsCallPatch g_member_address_scan_patch{};
MemberAddressScanFunction g_member_address_scan = nullptr;
std::atomic<bool> g_client_ipv6_member_address_support{false};

bool function_has_field_offset(const DtIntUtilsFunction &function, int64_t field_offset) {
    size_t offset = 0;
    while (offset < function.size) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction) ||
            instruction.length == 0) {
            ++offset;
            continue;
        }

        for (size_t index = 0; index < instruction.operand_count; ++index) {
            const DtIntUtilsOperand &operand = instruction.operands[index];
            if (operand.type == DTINTUTILS_OPERAND_MEMORY && operand.displacement == field_offset) {
                return true;
            }
        }

        offset += instruction.length;
    }
    return false;
}

bool validate_ipv6_member_address(const char *value) {
    if (value == nullptr || value[0] != '[') {
        return false;
    }

    const char *closing_bracket = std::strchr(value + 1, ']');
    if (closing_bracket == nullptr || closing_bracket == value + 1 || closing_bracket[1] != ':') {
        return false;
    }

    const size_t address_length = static_cast<size_t>(closing_bracket - value - 1);
    if (address_length >= INET6_ADDRSTRLEN) {
        return false;
    }

    char address[INET6_ADDRSTRLEN]{};
    std::memcpy(address, value + 1, address_length);

    IN6_ADDR parsed_address{};
    if (InetPtonA(AF_INET6, address, &parsed_address) != 1) {
        return false;
    }

    const char *port_begin = closing_bracket + 2;
    const char *port_end = value + std::strlen(value);
    uint32_t port = 0;
    const auto parse_result = std::from_chars(port_begin, port_end, port, 10);

    return port_begin != port_end && parse_result.ec == std::errc{} && parse_result.ptr == port_end && port > 0 &&
           port <= 65535;
}

bool branch_references_error(const uint8_t *branch, const DtIntUtilsFunction &handler,
                             const uint8_t *error_string) {
    const bool is_not_equal_branch = branch[0] == 0x75 || (branch[0] == 0x0f && branch[1] == 0x85);
    DtIntUtilsInstruction instruction{};
    if (!is_not_equal_branch || !dtintutils_decode(branch, static_cast<size_t>(handler.start + handler.size - branch),
                                                    &instruction) ||
        instruction.length == 0 || instruction.operand_count != 1 ||
        instruction.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
        !instruction.operands[0].has_absolute) {
        return false;
    }

    const uint8_t *target = reinterpret_cast<const uint8_t *>(instruction.operands[0].absolute);
    if (target < handler.start || target >= handler.start + handler.size) {
        return false;
    }

    const size_t scan_size = std::min(kMemberAddressFailureScanSize,
                                      static_cast<size_t>(handler.start + handler.size - target));
    const uint8_t *references[2]{};
    return dtintutils_find_rip_references(target, scan_size, reinterpret_cast<uintptr_t>(error_string),
                                          DTINTUTILS_MNEMONIC_ANY, references, std::size(references)) == 1;
}

int __cdecl scan_member_address(const char *value, const char *format, int *first, int *second, int *third,
                                int *fourth, int *port) {
    const int result = g_member_address_scan(value, format, first, second, third, fourth, port);

    if (result == 5 || !g_client_ipv6_member_address_support.load(std::memory_order_acquire)) {
        return result;
    }

    return validate_ipv6_member_address(value) ? 5 : result;
}

bool locate_member_address_scan_call(uint8_t **call_site, void **target, char *error, int error_capacity) {
    const uint8_t *error_strings[2]{};
    const size_t error_string_count = dtintutils_find_exact_strings(
        &g_module, "Invalid member IPv4 address reported from %llx", error_strings, std::size(error_strings));
    if (error_string_count != 1) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected one invalid member-address error string, found %zu", error_string_count);
        }
        return false;
    }

    DtIntUtilsFunction handler{};
    if (!dtintutils_find_unique_function_by_exact_string(
            &g_module, "Invalid member IPv4 address reported from %llx", &handler, error,
            error_capacity > 0 ? static_cast<size_t>(error_capacity) : 0)) {
        return false;
    }
    if (handler.size == 0 || handler.size > 0x2000 || !function_has_field_offset(handler, 0x5a8) ||
        !function_has_field_offset(handler, 0x5b0) || !function_has_field_offset(handler, 0x7c)) {
        return write_error(error, error_capacity,
                           "Darktide LAN lobby member-list handler semantic contract did not match");
    }

    const uint8_t *format_strings[2]{};
    const size_t format_count = dtintutils_find_exact_strings(&g_module, "%i.%i.%i.%i:%i", format_strings,
                                                               std::size(format_strings));
    if (format_count != 1) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected one Darktide member-address format string, found %zu", format_count);
        }
        return false;
    }

    const uint8_t *format_references[8]{};
    const size_t reference_count = dtintutils_find_rip_references(handler.start, handler.size,
                                                                  reinterpret_cast<uintptr_t>(format_strings[0]),
                                                                  DTINTUTILS_MNEMONIC_LEA, format_references,
                                                                  std::size(format_references));
    if (reference_count == 0 || reference_count > std::size(format_references)) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected a bounded member-address format reference set in the LAN lobby handler, found %zu",
                          reference_count);
        }
        return false;
    }

    const uint8_t *candidates[8]{};
    void *candidate_targets[8]{};
    size_t candidate_count = 0;

    for (size_t reference_index = 0; reference_index < reference_count; ++reference_index) {
        const uint8_t *cursor = format_references[reference_index];
        const uint8_t *scan_end = std::min<const uint8_t *>(handler.start + handler.size,
                                                            cursor + kMemberAddressValidationScanSize);

        while (cursor < scan_end) {
            DtIntUtilsInstruction instruction{};
            if (!dtintutils_decode(cursor, static_cast<size_t>(scan_end - cursor), &instruction) ||
                instruction.length == 0) {
                ++cursor;
                continue;
            }

            const uint8_t *next = cursor + instruction.length;
            if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.length == 5 &&
                instruction.operand_count >= 1 && instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
                instruction.operands[0].has_absolute && next + std::size(kCompareFive) <= scan_end &&
                std::memcmp(next, kCompareFive, std::size(kCompareFive)) == 0 &&
                branch_references_error(next + std::size(kCompareFive), handler, error_strings[0])) {
                bool duplicate = false;
                for (size_t candidate_index = 0; candidate_index < candidate_count; ++candidate_index) {
                    if (candidates[candidate_index] == cursor) {
                        duplicate = true;
                        break;
                    }
                }
                if (!duplicate) {
                    if (candidate_count >= std::size(candidates)) {
                        return write_error(error, error_capacity,
                                           "Member-address scan call candidate set exceeded its bound");
                    }
                    candidates[candidate_count] = cursor;
                    candidate_targets[candidate_count] = reinterpret_cast<void *>(instruction.operands[0].absolute);
                    ++candidate_count;
                }
            }

            cursor = next;
        }
    }

    if (candidate_count != 1 || !dtintutils_is_executable_address(&g_module, candidate_targets[0])) {
        if (error != nullptr && error_capacity > 0) {
            const unsigned long long handler_rva = static_cast<unsigned long long>(handler.start - g_module.base);
            const unsigned long long first_rva = candidate_count > 0
                                                     ? static_cast<unsigned long long>(candidates[0] - g_module.base)
                                                     : 0;
            const unsigned long long second_rva = candidate_count > 1
                                                      ? static_cast<unsigned long long>(candidates[1] - g_module.base)
                                                      : 0;
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected one validated member-address scan call, found %zu "
                          "(handler=%llx size=%zx references=%zu candidates=%llx,%llx)",
                          candidate_count, handler_rva, handler.size, reference_count, first_rva, second_rva);
        }
        return false;
    }

    *call_site = const_cast<uint8_t *>(candidates[0]);
    *target = candidate_targets[0];
    return true;
}

bool enable_client_ipv6_member_address_support(char *error, int error_capacity) {
    if (!g_member_address_scan_patch.active) {
        uint8_t *call_site = nullptr;
        void *target = nullptr;
        if (!locate_member_address_scan_call(&call_site, &target, error, error_capacity)) {
            return false;
        }

        g_member_address_scan = reinterpret_cast<MemberAddressScanFunction>(target);
        if (!dtintutils_call_patch_install(&g_member_address_scan_patch, call_site,
                                           reinterpret_cast<void *>(scan_member_address), target, error,
                                           error_capacity > 0 ? static_cast<size_t>(error_capacity) : 0)) {
            g_member_address_scan = nullptr;
            return false;
        }
    }

    g_client_ipv6_member_address_support.store(true, std::memory_order_release);
    return true;
}

} // namespace

bool set_client_ipv6_member_address_support(bool enabled, char *error, int error_capacity) {
    if (!enabled) {
        g_client_ipv6_member_address_support.store(false, std::memory_order_release);

        if (!dtintutils_call_patch_remove(&g_member_address_scan_patch, error,
                                          error_capacity > 0 ? static_cast<size_t>(error_capacity) : 0)) {
            return false;
        }

        return true;
    }

    return enable_client_ipv6_member_address_support(error, error_capacity);
}

} // namespace realms

int RealmsRuntime_SetClientIpv6MemberAddressSupport(int enabled, char *error, int error_capacity) {
    if (enabled != 0 && enabled != 1) {
        realms::write_error(error, error_capacity, "Client IPv6 member-address support flag is invalid");
        return 0;
    }
    if (!realms::ensure_initialized(error, error_capacity)) {
        return 0;
    }

    return realms::set_client_ipv6_member_address_support(enabled != 0, error, error_capacity) ? 1 : 0;
}
