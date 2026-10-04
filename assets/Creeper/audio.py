"""Build native Wwise events with Minecraft media and retail spatial routing."""

import struct
import subprocess

from resources import resource_id, sound_id


def chunk(tag, data):
    return tag + struct.pack("<I", len(data)) + data


def read_bank(template):
    assert struct.unpack_from("<I", template, 38)[0] == 29
    assert template[98:102] == b"BKHD"
    bank_size = struct.unpack_from("<I", template, 42)[0]
    bank = template[98:98 + bank_size]
    chunks = {}
    offset = 0
    while offset < len(bank):
        size = struct.unpack_from("<I", bank, offset + 4)[0]
        chunks[bank[offset:offset + 4]] = bank[offset + 8:offset + 8 + size]
        offset += size + 8
    assert offset == len(bank)
    return chunks


def pcm_media(source, pitch):
    samples = subprocess.run(["ffmpeg", "-v", "error", "-i", str(source), "-ac", "1",
                              "-ar", "48000", "-af", "aresample=48000,asetrate=%d,aresample=48000" % (48000 * pitch),
                              "-f", "s16le", "pipe:1"], check=True, capture_output=True).stdout
    # The game's PCM decoder requires Wwise's extensible format tag.
    fmt = struct.pack("<HHIIHHHHI", 0xFFFE, 1, 48000, 96000, 2, 16, 6, 0, 0x4101)
    body = b"WAVE" + chunk(b"fmt ", fmt) + chunk(b"JUNK", bytes(4)) + chunk(b"data", samples)
    return chunk(b"RIFF", body)


def build_event(template, source, name, pitch):
    chunks = read_bank(template)
    hierarchy = bytearray(chunks[b"HIRC"])
    count = struct.unpack_from("<I", hierarchy)[0]
    objects = []
    offset = 4
    for _ in range(count):
        kind, size = struct.unpack_from("<BI", hierarchy, offset)
        objects.append((kind, offset + 5, size))
        offset += size + 5
    assert offset == len(hierarchy) and [kind for kind, _, _ in objects] == [14, 2, 7, 7, 3, 4]
    old_event = struct.unpack_from("<I", template, 66)[0]
    new_event = sound_id(name.rsplit("/", 1)[1])
    replacements = {struct.unpack_from("<I", hierarchy, start)[0]:
                    sound_id(name + "/node%d" % index) for index, (_, start, _) in enumerate(objects)}
    replacements[old_event] = new_event
    old_media = struct.unpack_from("<I", chunks[b"DIDX"])[0]
    new_media = sound_id(name + "/media")
    replacements[old_media] = new_media
    original = bytes(hierarchy)
    for old, new in replacements.items():
        needle = struct.pack("<I", old)
        start = original.find(needle)
        while start >= 0:
            struct.pack_into("<I", hierarchy, start, new)
            start = original.find(needle, start + 4)
    media = pcm_media(source, pitch)
    sound_start = objects[1][1]
    assert struct.unpack_from("<I", hierarchy, sound_start + 4)[0] == 0x00040001
    struct.pack_into("<I", hierarchy, sound_start + 4, 0x00010001)
    struct.pack_into("<I", hierarchy, sound_start + 13, len(media))
    struct.pack_into("<ff", hierarchy, sound_start + 35, 0, 0)
    header = bytearray(chunks[b"BKHD"])
    # Retail encrypts four BKHD fields; changing only the bank ID preserves that encoding.
    stored_bank_id = struct.unpack_from("<I", header, 4)[0]
    struct.pack_into("<I", header, 4, stored_bank_id ^ old_event ^ new_event)
    bank = chunk(b"BKHD", header) + chunk(b"DIDX", struct.pack("<III", new_media, 0, len(media)))
    bank += chunk(b"DATA", media) + chunk(b"HIRC", hierarchy)
    cooked = bytearray(template[:98]) + bank + bytes(4)
    struct.pack_into("<Q", cooked, 8, resource_id(name))
    struct.pack_into("<I", cooked, 29, len(cooked) - 38)
    struct.pack_into("<I", cooked, 42, len(bank))
    struct.pack_into("<Q", cooked, 50, resource_id(name))
    struct.pack_into("<I", cooked, 66, new_event)
    return cooked


def build_audio(source, retail, output):
    template = (retail / "wwise/events/minions/play_minion_poxwalker_bomber_wind_up.wwise_event").read_bytes()
    output.mkdir(parents=True, exist_ok=True)
    for name, pitch in [("fuse", 0.5)] + [("explode%d" % index, 0.7) for index in range(1, 5)]:
        identity = "wwise/events/mods/creeper/play_creeper_" + name
        path = name + ".wwise_event"
        (output / path).write_bytes(build_event(template, source / (name + ".ogg"), identity, pitch))
