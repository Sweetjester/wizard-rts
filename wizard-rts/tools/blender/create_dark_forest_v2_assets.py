"""
Generate DARK_FOREST_FRONTIER_V2 GLB assets.

Run:
    blender --background --python tools/blender/create_dark_forest_v2_assets.py
"""

from __future__ import annotations

from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets_game" / "source" / "blender" / "dark_forest_frontier_v2"
BIOME = "dark_forest_frontier_v2"


def ensure_dir(*parts: str) -> Path:
    path = ROOT.joinpath(*parts)
    path.mkdir(parents=True, exist_ok=True)
    return path


DIRS = {
    "ground": ensure_dir("assets_game", "terrain", "ground", BIOME),
    "roads": ensure_dir("assets_game", "terrain", "roads", BIOME),
    "water": ensure_dir("assets_game", "terrain", "water", BIOME),
    "cliffs": ensure_dir("assets_game", "terrain", "cliffs", BIOME),
    "ramps": ensure_dir("assets_game", "terrain", "ramps", BIOME),
    "trees": ensure_dir("assets_game", "props", "trees", BIOME),
    "roots": ensure_dir("assets_game", "props", "roots", BIOME),
    "mushrooms": ensure_dir("assets_game", "props", "mushrooms", BIOME),
    "rocks": ensure_dir("assets_game", "props", "rocks", BIOME),
    "ruins": ensure_dir("assets_game", "props", "ruins", BIOME),
    "decor": ensure_dir("assets_game", "props", "decor", BIOME),
    "shrines": ensure_dir("assets_game", "structures", "shrines", BIOME),
}
SRC.mkdir(parents=True, exist_ok=True)
M = {}


def clear() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)


def mat(name: str, color, emission: float = 0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.95
        if emission > 0.0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = color
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission
    material.diffuse_color = color
    return material


def make_mats() -> None:
    global M
    M = {
        "trunk": mat("near_black_twisted_wood", (0.008, 0.025, 0.029, 1)),
        "root": mat("blue_black_roots", (0.015, 0.04, 0.04, 1)),
        "moss": mat("cold_moss_green", (0.035, 0.15, 0.08, 1)),
        "ground": mat("dark_blue_green_forest_floor", (0.025, 0.11, 0.085, 1)),
        "high": mat("cold_mossy_plateau", (0.018, 0.085, 0.083, 1)),
        "mud": mat("black_muddy_road", (0.105, 0.065, 0.045, 1)),
        "water": mat("dark_swamp_water", (0.005, 0.045, 0.06, 0.88)),
        "stone": mat("desaturated_teal_stone", (0.055, 0.085, 0.085, 1)),
        "shadow": mat("deep_shadow", (0.004, 0.006, 0.007, 1)),
        "pink": mat("hot_pink_mushroom_glow", (1.0, 0.055, 0.29, 1), 2.2),
        "red": mat("red_corruption_glow", (0.9, 0.02, 0.08, 1), 1.6),
        "bone": mat("old_bone", (0.48, 0.42, 0.32, 1)),
        "torch": mat("rare_warm_soul_light", (1.0, 0.38, 0.1, 1), 1.6),
    }


def cube(name, loc, scale, material, rz=0.0, rx=0.0, ry=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(rx, ry, rz))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def cyl(name, loc, radius, depth, material, vertices=7, rz=0.0, rx=0.0, ry=0.0, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=(rx, ry, rz))
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def cone(name, loc, r1, r2, depth, material, vertices=7, rz=0.0, rx=0.0, ry=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=(rx, ry, rz))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def ico(name, loc, radius, material, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def root_bar(name, loc, length, radius, rz, material=None):
    return cyl(name, loc, radius, length, material or M["root"], 7, rz=rz, rx=math.radians(90), scale=(1.0, 0.72, 1.0))


def mushroom(name, x, y, z, size):
    cyl(name + "_stem", (x, y, z + size * 0.28), size * 0.08, size * 0.55, M["pink"], 7)
    ico(name + "_cap", (x, y, z + size * 0.62), size * 0.24, M["pink"], (1.45, 1.15, 0.38))


def finish(name: str, folder: Path) -> None:
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            for polygon in obj.data.polygons:
                polygon.use_smooth = False
    bpy.ops.object.light_add(type="AREA", location=(-4, -5, 6))
    bpy.context.object.name = "preview_cool_key"
    bpy.context.object.data.energy = 450
    bpy.context.object.data.size = 5
    bpy.ops.object.camera_add(location=(3.6, -5.0, 3.3), rotation=(math.radians(60), 0, math.radians(38)))
    bpy.context.scene.camera = bpy.context.object
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(folder / f"{name}.glb"), export_format="GLB", export_apply=True, export_yup=True)
    print("[dark_forest_v2] wrote", folder / f"{name}.glb")


def make_tile(name, material_key, folder, glow=False):
    clear(); make_mats()
    cube("chunky_floor_slab", (0, 0, -0.03), (1.12, 1.12, 0.08), M[material_key])
    for i, (x, y, rz) in enumerate([(-0.32, -0.2, .2), (.28, .18, -.55), (.04, -.36, .95)]):
        root_bar(f"surface_root_{i}", (x, y, 0.045), 0.55, 0.035, rz)
    if glow:
        mushroom("tiny_edge_glow", .31, -.28, .04, .34)
    finish(name, folder)


def make_cliff(name, corner=False):
    clear(); make_mats()
    cube("black_cliff_mass", (0, 0, 0.48), (1.12, 1.08, 0.96), M["stone"])
    cube("mossy_plateau_cap", (0, 0, 1.02), (1.14, 1.1, 0.12), M["high"])
    for i, x in enumerate([-0.38, -0.12, 0.22, 0.42]):
        cube(f"broken_dark_face_{i}", (x, -0.54, 0.45 + i * .04), (0.2, 0.12, 0.75 - i * .08), M["shadow"], rz=i * .08)
    for i, (x, z, rz) in enumerate([(-.42, .7, .2), (.18, .62, -.45), (.44, .32, .62)]):
        root_bar(f"cliff_root_{i}", (x, -0.61, z), .72, .04, rz, M["root"])
    if corner:
        cube("side_cliff_face", (-0.55, 0, .48), (.14, 1.0, .88), M["shadow"])
        root_bar("corner_hanging_root", (-.58, .22, .68), .7, .045, 1.2)
    mushroom("cliff_mushroom_glow", .32, -.58, .18, .42)
    finish(name, DIRS["cliffs"])


def make_ramp(name, wide=False):
    clear(); make_mats()
    width = 1.65 if wide else 1.14
    half = width * .5
    verts = [(-half, -1.0, 0.02), (half, -1.0, 0.02), (half, -0.5, 0.02), (-half, -0.5, 0.02),
             (-half, 0.5, 1.02), (half, 0.5, 1.02), (half, 1.0, 1.02), (-half, 1.0, 1.02)]
    faces = [(0, 1, 2, 3), (3, 2, 5, 4), (4, 5, 6, 7)]
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces); mesh.update()
    obj = bpy.data.objects.new("mud_root_carved_ramp", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(M["mud"])
    root_bar("left_root_lip", (-half - .05, 0, .55), 1.9, .055, 0.0)
    root_bar("right_root_lip", (half + .05, 0, .55), 1.9, .055, 0.0)
    root_bar("cross_root_bottom", (0, -.74, .08), width * .86, .045, math.radians(90))
    root_bar("cross_root_top", (0, .72, 1.05), width * .8, .045, math.radians(90))
    mushroom("ramp_glow", -half * .55, -.55, .08, .34)
    finish(name, DIRS["ramps"])


def make_ancient_tree(name, variant=0):
    clear(); make_mats()
    height = 3.0 + variant * .35
    cyl("massive_twisted_trunk", (0, 0, height * .42), .28, height, M["trunk"], 8, rz=.2, scale=(1.0, .72, 1.0))
    cyl("second_twist_trunk", (.2, .08, height * .45), .18, height * .82, M["root"], 7, rz=.8, ry=.18, scale=(.8, .65, 1.0))
    for i, rz in enumerate([0, .72, 1.6, 2.55, 3.5, 4.3]):
        root_bar(f"giant_surface_root_{i}", (math.cos(rz) * .35, math.sin(rz) * .35, .12), 1.55 - (i % 2) * .25, .075, rz)
    for i, (z, rz, length) in enumerate([(1.5, .3, 1.0), (1.9, 1.5, .82), (2.3, 2.7, .72), (2.7, 4.2, .65)]):
        root_bar(f"crooked_branch_{i}", (math.cos(rz)*.25, math.sin(rz)*.25, z), length, .055, rz)
    for i, (x, y) in enumerate([(.35, -.18), (-.28, .22), (.08, .42)]):
        mushroom(f"trunk_fungus_{i}", x, y, .2 + i * .28, .38)
    finish(name, DIRS["trees"])


def make_dead_spike(name):
    clear(); make_mats()
    for i, (x, y, h, rz) in enumerate([(-.28, .1, 1.8, .15), (.05, -.12, 2.25, -.18), (.32, .16, 1.55, .4)]):
        cone(f"dead_black_spike_{i}", (x, y, h * .5), .13, .035, h, M["trunk"], 6, rz=rz)
    root_bar("spike_root_barrier", (0, -.25, .16), 1.35, .07, .05)
    finish(name, DIRS["trees"])


def make_root_cluster(name, wall=False):
    clear(); make_mats()
    count = 8 if wall else 5
    for i in range(count):
        rz = i * math.pi / max(1, count - 1) + (0.15 if i % 2 else -0.1)
        z = .16 + (i % 3) * .07
        root_bar(f"overlapping_root_{i}", (math.cos(rz) * .16, math.sin(rz) * .18, z), 1.35 if wall else .95, .07 if wall else .055, rz)
    if wall:
        for i, x in enumerate([-.42, -.12, .18, .46]):
            cone(f"upright_root_wall_{i}", (x, .08, .72), .09, .035, 1.25, M["root"], 7, rz=i * .4)
    finish(name, DIRS["roots"])


def make_mushroom_cluster(name, large=False):
    clear(); make_mats()
    sizes = [.52, .42, .35, .28, .22] if not large else [.95, .74, .58, .46, .34, .28]
    for i, size in enumerate(sizes):
        angle = i * 1.35
        radius = .18 + (i % 3) * .18
        mushroom(f"glow_mushroom_{i}", math.cos(angle) * radius, math.sin(angle) * radius, .02, size)
    root_bar("mushroom_root_nest", (0, 0, .08), 1.0 if large else .72, .04, .4)
    finish(name, DIRS["mushrooms"])


def make_rock_cluster(name):
    clear(); make_mats()
    for i, (x, y, s) in enumerate([(-.32, -.12, .38), (.05, .04, .52), (.38, .12, .34), (-.05, .34, .28)]):
        ico(f"mossy_stone_{i}", (x, y, s * .42), s, M["stone"], (1.0, .82, .72))
    cube("moss_sheet", (0, .08, .48), (.86, .42, .08), M["moss"], rz=.2)
    mushroom("rock_glow", .34, -.28, .1, .32)
    finish(name, DIRS["rocks"])


def make_ruin(name, kind="shrine"):
    clear(); make_mats()
    cube("broken_plinth", (0, 0, .18), (1.45, 1.0, .36), M["stone"])
    cube("rear_slab", (0, .32, .88), (1.1, .18, 1.25), M["stone"], rz=.04)
    cube("fallen_side_slab", (-.58, -.08, .36), (.22, .86, .34), M["stone"], rz=-.28)
    root_bar("overgrown_root_0", (-.12, -.18, .42), 1.25, .055, .45)
    root_bar("overgrown_root_1", (.22, .22, .62), 1.05, .045, -0.7)
    if kind == "altar":
        ico("corrupted_core", (0, .04, 1.18), .28, M["red"], (1.0, 1.0, .55))
    elif kind == "arch":
        cube("left_arch", (-.48, .02, 1.0), (.18, .2, 1.3), M["stone"])
        cube("right_arch", (.48, .02, 1.0), (.18, .2, 1.1), M["stone"], rz=.08)
        cube("broken_arch_top", (0, .02, 1.64), (.78, .2, .18), M["stone"], rz=-.12)
    else:
        mushroom("shrine_glow_mushroom", .34, -.28, .28, .5)
    finish(name, DIRS["ruins"] if kind != "shrine_structure" else DIRS["shrines"])


def make_ring(name):
    clear(); make_mats()
    for i in range(10):
        angle = i * math.tau / 10
        mushroom(f"ring_mushroom_{i}", math.cos(angle) * .58, math.sin(angle) * .58, .02, .32 + (i % 3) * .08)
    ico("low_magical_haze", (0, 0, .12), .38, M["red"], (1.4, 1.4, .16))
    finish(name, DIRS["mushrooms"])


def make_decor(name, kind="torch"):
    clear(); make_mats()
    if kind == "bone":
        for i, rz in enumerate([.1, .9, -0.55]):
            root_bar(f"bone_{i}", ((i - 1) * .18, .05 * i, .08), .55, .035, rz, M["bone"])
    elif kind == "road_roots":
        for i, rz in enumerate([.15, -.35, .72, -1.1]):
            root_bar(f"road_edge_root_{i}", ((i - 1.5) * .15, .1 * (i % 2), .07), .72, .035, rz)
        mushroom("road_edge_glow", .36, -.2, .04, .25)
    else:
        cone("soul_light_post", (0, 0, .55), .08, .045, 1.1, M["root"], 6)
        ico("soul_light_flame", (0, 0, 1.22), .2, M["torch"], (1.0, 1.0, 1.25))
        mushroom("torch_base_fungus", .22, .1, .05, .28)
    finish(name, DIRS["decor"])


def main():
    make_tile("df_v2_low_ground_tile_a", "ground", DIRS["ground"], True)
    make_tile("df_v2_high_ground_tile_a", "high", DIRS["ground"], True)
    make_tile("df_v2_muddy_road_tile_a", "mud", DIRS["roads"], False)
    make_tile("df_v2_swamp_water_tile_a", "water", DIRS["water"], True)
    make_cliff("df_v2_cliff_side_a", False)
    make_cliff("df_v2_cliff_corner_a", True)
    make_ramp("df_v2_root_mud_ramp_narrow_a", False)
    make_ramp("df_v2_root_mud_ramp_wide_a", True)
    make_ancient_tree("df_v2_ancient_tree_blocker_a", 0)
    make_ancient_tree("df_v2_ancient_tree_blocker_b", 1)
    make_root_cluster("df_v2_twisted_root_blocker_a", False)
    make_dead_spike("df_v2_dead_tree_spike_a")
    make_mushroom_cluster("df_v2_mushroom_cluster_small_a", False)
    make_mushroom_cluster("df_v2_mushroom_cluster_large_a", True)
    make_rock_cluster("df_v2_rock_moss_cluster_a")
    make_root_cluster("df_v2_root_wall_blocker_a", True)
    make_ruin("df_v2_ruined_shrine_a", "shrine")
    make_ruin("df_v2_corrupted_altar_a", "altar")
    make_ruin("df_v2_broken_stone_arch_a", "arch")
    make_ring("df_v2_glowing_mushroom_ring_a")
    make_decor("df_v2_torch_or_soul_light_a", "torch")
    make_decor("df_v2_bone_decor_a", "bone")
    make_decor("df_v2_road_edge_roots_a", "road_roots")
    make_ruin("df_v2_structure_shrine_a", "shrine_structure")


if __name__ == "__main__":
    main()
