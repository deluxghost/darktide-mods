"""Compile the Mojang vanilla Creeper geometry and explosion flipbook."""

import argparse
import base64
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import zlib

from PIL import Image
from audio import build_audio
from parent import build_parent

OUTLINE_LAYERS = (
    (0x641462D5, 0x365EA051CDF53AC8),
    (0xB7C91909, 0xE6481945702287A1),
    (0xB0A0A7A2, 0x4DDB0491C07AF985),
    (0xB2654DB8, 0x213BF6C76D71DB74),
)


def add_outline_layers(output):
    """Reuse the four material layers authored in the retail Poxburster body."""
    manifest_path = output / "build.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    resource = next(item for item in manifest["resources"] if item["key"]["type"] == "unit")
    path = output / resource["file"]["path"]
    data = bytearray(path.read_bytes())
    assert struct.unpack_from("<I", data, 16)[0] == 1 and data[33] == 1
    assert struct.unpack_from("<I", data, 34)[0] == 0, "Expected an inline unit"
    assert struct.unpack_from("<I", data, 29)[0] == len(data) - 38
    assert struct.unpack_from("<I", data, 38)[0] == 115, "Expected UNIT v115"
    assert data[-28:-12] == bytes(16), "Expected an empty material-layer table"
    entries = b"".join(struct.pack("<IQI", name, material, 0) for name, material in OUTLINE_LAYERS)
    data[-24:-20] = struct.pack("<I", len(OUTLINE_LAYERS)) + entries
    struct.pack_into("<I", data, 29, len(data) - 38)
    path.write_bytes(data)
    resource["file"]["size"] = len(data)
    resource["file"]["crc32"] = "%08x" % zlib.crc32(data)
    for artifact in manifest["artifacts"]:
        if artifact["path"] == resource["file"]["path"]:
            artifact["size"] = len(data)
    for _, material in OUTLINE_LAYERS:
        key = {"type": "material", "name": "#ID[%016x]" % material}
        resource["dependencies"].append(key)
        manifest["external_resources"].append({"key": key, "package_member": True})
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


class Scene:
    def __init__(self):
        self.data = bytearray()
        self.scene = {
            "asset": {"version": "2.0", "generator": "Creeper vanilla asset builder"},
            "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": [{"name": "root", "children": []}],
            "meshes": [], "materials": [], "bufferViews": [], "accessors": [],
            "images": [], "textures": [],
            "samplers": [{"magFilter": 9729, "minFilter": 9987}],
        }

    def accessor(self, values, kind, component=5126):
        count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[kind]
        while len(self.data) % 4:
            self.data.append(0)
        flat = [x for row in values for x in (row if isinstance(row, (list, tuple)) else [row])]
        payload = struct.pack("<" + {5126: "f", 5123: "H"}[component] * len(flat), *flat)
        view = len(self.scene["bufferViews"])
        self.scene["bufferViews"].append({"buffer": 0, "byteOffset": len(self.data), "byteLength": len(payload)})
        self.data.extend(payload)
        entry = {"bufferView": view, "componentType": component, "count": len(values), "type": kind}
        if kind == "VEC3":
            entry["min"] = [min(row[i] for row in values) for i in range(count)]
            entry["max"] = [max(row[i] for row in values) for i in range(count)]
        self.scene["accessors"].append(entry)
        return len(self.scene["accessors"]) - 1

    def material(self, image):
        self.scene["images"].append({"uri": "data:image/png;base64," + base64.b64encode(image.read_bytes()).decode()})
        texture = len(self.scene["textures"])
        self.scene["textures"].append({"sampler": 0, "source": len(self.scene["images"]) - 1})
        material = {
            "name": image.stem,
            "pbrMetallicRoughness": {"baseColorTexture": {"index": texture}, "metallicFactor": 0, "roughnessFactor": 1},
            "doubleSided": True,
        }
        self.scene["materials"].append(material)
        return len(self.scene["materials"]) - 1

    def mesh(self, positions, normals, uv, indices, material, joint):
        attributes = {
            "POSITION": self.accessor(positions, "VEC3"),
            "NORMAL": self.accessor(normals, "VEC3"),
            "TEXCOORD_0": self.accessor(uv, "VEC2"),
            "JOINTS_0": self.accessor([[joint, 0, 0, 0] for _ in positions], "VEC4", 5123),
            "WEIGHTS_0": self.accessor([[1, 0, 0, 0] for _ in positions], "VEC4"),
        }
        self.scene["meshes"].append({"primitives": [{
            "attributes": attributes, "indices": self.accessor(indices, "SCALAR", 5123), "material": material,
        }]})
        return len(self.scene["meshes"]) - 1

    def node(self, name, parent=0, **properties):
        node = len(self.scene["nodes"])
        self.scene["nodes"].append({"name": name, **properties})
        self.scene["nodes"][parent].setdefault("children", []).append(node)
        return node

    def group(self, name):
        return self.node(name, extras={"darktide_asset": {"version": 1, "id": name, "visibility_group": name}})

    def save(self, path):
        self.scene["buffers"] = [{"byteLength": len(self.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(self.data).decode()}]
        path.write_text(json.dumps(self.scene, separators=(",", ":")), encoding="utf-8")


def cube_geometry(cube):
    x, y, z = cube["origin"]
    w, h, d = cube["size"]
    u, v = cube["uv"]
    faces = [
        ([(x, y, z), (x, y+h, z), (x+w, y+h, z), (x+w, y, z)], (0, 0, -1), (u+d, v+d, w, h)),
        ([(x+w, y, z+d), (x+w, y+h, z+d), (x, y+h, z+d), (x, y, z+d)], (0, 0, 1), (u+2*d+w, v+d, w, h)),
        ([(x, y, z+d), (x, y+h, z+d), (x, y+h, z), (x, y, z)], (-1, 0, 0), (u, v+d, d, h)),
        ([(x+w, y, z), (x+w, y+h, z), (x+w, y+h, z+d), (x+w, y, z+d)], (1, 0, 0), (u+d+w, v+d, d, h)),
        ([(x, y+h, z), (x, y+h, z+d), (x+w, y+h, z+d), (x+w, y+h, z)], (0, 1, 0), (u+d, v, w, d)),
        ([(x, y, z+d), (x, y, z), (x+w, y, z), (x+w, y, z+d)], (0, -1, 0), (u+d+w, v, w, d)),
    ]
    positions, normals, uv, indices = [], [], [], []
    for vertices, normal, rect in faces:
        start = len(positions)
        positions.extend([[a/16, b/16, c/16] for a, b, c in vertices])
        normals.extend([normal] * 4)
        a, b, width, height = rect
        uv.extend([(a/64, (b+height)/32), (a/64, b/32), ((a+width)/64, b/32), ((a+width)/64, (b+height)/32)])
        indices.extend([start, start+1, start+2, start, start+2, start+3])
    return positions, normals, uv, indices


def build_creeper(source, output):
    scene = Scene()
    bones = json.loads((source / "creeper.geo.json").read_text())["geometry.creeper.v1.8"]["bones"]
    normal = scene.material(source / "creeper_pixels.png")
    flash = scene.material(source / "creeper_flash.png")
    bone_nodes, pivots, inverse = {}, {}, []
    for bone in bones:
        pivot = [x/16 for x in bone.get("pivot", [0, 0, 0])]
        parent = bone_nodes.get(bone.get("parent"), 0)
        parent_pivot = pivots.get(bone.get("parent"), [0, 0, 0])
        bone_nodes[bone["name"]] = scene.node(bone["name"], parent, translation=[a-b for a,b in zip(pivot, parent_pivot)])
        pivots[bone["name"]] = pivot
        inverse.append([1,0,0,0, 0,1,0,0, 0,0,1,0, -pivot[0],-pivot[1],-pivot[2],1])
    scene.scene["skins"] = [{"joints": list(bone_nodes.values()), "inverseBindMatrices": scene.accessor(inverse, "MAT4"), "skeleton": bone_nodes["body"]}]
    for group_name, material in [("normal", normal), ("flash", flash)]:
        group = scene.group(group_name)
        for joint, bone in enumerate(bones):
            positions, normals, uv, indices = cube_geometry(bone["cubes"][0])
            mesh = scene.mesh(positions, normals, uv, indices, material, joint)
            scene.node(group_name + "_" + bone["name"], group, mesh=mesh, skin=0)
    scene.save(output)


def build_explosion(source, generated, retail):
    frames = Image.new("RGBA", (128, 128))
    for frame in range(16):
        image = Image.open(source / ("explosion_%d.png" % frame)).convert("RGBA")
        assert image.size == (32, 32)
        frames.paste(image, ((frame % 4)*32, (frame // 4)*32))
    image_path = generated / "explosion_atlas.png"
    frames.resize((512, 512), Image.Resampling.NEAREST).save(image_path)
    effect = json.loads((source / "explosion.particles.json").read_text())
    scene = {
        "asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "explosion", "extras": {"darktide_asset": {
            "version": 1, "id": "explosion", "particles": {
                "name": "blast", "effect": effect, "extract": str(retail.resolve()),
                "materials": {"55f4ab2ac3be4399": {
                    "variables": {"atlas_rows_columns": [4, 4], "distortion_noise_noise2_atlas": [0, 0, 0],
                                  "use_erosion": [0], "additive": [0], "lerp_color_a": [1, 1, 1],
                                  "lerp_color_b": [1, 1, 1], "intensity": [0.1], "depth_fade_distance": [0.01]},
                    "textures": {"atlas": str(image_path.resolve())},
                }},
            },
        }}}],
    }
    path = generated / "explosion.gltf"
    path.write_text(json.dumps(scene), encoding="utf-8")
    return path


def publish(output, destination):
    manifest = json.loads((output / "build.json").read_text())
    destination.mkdir(parents=True, exist_ok=True)
    for artifact in manifest["artifacts"]:
        path = destination / artifact["path"]
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(output / artifact["path"], path)
    shutil.copy2(output / "build.json", destination / "build.json")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--retail", type=Path, required=True)
    args = parser.parse_args()
    asset_root = Path(__file__).resolve().parent
    mod_root = asset_root.parents[1] / "Creeper"
    source = asset_root / "source"
    model_source = source / "models" / "creeper"
    generated_models = asset_root / "build" / "source" / "models" / "creeper"
    generated_particles = asset_root / "build" / "source" / "particles"
    generated_models.mkdir(parents=True, exist_ok=True)
    generated_particles.mkdir(parents=True, exist_ok=True)
    shutil.copy2(model_source / "creeper.geo.json", generated_models / "creeper.geo.json")
    original = Image.open(model_source / "creeper.png").convert("RGBA")
    pixels = original.resize((1024, 512), Image.Resampling.NEAREST)
    pixels.save(generated_models / "creeper_pixels.png")
    white = Image.new("RGBA", pixels.size, (255,255,255,255))
    Image.blend(pixels, white, 0.5).save(generated_models / "creeper_flash.png")
    env = os.environ.copy()
    env["DARKTIDE_OODLE_CONFIG_DIR"] = str(asset_root / "build" / "oodle")
    subprocess.run([str(args.compiler), "--configure-oodle", str(args.game)], check=True, env=env)
    gltf = generated_models / "creeper.gltf"
    build_creeper(generated_models, gltf)
    model_output = asset_root / "build" / "models" / "creeper"
    subprocess.run([str(args.compiler), str(gltf), "-o", str(model_output),
                    "--asset-path", "content/mods/creeper/creeper", "--no-physics"], check=True, env=env)
    add_outline_layers(model_output)
    gltf = build_explosion(source / "particles", generated_particles, args.retail)
    particle_output = asset_root / "build" / "particles" / "explosion"
    subprocess.run([str(args.compiler), str(gltf), "-o", str(particle_output),
                    "--asset-path", "content/mods/creeper/explosion", "--no-physics"], check=True, env=env)
    publish(model_output, mod_root / "Custom" / "unit_creeper")
    publish(particle_output, mod_root / "Custom" / "particles_explosion")
    audio_output = asset_root / "build" / "audio"
    build_audio(source / "audio", args.retail, audio_output)
    shutil.copytree(audio_output, mod_root / "Custom" / "wwise_event_creeper", dirs_exist_ok=True)
    parent_output = asset_root / "build" / "models" / "poxburster"
    build_parent(source / "particles", generated_particles, args.retail, parent_output, args.compiler, env)
    publish(parent_output, mod_root / "Custom" / "unit_poxburster")


if __name__ == "__main__":
    main()
