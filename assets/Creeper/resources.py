"""Resource identities and inline cooked resources for Custom Assets."""

import struct


def resource_id(name):
    data = name.encode("utf-8")
    multiplier = 0xC6A4A7935BD1E995
    mask = (1 << 64) - 1
    value = len(data) * multiplier & mask
    end = len(data) // 8 * 8
    for offset in range(0, end, 8):
        block = struct.unpack_from("<Q", data, offset)[0] * multiplier & mask
        block = (block ^ (block >> 47)) * multiplier & mask
        value = (value ^ block) * multiplier & mask
    if end < len(data):
        value = (value ^ int.from_bytes(data[end:], "little")) * multiplier & mask
    value = (value ^ (value >> 47)) * multiplier & mask
    return value ^ (value >> 47)


def sound_id(name):
    value = 2166136261
    for byte in name.lower().encode("ascii"):
        value = ((value * 16777619) ^ byte) & 0xFFFFFFFF
    return value
