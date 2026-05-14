"""
Generate DARK_FOREST_FRONTIER_V1 placeholder biome kit.

Run from the repository root:

    blender --background --python tools/blender/create_dark_forest_frontier_v1.py

The script creates source .blend files under assets_game/source/blender/
and runtime .glb files under assets_game/terrain, assets_game/props, and
assets_game/structures.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
BIOME = "dark_forest_frontier_v1"
SOURCE = ROOT / "assets_game" / "source" / "blender" / BIOME
CLIFFS = ROOT / "assets_game" / "terrain" / "cliffs" / BIOME
PLATEAU = ROOT / "assets_game" / "terrain" / "plateau_edges" / BIOME
RAMPS = ROOT / "assets_game" / "terrain" / "ramps" / BIOME
TREES = ROOT / "assets_game" / "props" / "trees" / BIOME
DECOR = ROOT / "assets_game" / "props" / "decor" / BIOME
ROCKS = ROOT / "assets_game" / "props" / "rocks" / BIOME
RUINS = ROOT / "assets_game" / "structures" / "ruins" / BIOME


def ensure_dirs() -> None:
    for folder in [SOURCE, CLIFFS, PLATEAU, RAMPS, TREES, DECOR, ROCKS, RUINS]:
        folder.mkdir(parents=True, exist_ok=True)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name: str, color: tuple[float, float, float, float], emission: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.92
        bsdf.inputs["Metallic"].default_value = 0.0
        if emission > 0.0 and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = emission
    material.diffuse_color = color
    return material


def materials() -> dict[str, bpy.types.Material]:
    return {
        "dark_rock": mat("dark_rock", (0.09, 0.10, 0.10, 1.0)),
        "mud": mat("muddy_dirt", (0.30, 0.18, 0.10, 1.0)),
        "wood": mat("dead_wood", (0.20, 0.12, 0.07, 1.0)),
        "moss": mat("dark_moss", (0.04, 0.18, 0.08, 1.0)),
        "mushroom": mat("bruise_mushroom_cap", (0.25, 0.12, 0.33, 1.0)),
        "glow": mat("dim_torch_glow", (1.0, 0.42, 0.12, 1.0), 0.6),
    }


def cube(name: str, loc, scale, material, rot_z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=(0.0, 0.0, rot_z))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def ico(name: str, loc, radius, scale, material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def cone(name: str, loc, radius1, radius2, depth, material, vertices=5, rot_z=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=loc, rotation=(0.0, 0.0, rot_z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def ramp_mesh(name: str, rock, dirt):
    mesh = bpy.data.meshes.new(name + "_mesh")
    verts = [(-0.5, -0.5, 0.0), (0.5, -0.5, 0.0), (0.5, 0.5, 1.0), (-0.5, 0.5, 1.0), (-0.5, 0.5, 0.0), (0.5, 0.5, 0.0)]
    faces = [(0, 1, 2, 3), (4, 5, 1, 0), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(dirt)
    obj.data.materials.append(rock)
    for index, poly in enumerate(obj.data.polygons):
        poly.material_index = 0 if index == 0 else 1
    return obj


def finish(asset_name: str, export_dir: Path) -> None:
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            for poly in obj.data.polygons:
                poly.use_smooth = False
    bpy.ops.object.light_add(type="AREA", location=(-3, -4, 6))
    bpy.context.object.data.energy = 300
    bpy.context.object.data.size = 4
    bpy.ops.object.camera_add(location=(3, -4, 3), rotation=(math.radians(60), 0, math.radians(38)))
    bpy.context.scene.camera = bpy.context.object
    blend = SOURCE / f"{asset_name}.blend"
    glb = export_dir / f"{asset_name}.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=False, export_apply=True, export_yup=True)
    print(f"[{BIOME}] wrote {glb}")


def cliff_chunk(asset_name: str, variant: int) -> None:
    clear_scene()
    m = materials()
    cube("cliff_mass", (0, 0, 0.5), (1.0, 1.0, 1.0), m["dark_rock"])
    cube("mud_cap", (0, 0, 1.04), (0.96, 0.96, 0.10), m["mud"])
    cube("moss_cap_patch", (-0.18, 0.12, 1.105), (0.42, 0.32, 0.035), m["moss"], 0.2)
    for i in range(3 + variant):
        cube(f"rock_chip_{i}", (-0.42 + i * 0.28, -0.46 + (i % 2) * 0.12, 0.28 + 0.12 * i), (0.18, 0.14, 0.42), m["dark_rock"], 0.12 * i)
    finish(asset_name, CLIFFS)


def plateau_edge(asset_name: str) -> None:
    clear_scene()
    m = materials()
    cube("plateau_edge_slab", (0, 0, 0.5), (1.0, 0.42, 1.0), m["dark_rock"])
    cube("mud_top", (0, 0.18, 1.04), (1.0, 0.48, 0.08), m["mud"])
    cube("moss_hang", (-0.22, -0.12, 0.74), (0.32, 0.12, 0.45), m["moss"])
    finish(asset_name, PLATEAU)


def ramp(asset_name: str) -> None:
    clear_scene()
    m = materials()
    ramp_mesh("muddy_ramp_slope", m["dark_rock"], m["mud"])
    cube("left_lip", (-0.55, 0.05, 0.45), (0.14, 0.82, 0.22), m["dark_rock"])
    cube("right_lip", (0.55, 0.05, 0.45), (0.14, 0.82, 0.22), m["dark_rock"])
    cube("root_crossing", (0.0, -0.12, 0.28), (0.70, 0.08, 0.08), m["wood"], 0.18)
    finish(asset_name, RAMPS)


def dead_pine(asset_name: str, variant: int) -> None:
    clear_scene()
    m = materials()
    cube("footprint_shadow", (0, 0, 0.025), (0.86, 0.86, 0.05), m["mud"])
    cone("dead_pine_trunk", (0, 0, 0.92), 0.18, 0.10, 1.8 + 0.18 * variant, m["wood"], 6, 0.15)
    for i in range(4):
        cube(f"jagged_branch_{i}", (0.0, 0.0, 0.92 + i * 0.28), (0.10, 0.56 - i * 0.08, 0.10), m["wood"], (i * 0.85) + 0.3)
    cone("dark_needles_low", (0.0, 0.0, 1.38), 0.55, 0.08, 0.58, m["moss"], 6, 0.2)
    cone("dark_needles_top", (0.0, 0.0, 1.84), 0.38, 0.04, 0.54, m["moss"], 6, -0.1)
    finish(asset_name, TREES)


def roots(asset_name: str) -> None:
    clear_scene()
    m = materials()
    cube("root_main", (0, 0, 0.12), (0.92, 0.16, 0.16), m["wood"], 0.18)
    cube("root_split_a", (-0.22, 0.24, 0.12), (0.58, 0.12, 0.12), m["wood"], -0.55)
    cube("root_split_b", (0.26, -0.22, 0.12), (0.52, 0.12, 0.12), m["wood"], 0.72)
    cube("moss_lump", (-0.16, 0.0, 0.22), (0.24, 0.18, 0.14), m["moss"])
    finish(asset_name, DECOR)


def mushroom(asset_name: str, variant: int) -> None:
    clear_scene()
    m = materials()
    cone("stalk", (0, 0, 0.46), 0.16, 0.11, 0.9, m["wood"], 7)
    ico("cap", (0, 0, 1.02), 0.48 + variant * 0.05, (1.2, 1.0, 0.42), m["mushroom"])
    cube("cap_shadow", (0, 0, 0.84), (0.72, 0.62, 0.08), m["dark_rock"], 0.2)
    finish(asset_name, TREES)


def rock_cluster(asset_name: str, variant: int) -> None:
    clear_scene()
    m = materials()
    for i in range(4 + variant):
        ico(f"rock_{i}", (-0.28 + i * 0.18, (-0.16 if i % 2 == 0 else 0.18), 0.22 + 0.06 * i), 0.24, (1.0, 0.82, 0.9 + i * 0.08), m["dark_rock"])
    cube("moss_patch", (0.1, 0.0, 0.52), (0.38, 0.22, 0.08), m["moss"], 0.4)
    finish(asset_name, ROCKS)


def shrine(asset_name: str) -> None:
    clear_scene()
    m = materials()
    cube("shrine_base", (0, 0, 0.14), (1.55, 1.05, 0.28), m["dark_rock"])
    cube("broken_plinth", (0, 0, 0.55), (0.80, 0.58, 0.72), m["dark_rock"], 0.08)
    cube("fallen_side_stone", (-0.58, 0.14, 0.30), (0.24, 0.68, 0.28), m["dark_rock"], -0.32)
    cube("moss_blanket", (0.06, 0.0, 0.94), (0.58, 0.40, 0.08), m["moss"])
    finish(asset_name, RUINS)


def torch(asset_name: str) -> None:
    clear_scene()
    m = materials()
    cone("torch_post", (0, 0, 0.58), 0.07, 0.05, 1.1, m["wood"], 5)
    cube("torch_crossbar", (0, 0, 1.02), (0.36, 0.07, 0.07), m["wood"], 0.15)
    ico("dim_flame", (0, 0, 1.28), 0.16, (0.72, 0.72, 1.25), m["glow"])
    finish(asset_name, DECOR)


def main() -> None:
    ensure_dirs()
    cliff_chunk("df_cliff_chunk_a", 0)
    cliff_chunk("df_cliff_chunk_b", 1)
    plateau_edge("df_plateau_edge_a")
    ramp("df_ramp_a")
    dead_pine("df_dead_pine_a", 0)
    dead_pine("df_dead_pine_b", 1)
    roots("df_twisted_roots_a")
    mushroom("df_mushroom_blocker_a", 0)
    mushroom("df_mushroom_blocker_b", 1)
    rock_cluster("df_rock_cluster_a", 0)
    rock_cluster("df_rock_cluster_b", 1)
    shrine("df_ruined_shrine_a")
    torch("df_torch_a")


if __name__ == "__main__":
    main()
