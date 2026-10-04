"""Retain the retail gameplay unit while removing its native priming particles."""

import json
import struct
import subprocess
import zlib

from resources import resource_id

RETAIL_UNIT = "content/characters/enemy/chaos_poxwalker_bomber/third_person/base"
PARENT_UNIT = "content/mods/creeper/parent"
RETAIL_PRIME = "content/fx/particles/enemies/poxwalker_bomber/poxwalker_prime_bomb"
REMOVED_PRIME = "content/mods/creeper/particles/removed_poxwalker_bomber_prime_bomb"


def build_parent(source, generated, retail, output, compiler, env):
    effect = json.loads((source / "removed_prime.particles.json").read_text())
    scene = {
        "asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "removed_prime", "extras": {"darktide_asset": {
            "version": 1, "id": "removed_prime", "particles": {
                "name": REMOVED_PRIME.rsplit("/", 1)[1], "effect": effect, "extract": str(retail.resolve()),
            },
        }}}],
    }
    output.mkdir(parents=True, exist_ok=True)
    gltf = generated / "removed_prime.gltf"
    gltf.parent.mkdir(parents=True, exist_ok=True)
    gltf.write_text(json.dumps(scene), encoding="utf-8")
    subprocess.run([str(compiler), str(gltf), "-o", str(output),
                    "--asset-path", "content/mods/creeper/particles/removed_prime", "--no-physics"], check=True, env=env)

    data = bytearray((retail / (RETAIL_UNIT + ".unit")).read_bytes())
    assert struct.unpack_from("<I", data, 38)[0] == 115
    assert struct.unpack_from("<I", data, 29)[0] == len(data) - 38
    assert struct.unpack_from("<Q", data, 8)[0] == resource_id(RETAIL_UNIT)
    assert len(RETAIL_PRIME) == len(REMOVED_PRIME)
    assert data.count(RETAIL_PRIME.encode()) == 1
    # Equal-length replacement preserves every serialized Flow offset.
    data = data.replace(RETAIL_PRIME.encode(), REMOVED_PRIME.encode())
    struct.pack_into("<Q", data, 8, resource_id(PARENT_UNIT))
    (output / "parent.unit").write_bytes(data)

    manifest_path = output / "build.json"
    manifest = json.loads(manifest_path.read_text())
    removed_key = {"type": "particles", "name": REMOVED_PRIME}
    assert manifest["roots"] == [removed_key]
    members = json.loads((retail / (RETAIL_UNIT + ".package.json")).read_text())
    external = [{"type": item["ext"], "name": "#ID[" + item["name_hash"] + "]"}
                for item in members if item["ext"] != "unit" and item["name_hash"] != "%016x" % resource_id(RETAIL_PRIME)]
    parent_key = {"type": "unit", "name": PARENT_UNIT}
    manifest["roots"] = [parent_key]
    manifest["resources"].append({"key": parent_key, "file": {
        "path": "parent.unit", "size": len(data), "crc32": "%08x" % zlib.crc32(data),
    }, "dependencies": [removed_key] + external})
    manifest["artifacts"].append({"resource": parent_key, "path": "parent.unit", "role": "primary", "size": len(data)})
    manifest["external_resources"] = [{"key": key, "package_member": True} for key in external]
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
